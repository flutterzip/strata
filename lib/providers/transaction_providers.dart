import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../models/txn_filter.dart';
import '../services/local_transaction_repository.dart';
import '../services/transaction_repository.dart';
import '../shared/utils/txn_grouping.dart';

/// Storage for transactions. Swap this one line for a remote implementation
/// and no screen changes.
final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => LocalTransactionRepository(),
);

/// Every transaction, newest first.
///
/// Writes are optimistic — the list updates before storage confirms, so the
/// UI never stalls on a local write — and roll back when storage refuses,
/// because a list showing an edit that was not saved is worse than one that
/// never showed it.
class TransactionNotifier extends AsyncNotifier<List<Transaction>> {
  TransactionRepository get _repo => ref.read(transactionRepositoryProvider);

  @override
  Future<List<Transaction>> build() async => _sorted(await _repo.load());

  /// Copies before sorting. A repository is free to hand back an
  /// unmodifiable list — the in-memory one does — and sorting it in place
  /// throws at runtime rather than at compile time.
  List<Transaction> _sorted(Iterable<Transaction> items) =>
      items.toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  /// Named [create] rather than `add` so a call site can never read as
  /// "add to the screen" when it means "record a new movement of money".
  Future<void> create(Transaction txn) async {
    final previous = state.valueOrNull ?? const <Transaction>[];
    state = AsyncData(_sorted([...previous, txn]));
    try {
      await _repo.add(txn);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> edit(
    String id,
    Transaction Function(Transaction) change,
  ) async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    state = AsyncData(_sorted([
      for (final t in previous) t.id == id ? change(t) : t,
    ]));
    try {
      await _repo.update(id, change);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> remove(String id) async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    state = AsyncData([
      for (final t in previous)
        if (t.id != id) t,
    ]);
    try {
      await _repo.remove(id);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Put a deleted record back, for undo. Separate from [create] so the
  /// intent is readable at the call site.
  Future<void> restore(Transaction txn) => create(txn);

  /// Discard user changes and restore the bundled demo data.
  Future<void> resetDemoData() async {
    final repo = _repo;
    if (repo is! LocalTransactionRepository) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final items = await repo.resetToSeed();
      items.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      return items;
    });
  }
}

final transactionsProvider =
    AsyncNotifierProvider<TransactionNotifier, List<Transaction>>(
        TransactionNotifier.new);

/// What the list is narrowed to. Held apart from the records themselves so
/// clearing a filter can never be confused with deleting data.
final txnFilterProvider = StateProvider<TxnFilter>((ref) => TxnFilter.none);

/// The rows the screen shows, after the filter.
final filteredTransactionsProvider = Provider<List<Transaction>>((ref) {
  final all =
      ref.watch(transactionsProvider).valueOrNull ?? const <Transaction>[];
  final filter = ref.watch(txnFilterProvider);
  return all.where(filter.matches).toList();
});

/// The filtered rows, grouped by day for the sticky headers.
final transactionGroupsProvider = Provider<List<DayGroup>>(
    (ref) => TxnGrouping.byDay(ref.watch(filteredTransactionsProvider)));

/// Categories actually in use, for the filter sheet and the edit form. Taken
/// from every record rather than the filtered set, or choosing one category
/// would hide all the others from the picker.
final txnCategoriesProvider = Provider<List<String>>((ref) =>
    TxnGrouping.categoriesIn(
        ref.watch(transactionsProvider).valueOrNull ?? const []));
