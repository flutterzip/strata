import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'demo_data.dart';

/// Seed-then-persist storage, shared by everything the app keeps locally.
///
/// The pattern is identical for cards, the profile and notifications, so it
/// lives here once:
///
/// 1. First read finds nothing stored, so the bundled seed under
///    `assets/data/` is loaded and written through.
/// 2. Later reads come from storage.
/// 3. Corrupt or outdated stored data falls back to the seed rather than
///    crashing on launch.
/// 4. [resetToSeed] discards user changes and starts again.
///
/// Swap the whole app to a backend by replacing the repositories that use
/// this, not by editing it.
abstract class _BaseStore {
  _BaseStore(
      {required this.storageKey,
      required this.seedFile,
      SharedPreferences? prefs})
      : _injected = prefs;

  /// Key under which the JSON payload is written.
  final String storageKey;

  /// File under `assets/data/` holding the first-run data.
  final String seedFile;

  final SharedPreferences? _injected;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async =>
      _prefs ??= _injected ?? await SharedPreferences.getInstance();

  Future<void> clear() async => (await prefs).remove(storageKey);
}

/// A stored list of records, e.g. cards or notifications.
class JsonCollectionStore<T> extends _BaseStore {
  JsonCollectionStore({
    required super.storageKey,
    required super.seedFile,
    required this.seedKey,
    required this.fromJson,
    required this.toJson,
    this.transformSeed,
    super.prefs,
  });

  /// Top-level key inside the seed file holding the array.
  final String seedKey;

  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;

  /// Last chance to adjust the seed before it is written through, given the
  /// parsed rows and the whole seed document so sibling keys are reachable.
  ///
  /// Runs on first run and on reset only, never on an ordinary load — so
  /// whatever it does must not be expected to re-apply to stored data.
  /// Transactions use it to shift bundled dates forward by the age of the
  /// seed; most entities need nothing here.
  final List<T> Function(List<T> items, Map<String, dynamic> doc)?
      transformSeed;

  Future<List<T>> load() async {
    final raw = (await prefs).getString(storageKey);
    if (raw == null) return _seedThrough();
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(fromJson).toList();
    } on FormatException {
      return _seedThrough();
    } on TypeError {
      return _seedThrough();
    }
  }

  Future<void> save(List<T> items) async {
    await (await prefs).setString(
      storageKey,
      jsonEncode([for (final i in items) toJson(i)]),
    );
  }

  Future<List<T>> resetToSeed() async {
    DemoData.clearCache();
    return _seedThrough();
  }

  Future<List<T>> _seedThrough() async {
    final doc = await DemoData.loadJson(seedFile);
    final rows = await DemoData.loadList(seedFile, seedKey);
    var items = rows.map(fromJson).toList();
    if (transformSeed != null) items = transformSeed!(items, doc);
    await save(items);
    return items;
  }
}

/// A single stored record, e.g. the user profile.
class JsonDocumentStore<T> extends _BaseStore {
  JsonDocumentStore({
    required super.storageKey,
    required super.seedFile,
    required this.fromJson,
    required this.toJson,
    super.prefs,
  });

  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;

  Future<T> load() async {
    final raw = (await prefs).getString(storageKey);
    if (raw == null) return _seedThrough();
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return _seedThrough();
    } on TypeError {
      return _seedThrough();
    }
  }

  Future<void> save(T value) async {
    await (await prefs).setString(storageKey, jsonEncode(toJson(value)));
  }

  Future<T> resetToSeed() async {
    DemoData.clearCache();
    return _seedThrough();
  }

  Future<T> _seedThrough() async {
    final doc = await DemoData.loadJson(seedFile);
    final value = fromJson(doc);
    await save(value);
    return value;
  }
}
