import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Loads the seed JSON under `assets/data/`.
///
/// Seed data is read-only and bundled. It populates storage on first run and
/// is re-read when demo data is reset. Everything a user changes afterwards
/// lives in the mutable store, not here.
abstract final class DemoData {
  static const String root = 'assets/data';

  static final Map<String, Map<String, dynamic>> _cache = {};

  /// Read and decode `assets/data/[name]`.
  ///
  /// Results are cached: seed files cannot change while the app is running.
  static Future<Map<String, dynamic>> loadJson(String name) async {
    final cached = _cache[name];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('$root/$name');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return _cache[name] = decoded;
  }

  /// Read a top-level list from a seed file.
  static Future<List<Map<String, dynamic>>> loadList(
    String name,
    String key,
  ) async {
    final doc = await loadJson(name);
    final list = doc[key];
    if (list is! List) {
      throw FormatException(
        'Expected "$key" to be a list in $root/$name, got ${list.runtimeType}',
      );
    }
    return list.cast<Map<String, dynamic>>();
  }

  /// Drop the cache so the next read hits the bundle again.
  static void clearCache() => _cache.clear();
}
