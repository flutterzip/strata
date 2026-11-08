import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/config/palette.dart';
import 'package:strata/models/card_brand.dart';
import 'package:strata/models/payment_card.dart';
import 'package:strata/models/rate_table.dart';
import 'package:strata/models/transaction.dart';
import 'package:strata/providers/convert_providers.dart';
import 'package:strata/providers/notification_providers.dart';
import 'package:strata/providers/transaction_providers.dart';
import 'package:strata/providers/wallet_providers.dart';
import 'package:strata/services/transaction_repository.dart';
import 'package:strata/services/wallet_repository.dart';

final table = RateTable(
  asOf: DateTime(2026, 11, 7),
  base: 'USD',
  feeBps: 50,
  rates: const {'USD': 1.0, 'EUR': 0.9172},
);

const usd = PaymentCard(
  id: 'c_forest',
  last4: '8152',
  brand: CardBrand.mastercard,
  funding: CardFunding.debit,
  holder: 'OLYMPICSON',
  expiryMonth: 7,
  expiryYear: 2029,
  skin: CardSkin.forest,
  balanceMinor: 100000,
  currency: 'USD',
  nickname: 'Everyday',
);

const eur = PaymentCard(
  id: 'c_moss',
  last4: '4410',
  brand: CardBrand.visa,
  funding: CardFunding.virtualDebit,
  holder: 'OLYMPICSON',
  expiryMonth: 11,
  expiryYear: 2028,
  skin: CardSkin.moss,
  balanceMinor: 20000,
  currency: 'EUR',
  nickname: 'Travel',
);

const usd2 = PaymentCard(
  id: 'c_sage',
  last4: '7731',
  brand: CardBrand.visa,
  funding: CardFunding.credit,
  holder: 'OLYMPICSON',
  expiryMonth: 3,
  expiryYear: 2030,
  skin: CardSkin.sage,
  balanceMinor: 5000,
  currency: 'USD',
  nickname: 'Household',
);

/// Loads, but refuses every card write — the half-applied-conversion path.
class WriteRefusingWallet implements WalletRepository {
  @override
  Future<List<PaymentCard>> load() async => const [usd, eur];
  @override
  Future<PaymentCard> add(PaymentCard card) async => throw Exception('offline');
  @override
  Future<void> remove(String id) async => throw Exception('offline');
  @override
  Future<PaymentCard> restyle(String id, CardSkin skin) async =>
      throw Exception('offline');
  @override
  Future<PaymentCard> update(
          String id, PaymentCard Function(PaymentCard) change) async =>
      throw Exception('offline');
}

ProviderContainer containerWith({WalletRepository? wallet}) {
  final c = ProviderContainer(overrides: [
    walletRepositoryProvider.overrideWithValue(
        wallet ?? InMemoryWalletRepository(seed: [usd, eur, usd2])),
    transactionRepositoryProvider
        .overrideWithValue(InMemoryTransactionRepository(seed: const [])),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> warmUp(ProviderContainer c) async {
  await c.read(walletProvider.future);
  await c.read(transactionsProvider.future);
  await c.read(notificationsProvider.future);
}

PaymentCard cardIn(ProviderContainer c, String id) =>
    c.read(walletProvider).value!.firstWhere((x) => x.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({
        'strata.notifications.v1': '[]',
      }));

  test('a conversion debits one card and credits the other', () async {
    final c = containerWith();
    await warmUp(c);

    final outcome = await c.read(convertServiceProvider).convert(
          const ConvertRequest(from: usd, to: eur, amountMinor: 20000),
          table,
        );

    // $200 less 0.5% = $199, times 0.9172.
    final expected = (19900 * 0.9172).round();
    expect(outcome.quote.feeMinor, 100);
    expect(outcome.quote.convertedMinor, expected);
    expect(outcome.fromBalanceMinor, 80000);
    expect(outcome.toBalanceMinor, 20000 + expected);

    expect(cardIn(c, 'c_forest').balanceMinor, 80000);
    expect(cardIn(c, 'c_moss').balanceMinor, 20000 + expected);
  });

  test('it writes a matched pair of conversion rows, one per currency',
      () async {
    // A single signed row cannot hold two currencies.
    final c = containerWith();
    await warmUp(c);

    await c.read(convertServiceProvider).convert(
          const ConvertRequest(from: usd, to: eur, amountMinor: 20000),
          table,
        );

    final txns = c.read(transactionsProvider).value!;
    expect(txns, hasLength(2));
    expect(txns.every((t) => t.kind == TxnKind.conversion), isTrue);

    final debit = txns.firstWhere((t) => t.cardId == 'c_forest');
    final credit = txns.firstWhere((t) => t.cardId == 'c_moss');

    expect(debit.amountMinor, -20000);
    expect(debit.currency, 'USD');
    expect(debit.merchant, 'USD to EUR');
    expect(debit.note, contains('0.9172'));
    expect(debit.note, contains(r'$1.00'), reason: 'the fee');

    expect(credit.amountMinor, greaterThan(0));
    expect(credit.currency, 'EUR');
    expect(credit.id, isNot(debit.id));
  });

  test('a same-currency move charges nothing and is named by the cards',
      () async {
    final c = containerWith();
    await warmUp(c);

    final outcome = await c.read(convertServiceProvider).convert(
          const ConvertRequest(from: usd, to: usd2, amountMinor: 20000),
          table,
        );

    expect(outcome.quote.feeMinor, 0);
    expect(outcome.quote.convertedMinor, 20000);
    expect(cardIn(c, 'c_forest').balanceMinor, 80000);
    expect(cardIn(c, 'c_sage').balanceMinor, 25000);

    final txns = c.read(transactionsProvider).value!;
    expect(txns.first.merchant, 'Everyday to Household');
    // No rate or fee note: there is nothing to disclose.
    expect(txns.every((t) => t.note == null), isTrue);
  });

  test('it notifies, naming both figures', () async {
    final c = containerWith();
    await warmUp(c);

    await c.read(convertServiceProvider).convert(
          const ConvertRequest(from: usd, to: eur, amountMinor: 20000),
          table,
        );

    final note = c.read(notificationsProvider).value!.single;
    expect(note.read, isFalse);
    expect(note.title, 'Currency converted');
    expect(note.body, contains(r'$200.00'));
    expect(note.body, contains('€'));
    expect(c.read(unreadCountProvider), 1);
  });

  test('converting more than the balance is refused before any write',
      () async {
    final c = containerWith();
    await warmUp(c);

    await expectLater(
      c.read(convertServiceProvider).convert(
            const ConvertRequest(from: usd, to: eur, amountMinor: 500000),
            table,
          ),
      throwsA(isA<ConvertRefused>()),
    );

    expect(c.read(transactionsProvider).value, isEmpty);
    expect(cardIn(c, 'c_forest').balanceMinor, 100000);
    expect(cardIn(c, 'c_moss').balanceMinor, 20000);
  });

  test('the same card on both sides is refused', () async {
    final c = containerWith();
    await warmUp(c);
    await expectLater(
      c.read(convertServiceProvider).convert(
            const ConvertRequest(from: usd, to: usd, amountMinor: 1000),
            table,
          ),
      throwsA(isA<ConvertRefused>()),
    );
    expect(c.read(transactionsProvider).value, isEmpty);
  });

  test('a failed card write leaves no half-applied conversion behind',
      () async {
    // Money off one card and not onto the other is the worst outcome here,
    // so every earlier step is undone.
    final c = containerWith(wallet: WriteRefusingWallet());
    await warmUp(c);

    await expectLater(
      c.read(convertServiceProvider).convert(
            const ConvertRequest(from: usd, to: eur, amountMinor: 20000),
            table,
          ),
      throwsA(anything),
    );

    expect(c.read(transactionsProvider).value, isEmpty,
        reason: 'both rows must be compensated');
    expect(cardIn(c, 'c_forest').balanceMinor, 100000);
    expect(cardIn(c, 'c_moss').balanceMinor, 20000);
  });

  test('a stale snapshot cannot overdraw the real balance', () async {
    final c = containerWith();
    await warmUp(c);
    final service = c.read(convertServiceProvider);

    await service.convert(
        const ConvertRequest(from: usd, to: eur, amountMinor: 90000), table);

    await expectLater(
      service.convert(
        ConvertRequest(
            from: cardIn(c, 'c_forest'), to: eur, amountMinor: 20000),
        table,
      ),
      throwsA(isA<ConvertRefused>()),
    );
    expect(cardIn(c, 'c_forest').balanceMinor, 10000);
  });

  test('two conversions in a row both land, with distinct rows', () async {
    final c = containerWith();
    await warmUp(c);
    final service = c.read(convertServiceProvider);

    await service.convert(
        const ConvertRequest(from: usd, to: eur, amountMinor: 10000), table);
    await service.convert(
      ConvertRequest(
          from: cardIn(c, 'c_forest'),
          to: cardIn(c, 'c_moss'),
          amountMinor: 10000),
      table,
    );

    final txns = c.read(transactionsProvider).value!;
    expect(txns, hasLength(4));
    expect(txns.map((t) => t.id).toSet(), hasLength(4));
    expect(cardIn(c, 'c_forest').balanceMinor, 80000);
  });

  test('the activity list and the balances agree afterwards', () async {
    final c = containerWith();
    await warmUp(c);

    await c.read(convertServiceProvider).convert(
          const ConvertRequest(from: usd, to: eur, amountMinor: 20000),
          table,
        );

    final txns = c.read(transactionsProvider).value!;
    final usdNet = txns
        .where((t) => t.cardId == 'c_forest')
        .fold<int>(0, (s, t) => s + t.amountMinor);
    final eurNet = txns
        .where((t) => t.cardId == 'c_moss')
        .fold<int>(0, (s, t) => s + t.amountMinor);

    expect(cardIn(c, 'c_forest').balanceMinor, 100000 + usdNet);
    expect(cardIn(c, 'c_moss').balanceMinor, 20000 + eurNet);
  });
}
