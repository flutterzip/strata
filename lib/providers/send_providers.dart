import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../models/payment_card.dart';
import '../models/recipient.dart';
import '../models/transaction.dart';
import '../shared/utils/ids.dart';
import '../shared/utils/money.dart';
import '../shared/utils/send_rules.dart';
import '../shared/utils/spend_limit.dart';
import 'notification_providers.dart';
import 'recipient_providers.dart';
import 'transaction_providers.dart';
import 'wallet_providers.dart';

/// Everything one send needs.
class SendRequest {
  const SendRequest({
    required this.recipient,
    required this.card,
    required this.amountMinor,
    this.note,
  });

  final Recipient recipient;
  final PaymentCard card;
  final int amountMinor;
  final String? note;
}

/// What happened.
class SendOutcome {
  const SendOutcome({
    required this.transaction,
    required this.newBalanceMinor,
  });

  final Transaction transaction;
  final int newBalanceMinor;
}

/// A send was refused before anything was written.
class SendRefused implements Exception {
  const SendRefused(this.reason);

  final String reason;

  @override
  String toString() => 'SendRefused: $reason';
}

/// Moving money, in one place.
///
/// A send is four writes — the transaction, the card balance, a
/// notification, and the recipient's "last used" — and doing them inline in
/// a widget is how three of the four get forgotten. Keeping them here also
/// means the order, and what happens when one fails, is written down once.
class SendService {
  const SendService(this._ref);

  final Ref _ref;

  Future<SendOutcome> send(SendRequest request) async {
    // Re-check at the point of writing rather than trusting the screen: the
    // balance can have moved since the review step was drawn.
    final check = SendRules.check(
      recipient: request.recipient,
      card: request.card,
      amountMinor: request.amountMinor,
      // Awaited, not read synchronously. A plain read of a provider that
      // has not finished building hands back an empty list, which reads as
      // "nothing spent this month" and waves a send straight past the cap.
      limit: SpendLimits.statusFor(
        request.card,
        await _ref.read(transactionsProvider.future),
        now: DateTime.now(),
      ),
    );
    if (!check.ok) throw SendRefused(check.reason!);

    final txn = Transaction(
      id: Ids.next('t'),
      cardId: request.card.id,
      kind: TxnKind.transfer,
      merchant: 'To ${request.recipient.name}',
      category: 'Transfers',
      // Negative: money out. The sign lives on the amount, so a list can be
      // summed directly and can never disagree with itself.
      amountMinor: -request.amountMinor,
      currency: request.card.currency,
      occurredAt: DateTime.now(),
      note:
          (request.note?.trim().isEmpty ?? true) ? null : request.note!.trim(),
    );

    // The record of what happened goes first; it is the thing everything
    // else is derived from.
    await _ref.read(transactionsProvider.notifier).create(txn);

    try {
      await _ref.read(walletProvider.notifier).edit(
            request.card.id,
            (c) =>
                c.copyWith(balanceMinor: c.balanceMinor - request.amountMinor),
          );
    } catch (_) {
      // Compensate rather than leave a transaction with no debit behind it.
      await _ref.read(transactionsProvider.notifier).remove(txn.id);
      rethrow;
    }

    // Neither of these is worth failing the send over: the money has moved
    // and the record exists. A missing notification is a cosmetic loss.
    try {
      await _ref.read(notificationsProvider.notifier).push(
            kind: NotificationKind.payment,
            title: 'Money sent',
            body: '${Money.format(request.amountMinor, request.card.currency)} '
                'went to ${request.recipient.name} (${request.recipient.handle}) '
                'from your ${request.card.displayLabel} card.',
          );
      await _ref
          .read(recipientsProvider.notifier)
          .markUsed(request.recipient.id);
    } catch (_) {
      // Deliberately swallowed. See above.
    }

    return SendOutcome(
      transaction: txn,
      newBalanceMinor: request.card.balanceMinor - request.amountMinor,
    );
  }
}

final sendServiceProvider = Provider<SendService>(SendService.new);
