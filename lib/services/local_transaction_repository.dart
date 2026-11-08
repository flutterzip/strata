import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction.dart';
import 'json_store.dart';
import 'transaction_repository.dart';
import 'transaction_seed.dart';

/// Persists transactions locally, seeded from `assets/data/transactions.json`.
///
/// The seed-then-persist machinery lives in [JsonCollectionStore]; the only
/// thing special here is [TransactionSeed.rebase], which moves the bundled
/// dates forward so the demo's current week is never empty.
class LocalTransactionRepository implements TransactionRepository {
  LocalTransactionRepository({SharedPreferences? prefs})
      : _store = JsonCollectionStore<Transaction>(
          storageKey: storageKey,
          seedFile: TransactionSeed.seedFile,
          seedKey: TransactionSeed.seedKey,
          fromJson: Transaction.fromJson,
          toJson: (t) => t.toJson(),
          transformSeed: (items, doc) => TransactionSeed.rebase(
            items,
            asOf: TransactionSeed.asOfIn(doc),
            now: DateTime.now(),
          ),
          prefs: prefs,
        );

  static const String storageKey = 'strata.transactions.v1';

  final JsonCollectionStore<Transaction> _store;

  /// Newest first, which is the order every screen wants.
  @override
  Future<List<Transaction>> load() async {
    final items = await _store.load();
    items.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return items;
  }

  @override
  Future<Transaction> add(Transaction txn) async {
    final items = await load()
      ..add(txn);
    await _store.save(items);
    return txn;
  }

  @override
  Future<Transaction> update(
    String id,
    Transaction Function(Transaction) change,
  ) async {
    final items = await load();
    final i = items.indexWhere((t) => t.id == id);
    if (i == -1) throw StateError('No transaction $id');
    final updated = items[i] = change(items[i]);
    await _store.save(items);
    return updated;
  }

  @override
  Future<void> remove(String id) async {
    final items = await load()
      ..removeWhere((t) => t.id == id);
    await _store.save(items);
  }

  /// Discard user changes and restore the bundled demo data.
  Future<List<Transaction>> resetToSeed() => _store.resetToSeed();
}
