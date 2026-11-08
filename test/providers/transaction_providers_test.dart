import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strata/models/payment_card.dart';
import 'package:strata/models/transaction.dart';
import 'package:strata/models/txn_filter.dart';
import 'package:strata/providers/spending_providers.dart';
import 'package:strata/providers/transaction_providers.dart';
import 'package:strata/providers/wallet_providers.dart';
import 'package:strata/services/transaction_repository.dart';
import 'package:strata/services/wallet_repository.dart';

import '../support/harness.dart';

final now = DateTime.now();

Transaction tx(
  String id, {
  String cardId = 'c_test',
  int daysAgo = 1,
  int amountMinor = -1000,
  String category = 'Food',
  String merchant = 'Blue Bottle',
  String currency = 'USD',
  TxnKind kind = TxnKind.payment,
}) =>
    Transaction(
      id: id,
      cardId: cardId,
      kind: kind,
      merchant: merchant,
      category: category,
      amountMinor: amountMinor,
      currency: currency,
      occurredAt: now.subtract(Duration(days: daysAgo, hours: 1)),
    );

ProviderContainer containerWith(
  List<Transaction> txns, {
  List<PaymentCard>? cards,
}) {
  final c = ProviderContainer(overrides: [
    transactionRepositoryProvider
        .overrideWithValue(InMemoryTransactionRepository(seed: txns)),
    walletRepositoryProvider.overrideWithValue(
        InMemoryWalletRepository(seed: cards ?? [sampleCard])),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('the list loads newest first', () async {
    final c = containerWith([tx('old', daysAgo: 5), tx('new', daysAgo: 1)]);
    final loaded = await c.read(transactionsProvider.future);
    expect(loaded.map((t) => t.id), ['new', 'old']);
  });

  test('the filter narrows what the screen shows, without losing the rest',
      () async {
    final c = containerWith([
      tx('a', category: 'Food'),
      tx('b', category: 'Transport', merchant: 'City Rail'),
    ]);
    await c.read(transactionsProvider.future);

    expect(c.read(filteredTransactionsProvider).map((t) => t.id), ['a', 'b']);

    c.read(txnFilterProvider.notifier).state =
        TxnFilter.none.copyWith(category: 'Transport');
    expect(c.read(filteredTransactionsProvider).map((t) => t.id), ['b']);

    // The underlying records are untouched; only the view narrowed.
    expect(c.read(transactionsProvider).value, hasLength(2));
  });

  test('groups come from the filtered list, not the whole list', () async {
    final c = containerWith([
      tx('a', daysAgo: 1, category: 'Food'),
      tx('b', daysAgo: 4, category: 'Transport'),
    ]);
    await c.read(transactionsProvider.future);
    expect(c.read(transactionGroupsProvider), hasLength(2));

    c.read(txnFilterProvider.notifier).state =
        TxnFilter.none.copyWith(category: 'Food');
    expect(c.read(transactionGroupsProvider), hasLength(1));
    expect(c.read(transactionGroupsProvider).single.items.single.id, 'a');
  });

  test('the category list offers only categories something is filed under',
      () async {
    final c = containerWith([
      tx('a', category: 'Food'),
      tx('b', category: 'Transport'),
      tx('c', category: 'Food'),
    ]);
    await c.read(transactionsProvider.future);
    expect(c.read(txnCategoriesProvider), ['Food', 'Transport']);
  });

  group('the home chart derives from transactions', () {
    test('it sums this week by category', () async {
      final c = containerWith([
        tx('a', category: 'Food', amountMinor: -2000),
        tx('b', category: 'Transport', amountMinor: -500),
      ]);
      await c.read(transactionsProvider.future);

      final summary = c.read(spendingProvider).value!;
      expect(summary.categories.map((e) => e.label), ['Food', 'Transport']);
      expect(summary.totalMinor, 2500);
    });

    test('editing a transaction amount moves the chart', () async {
      // The whole point of the rewire: the chart cannot state a total that
      // the list no longer supports.
      final c = containerWith([tx('a', category: 'Food', amountMinor: -2000)]);
      await c.read(transactionsProvider.future);
      expect(c.read(spendingProvider).value!.totalMinor, 2000);

      await c
          .read(transactionsProvider.notifier)
          .edit('a', (t) => t.copyWith(amountMinor: -3500));

      expect(c.read(spendingProvider).value!.totalMinor, 3500);
    });

    test('recategorising a transaction moves it between slices', () async {
      final c = containerWith([
        tx('a', category: 'Food', amountMinor: -2000),
        tx('b', category: 'Transport', amountMinor: -500),
      ]);
      await c.read(transactionsProvider.future);

      await c
          .read(transactionsProvider.notifier)
          .edit('a', (t) => t.copyWith(category: 'Transport'));

      final summary = c.read(spendingProvider).value!;
      expect(summary.categories.map((e) => e.label), ['Transport']);
      expect(summary.categories.single.minor, 2500);
    });

    test('deleting the only transaction empties the chart', () async {
      final c = containerWith([tx('a', amountMinor: -2000)]);
      await c.read(transactionsProvider.future);

      await c.read(transactionsProvider.notifier).remove('a');

      expect(c.read(spendingProvider).value!.categories, isEmpty);
      expect(c.read(spendingProvider).value!.totalMinor, 0);
    });

    test('adding a transaction moves the chart too', () async {
      final c = containerWith([tx('a', amountMinor: -2000)]);
      await c.read(transactionsProvider.future);

      await c
          .read(transactionsProvider.notifier)
          .create(tx('b', category: 'Home', amountMinor: -1000));

      expect(c.read(spendingProvider).value!.totalMinor, 3000);
    });

    test('the chart is reported in the wallet currency', () async {
      final c = containerWith([tx('a', amountMinor: -2000)]);
      await c.read(transactionsProvider.future);
      await c.read(walletProvider.future);
      expect(c.read(spendingProvider).value!.currency, 'USD');
    });

    test('the filter does not move the chart', () async {
      // The chart is a view over the whole week, not over the current
      // search. Narrowing the list must not rewrite the headline figure.
      final c = containerWith([
        tx('a', category: 'Food', amountMinor: -2000),
        tx('b', category: 'Transport', amountMinor: -500),
      ]);
      await c.read(transactionsProvider.future);

      c.read(txnFilterProvider.notifier).state =
          TxnFilter.none.copyWith(category: 'Food');

      expect(c.read(spendingProvider).value!.totalMinor, 2500);
    });
  });

  test('a failed edit rolls the list back rather than keeping a lie', () async {
    final c = ProviderContainer(overrides: [
      transactionRepositoryProvider
          .overrideWithValue(_FailingAfterLoadRepository([tx('a')])),
      walletRepositoryProvider
          .overrideWithValue(InMemoryWalletRepository(seed: [sampleCard])),
    ]);
    addTearDown(c.dispose);
    await c.read(transactionsProvider.future);

    // It rethrows, so the sheet that asked for the edit can say so rather
    // than closing on a change that was never stored.
    await expectLater(
      c
          .read(transactionsProvider.notifier)
          .edit('a', (t) => t.copyWith(note: 'optimistic')),
      throwsA(isA<Exception>()),
    );

    expect(c.read(transactionsProvider).value!.single.note, isNull);
  });
}

/// Loads fine, then refuses every write — the shape of a real offline edit.
class _FailingAfterLoadRepository implements TransactionRepository {
  _FailingAfterLoadRepository(this._items);

  final List<Transaction> _items;

  @override
  Future<List<Transaction>> load() async => List.unmodifiable(_items);
  @override
  Future<Transaction> add(Transaction txn) async => throw Exception('offline');
  @override
  Future<Transaction> update(
          String id, Transaction Function(Transaction) change) async =>
      throw Exception('offline');
  @override
  Future<void> remove(String id) async => throw Exception('offline');
}
