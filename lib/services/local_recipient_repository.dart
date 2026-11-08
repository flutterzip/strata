import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipient.dart';
import 'json_store.dart';
import 'recipient_repository.dart';

/// Persists recipients locally, seeded from `assets/data/recipients.json`.
class LocalRecipientRepository implements RecipientRepository {
  LocalRecipientRepository({SharedPreferences? prefs})
      : _store = JsonCollectionStore<Recipient>(
          storageKey: storageKey,
          seedFile: seedFile,
          seedKey: 'recipients',
          fromJson: Recipient.fromJson,
          toJson: (r) => r.toJson(),
          prefs: prefs,
        );

  static const String storageKey = 'strata.recipients.v1';
  static const String seedFile = 'recipients.json';

  final JsonCollectionStore<Recipient> _store;

  @override
  Future<List<Recipient>> load() => _store.load();

  @override
  Future<Recipient> add(Recipient recipient) async {
    final items = await load()
      ..add(recipient);
    await _store.save(items);
    return recipient;
  }

  @override
  Future<Recipient> update(
    String id,
    Recipient Function(Recipient) change,
  ) async {
    final items = await load();
    final i = items.indexWhere((r) => r.id == id);
    if (i == -1) throw StateError('No recipient $id');
    final updated = items[i] = change(items[i]);
    await _store.save(items);
    return updated;
  }

  @override
  Future<void> remove(String id) async {
    final items = await load()
      ..removeWhere((r) => r.id == id);
    await _store.save(items);
  }

  /// Discard user changes and restore the bundled demo data.
  Future<List<Recipient>> resetToSeed() => _store.resetToSeed();
}
