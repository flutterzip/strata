import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/config/palette.dart';
import 'package:strata/models/card_brand.dart';
import 'package:strata/models/payment_card.dart';
import 'package:strata/models/recipient.dart';
import 'package:strata/models/transaction.dart';
import 'package:strata/providers/notification_providers.dart';
import 'package:strata/providers/recipient_providers.dart';
import 'package:strata/providers/send_providers.dart';
import 'package:strata/providers/transaction_providers.dart';
import 'package:strata/providers/wallet_providers.dart';
import 'package:strata/services/recipient_repository.dart';
import 'package:strata/services/transaction_repository.dart';
import 'package:strata/services/wallet_repository.dart';

const akosua = Recipient(
  id: 'r_mensah',
  name: 'Akosua Mensah',
  handle: '@akosua',
  email: 'akosua.mensah@example.com',
  verified: true,
);

const everyday = PaymentCard(
  id: 'c_forest',
  last4: '8152',
  brand: CardBrand.mastercard,
  funding: CardFunding.debit,
  holder: 'OLYMPICSON',
  expiryMonth: 7,
  expiryYear: 2029,
  skin: CardSkin.forest,
  balanceMinor: 50000,
  currency: 'USD',
  nickname: 'Everyday',
);

/// A wallet that loads but refuses every write, for the compensating path.
class WriteRefusingWallet implements WalletRepository {
  @override
  Future<List<PaymentCard>> load() async => const [everyday];
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
        wallet ?? InMemoryWalletRepository(seed: [everyday])),
    transactionRepositoryProvider
        .overrideWithValue(InMemoryTransactionRepository(seed: const [])),
    recipientRepositoryProvider
        .overrideWithValue(InMemoryRecipientRepository(seed: const [akosua])),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> warmUp(ProviderContainer c) async {
  await c.read(walletProvider.future);
  await c.read(transactionsProvider.future);
  await c.read(recipientsProvider.future);
  await c.read(notificationsProvider.future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({
        'strata.notifications.v1': '[]',
      }));

  test('a send debits the card and records a transfer', () async {
    final c = containerWith();
    await warmUp(c);

    final outcome = await c.read(sendServiceProvider).send(const SendRequest(
          recipient: akosua,
          card: everyday,
          amountMinor: 12500,
        ));

    expect(outcome.newBalanceMinor, 37500);
    expect(c.read(walletProvider).value!.single.balanceMinor, 37500);

    final txn = c.read(transactionsProvider).value!.single;
    expect(txn.kind, TxnKind.transfer);
    expect(txn.amountMinor, -12500, reason: 'money out is negative');
    expect(txn.merchant, 'To Akosua Mensah');
    expect(txn.category, 'Transfers');
    expect(txn.cardId, 'c_forest');
    expect(txn.currency, 'USD');
  });

  test('the note travels with the transfer', () async {
    final c = containerWith();
    await warmUp(c);

    await c.read(sendServiceProvider).send(const SendRequest(
          recipient: akosua,
          card: everyday,
          amountMinor: 500,
          note: '  half the deposit  ',
        ));

    expect(c.read(transactionsProvider).value!.single.note, 'half the deposit');
  });

  test('a blank note is stored as no note, not as whitespace', () async {
    final c = containerWith();
    await warmUp(c);
    await c.read(sendServiceProvider).send(const SendRequest(
          recipient: akosua,
          card: everyday,
          amountMinor: 500,
          note: '   ',
        ));
    expect(c.read(transactionsProvider).value!.single.note, isNull);
  });

  test('a send pushes an unread notification naming the amount and payee',
      () async {
    // A transfer the person can find no trace of afterwards is
    // indistinguishable from one that failed.
    final c = containerWith();
    await warmUp(c);

    await c.read(sendServiceProvider).send(const SendRequest(
          recipient: akosua,
          card: everyday,
          amountMinor: 12500,
        ));

    final notes = c.read(notificationsProvider).value!;
    expect(notes, hasLength(1));
    expect(notes.single.read, isFalse);
    expect(notes.single.body, contains(r'$125.00'));
    expect(notes.single.body, contains('Akosua Mensah'));
    expect(notes.single.body, contains('Everyday'));
    expect(c.read(unreadCountProvider), 1);
  });

  test('a send marks the recipient as just used, so the list reorders',
      () async {
    final c = containerWith();
    await warmUp(c);
    expect(c.read(recipientsProvider).value!.single.lastUsedAt, isNull);

    await c.read(sendServiceProvider).send(const SendRequest(
          recipient: akosua,
          card: everyday,
          amountMinor: 100,
        ));

    expect(c.read(recipientsProvider).value!.single.lastUsedAt, isNotNull);
  });

  test('the home chart moves, because a transfer is money out', () async {
    final c = containerWith();
    await warmUp(c);
    await c.read(sendServiceProvider).send(const SendRequest(
          recipient: akosua,
          card: everyday,
          amountMinor: 12500,
        ));

    expect(c.read(filteredTransactionsProvider), hasLength(1));
  });

  test('sending more than the balance is refused before anything is written',
      () async {
    final c = containerWith();
    await warmUp(c);

    await expectLater(
      c.read(sendServiceProvider).send(const SendRequest(
            recipient: akosua,
            card: everyday,
            amountMinor: 60000,
          )),
      throwsA(isA<SendRefused>()),
    );

    expect(c.read(transactionsProvider).value, isEmpty);
    expect(c.read(walletProvider).value!.single.balanceMinor, 50000);
    expect(c.read(notificationsProvider).value, isEmpty);
  });

  test('a zero send is refused', () async {
    final c = containerWith();
    await warmUp(c);
    await expectLater(
      c.read(sendServiceProvider).send(
          const SendRequest(recipient: akosua, card: everyday, amountMinor: 0)),
      throwsA(isA<SendRefused>()),
    );
    expect(c.read(transactionsProvider).value, isEmpty);
  });

  test('a failed debit takes the transaction back out again', () async {
    // Otherwise the history shows money leaving that never left, and the
    // chart and the balance disagree forever.
    final c = containerWith(wallet: WriteRefusingWallet());
    await warmUp(c);

    await expectLater(
      c.read(sendServiceProvider).send(const SendRequest(
            recipient: akosua,
            card: everyday,
            amountMinor: 1000,
          )),
      throwsA(anything),
    );

    expect(c.read(transactionsProvider).value, isEmpty,
        reason: 'the transaction must be compensated');
  });

  test('two sends in a row both land', () async {
    final c = containerWith();
    await warmUp(c);
    final service = c.read(sendServiceProvider);

    await service.send(const SendRequest(
        recipient: akosua, card: everyday, amountMinor: 10000));
    final card = c.read(walletProvider).value!.single;
    await service
        .send(SendRequest(recipient: akosua, card: card, amountMinor: 15000));

    expect(c.read(walletProvider).value!.single.balanceMinor, 25000);
    expect(c.read(transactionsProvider).value, hasLength(2));
    // Distinct ids, or the second would overwrite the first.
    expect(
      c.read(transactionsProvider).value!.map((t) => t.id).toSet(),
      hasLength(2),
    );
  });

  test('a monthly limit is enforced at the point of writing', () async {
    // Not just while typing. The service reads the spend from transactions
    // itself, and must await them: an unbuilt provider reads as an empty
    // list, which looks like nothing has been spent this month.
    final now = DateTime.now();
    final capped = PaymentCard(
      id: everyday.id,
      last4: everyday.last4,
      brand: everyday.brand,
      funding: everyday.funding,
      holder: everyday.holder,
      expiryMonth: everyday.expiryMonth,
      expiryYear: everyday.expiryYear,
      skin: everyday.skin,
      balanceMinor: everyday.balanceMinor,
      currency: everyday.currency,
      nickname: everyday.nickname,
      spendLimitMinor: 10000,
    );
    final c = ProviderContainer(overrides: [
      walletRepositoryProvider
          .overrideWithValue(InMemoryWalletRepository(seed: [capped])),
      transactionRepositoryProvider.overrideWithValue(
        InMemoryTransactionRepository(seed: [
          Transaction(
            id: 't_spent',
            cardId: capped.id,
            kind: TxnKind.payment,
            merchant: 'Greenmarket',
            category: 'Groceries',
            amountMinor: -9000,
            currency: 'USD',
            occurredAt: DateTime(now.year, now.month, 1, 12),
          ),
        ]),
      ),
      recipientRepositoryProvider
          .overrideWithValue(InMemoryRecipientRepository(seed: const [akosua])),
    ]);
    addTearDown(c.dispose);
    // Deliberately not warmed up: the service has to load them itself.
    await expectLater(
      c.read(sendServiceProvider).send(
            SendRequest(recipient: akosua, card: capped, amountMinor: 5000),
          ),
      throwsA(isA<SendRefused>()),
    );
  });

  test('a frozen card is refused at the point of writing', () async {
    final frozen = PaymentCard(
      id: everyday.id,
      last4: everyday.last4,
      brand: everyday.brand,
      funding: everyday.funding,
      holder: everyday.holder,
      expiryMonth: everyday.expiryMonth,
      expiryYear: everyday.expiryYear,
      skin: everyday.skin,
      balanceMinor: everyday.balanceMinor,
      currency: everyday.currency,
      nickname: everyday.nickname,
      frozen: true,
    );
    final c = containerWith(wallet: InMemoryWalletRepository(seed: [frozen]));
    await warmUp(c);

    await expectLater(
      c.read(sendServiceProvider).send(
            SendRequest(recipient: akosua, card: frozen, amountMinor: 100),
          ),
      throwsA(isA<SendRefused>()),
    );
    expect(c.read(transactionsProvider).value, isEmpty);
  });

  test('a stale card snapshot cannot overdraw the real balance', () async {
    // The review screen holds a card from before an earlier send. The check
    // runs again at the point of writing, against what is passed in.
    final c = containerWith();
    await warmUp(c);
    final service = c.read(sendServiceProvider);

    await service.send(const SendRequest(
        recipient: akosua, card: everyday, amountMinor: 45000));

    await expectLater(
      service.send(SendRequest(
          recipient: akosua,
          card: c.read(walletProvider).value!.single,
          amountMinor: 10000)),
      throwsA(isA<SendRefused>()),
    );
    expect(c.read(walletProvider).value!.single.balanceMinor, 5000);
  });
}
