import '../models/transaction.dart';

/// Contract for transaction storage.
///
/// Async even though the local implementation is not, so a real API can be
/// dropped in without touching a widget — the same rule the wallet follows.
abstract interface class TransactionRepository {
  Future<List<Transaction>> load();
  Future<Transaction> add(Transaction txn);

  /// Apply a change to one record. Throws [StateError] when the id is gone,
  /// rather than silently doing nothing and leaving the UI showing an edit
  /// that was never stored.
  Future<Transaction> update(
    String id,
    Transaction Function(Transaction) change,
  );

  Future<void> remove(String id);
}

/// In-memory implementation, for tests and for exercising loading states.
class InMemoryTransactionRepository implements TransactionRepository {
  InMemoryTransactionRepository({List<Transaction>? seed, this.latency})
      : _items = [...(seed ?? const <Transaction>[])];

  final List<Transaction> _items;

  /// Simulated network delay, so loading states are reachable in the demo.
  final Duration? latency;

  Future<void> _settle() async {
    if (latency != null) await Future<void>.delayed(latency!);
  }

  @override
  Future<List<Transaction>> load() async {
    await _settle();
    return List.unmodifiable(
        _items..sort((a, b) => b.occurredAt.compareTo(a.occurredAt)));
  }

  @override
  Future<Transaction> add(Transaction txn) async {
    await _settle();
    _items.add(txn);
    return txn;
  }

  @override
  Future<Transaction> update(
    String id,
    Transaction Function(Transaction) change,
  ) async {
    await _settle();
    final i = _items.indexWhere((t) => t.id == id);
    if (i == -1) throw StateError('No transaction $id');
    return _items[i] = change(_items[i]);
  }

  @override
  Future<void> remove(String id) async {
    await _settle();
    _items.removeWhere((t) => t.id == id);
  }
}
