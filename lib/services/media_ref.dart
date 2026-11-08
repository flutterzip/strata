import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Where a piece of media lives.
enum MediaSource {
  /// Bundled with the app under `assets/`. Read-only.
  asset,

  /// Written at runtime into the app documents directory.
  file,
}

/// A reference to an image, audio clip or other media file.
///
/// JSON records store a short string, never the bytes themselves:
///
/// ```json
/// "artwork": "asset:cards/aurora.png"   // assets/images/cards/aurora.png
/// "artwork": "file:media/ab12cd.png"    // <documents>/media/ab12cd.png
/// ```
///
/// Base64 inside JSON is deliberately not supported: it bloats the file,
/// makes it unreadable, and defeats the point of seed data a buyer can edit.
@immutable
class MediaRef {
  const MediaRef(this.source, this.path);

  final MediaSource source;

  /// Path relative to the source root, so a record stays valid across
  /// devices and reinstalls.
  final String path;

  static const String imageRoot = 'assets/images';
  static const String audioRoot = 'assets/audio';

  /// Parse the stored form. Returns null for null or empty input.
  static MediaRef? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final i = raw.indexOf(':');
    if (i == -1) return MediaRef(MediaSource.asset, raw);
    final scheme = raw.substring(0, i);
    final rest = raw.substring(i + 1);
    return switch (scheme) {
      'file' => MediaRef(MediaSource.file, rest),
      'asset' => MediaRef(MediaSource.asset, rest),
      _ => MediaRef(MediaSource.asset, raw),
    };
  }

  /// The form written back to JSON.
  String get encoded => '${source.name}:$path';

  /// Bundled asset key, for [AssetImage] and friends.
  String get assetKey => '$imageRoot/$path';

  /// Absolute on-disk location for runtime media.
  Future<File> resolveFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$path');
  }

  /// An [ImageProvider] for either source, so widgets need no branching.
  Future<ImageProvider?> imageProvider() async {
    switch (source) {
      case MediaSource.asset:
        return AssetImage(assetKey);
      case MediaSource.file:
        final f = await resolveFile();
        return await f.exists() ? FileImage(f) : null;
    }
  }

  /// Directory runtime media is written to. Created if missing.
  static Future<Directory> runtimeMediaDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final media = Directory('${dir.path}/media');
    if (!await media.exists()) await media.create(recursive: true);
    return media;
  }

  @override
  bool operator ==(Object other) =>
      other is MediaRef && other.source == source && other.path == path;

  @override
  int get hashCode => Object.hash(source, path);

  @override
  String toString() => encoded;
}
