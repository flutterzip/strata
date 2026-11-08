import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../models/payment_card.dart';
import '../models/rate_table.dart';
import '../models/transaction.dart';
import '../shared/utils/conversion.dart';
import '../shared/utils/ids.dart';
import '../shared/utils/spend_limit.dart';
import '../shared/utils/money.dart';
import 'notification_providers.dart';
import 'transaction_providers.dart';
import 'wallet_providers.dart';

/// Everything one conversion needs.
class ConvertRequest {
  const ConvertRequest({
    required this.from,
    required this.to,
    required this.amountMinor,
  });

  final PaymentCard from;
  final PaymentCard to;
  final int amountMinor;
}

/// What happened.
class ConvertOutcome {
  const ConvertOutcome({
    required this.quote,
    required this.fromBalanceMinor,
    required this.toBalanceMinor,
  });

  final ConversionQuote quote;
  final int fromBalanceMinor;
  final int toBalanceMinor;
}

/// A conversion was refused before anything was written.
class ConvertRefused implements Exception {
  const ConvertRefused(this.reason);

  final String reason;

  @override
  String toString() => 'ConvertRefused: $reason';
}

/// Moving money between two of the owner's own cards, across currencies.
///
/// Four writes, like a send, but two of them are a matched pair: a
/// conversion is one debit and one credit, recorded separately because they
/// are in different currencies and a single signed row cannot hold both. If
/// any step fails, the ones before it are undone — a half-applied conversion
/// is money that has left one card without arriving on the other.
class ConvertService {
  const ConvertService(this._ref);

  final Ref _ref;

  Future<ConvertOutcome> convert(
    ConvertRequest request,
    RateTable table,
  ) async {
    // Re-checked here rather than trusted from the screen: the balance can
    // have moved since the figures were drawn.
    final check = Conversion.check(
      from: request.from,
      to: request.to,
      amountMinor: request.amountMinor,
      table: table,
      // Awaited, for the same reason as in SendService: an unbuilt
      // provider reads as an empty list, which looks like nothing has been
      // spent and lets a conversion past the monthly cap.
      limit: SpendLimits.statusFor(
        request.from,
        await _ref.read(transactionsProvider.future),
        now: DateTime.now(),
      ),
    );
    if (!check.ok) throw ConvertRefused(check.reason!);

    final q = check.quote;
    // Cross-currency reads as the pair, matching the seeded rows. Moving
    // dollars to dollars is not a conversion, so it is named by the cards
    // instead — "USD to USD" in an activity list tells you nothing.
    final label = q.sameCurrency
        ? '${request.from.displayLabel} to ${request.to.displayLabel}'
        : '${q.fromCurrency} to ${q.toCurrency}';
    final when = DateTime.now();

    final debit = Transaction(
      id: Ids.next('t'),
      cardId: request.from.id,
      kind: TxnKind.conversion,
      merchant: label,
      category: 'Transfers',
      amountMinor: -q.amountMinor,
      currency: q.fromCurrency,
      occurredAt: when,
      note: q.sameCurrency
          ? null
          : 'Rate ${q.rateLabel}, fee '
              '${Money.format(q.feeMinor, q.fromCurrency)}',
    );
    final credit = Transaction(
      id: Ids.next('t'),
      cardId: request.to.id,
      kind: TxnKind.conversion,
      merchant: label,
      category: 'Transfers',
      amountMinor: q.convertedMinor,
      currency: q.toCurrency,
      occurredAt: when,
      note: q.sameCurrency ? null : 'Rate ${q.rateLabel}',
    );

    // Undo steps, newest first. Built as we go so a failure half way can
    // put things back exactly as far as they got.
    final undo = <Future<void> Function()>[];
    final txns = _ref.read(transactionsProvider.notifier);
    final wallet = _ref.read(walletProvider.notifier);

    try {
      await txns.create(debit);
      undo.add(() => txns.remove(debit.id));

      await txns.create(credit);
      undo.add(() => txns.remove(credit.id));

      await wallet.edit(request.from.id,
          (c) => c.copyWith(balanceMinor: c.balanceMinor - q.amountMinor));
      undo.add(() => wallet.edit(request.from.id,
          (c) => c.copyWith(balanceMinor: c.balanceMinor + q.amountMinor)));

      await wallet.edit(request.to.id,
          (c) => c.copyWith(balanceMinor: c.balanceMinor + q.convertedMinor));
    } catch (_) {
      for (final step in undo.reversed) {
        // Best effort. If an undo itself fails there is nothing further to
        // try, and swallowing it keeps the original cause as what is thrown.
        try {
          await step();
        } catch (_) {}
      }
      rethrow;
    }

    // Not worth failing a completed conversion over.
    try {
      await _ref.read(notificationsProvider.notifier).push(
            kind: NotificationKind.payment,
            title: q.sameCurrency ? 'Money moved' : 'Currency converted',
            body: '${Money.format(q.amountMinor, q.fromCurrency)} from your '
                '${request.from.displayLabel} card became '
                '${Money.format(q.convertedMinor, q.toCurrency)} on your '
                '${request.to.displayLabel} card.',
          );
    } catch (_) {}

    return ConvertOutcome(
      quote: q,
      fromBalanceMinor: request.from.balanceMinor - q.amountMinor,
      toBalanceMinor: request.to.balanceMinor + q.convertedMinor,
    );
  }
}

final convertServiceProvider = Provider<ConvertService>(ConvertService.new);
