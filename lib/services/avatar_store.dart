import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../shared/utils/ids.dart';
import 'image_encoder.dart';
import 'media_ref.dart';

/// Where user-supplied media is written.
///
/// An interface, like every other store here, so a screen never talks to the
/// filesystem and a remote uploader can take its place without touching the
/// UI.
abstract interface class MediaStore {
  /// Re-encode and write [bytes], returning the reference to store in JSON.
  Future<MediaRef> write(
    Uint8List bytes, {
    required String entity,
    required String id,
  });

  /// Write a replacement and delete what it replaced — but only once the new
  /// file is safely on disk, so a failure cannot lose both.
  Future<MediaRef> replace(
    Uint8List bytes, {
    required String entity,
    required String id,
    MediaRef? previous,
  });

  /// Remove the file a reference points at, if it is ours to remove.
  Future<void> delete(MediaRef? ref);

  /// An [ImageProvider] for [ref], or null when there is nothing to show.
  ///
  /// Null covers a null reference and a file that is no longer on disk — a
  /// restored backup, cleared storage. A caller gets one answer for "show
  /// the fallback" instead of having to distinguish them.
  ///
  /// Resolution lives behind this interface rather than on [MediaRef] so the
  /// widget layer never reaches for `path_provider`, which has no answer at
  /// all inside a widget test.
  Future<ImageProvider?> imageFor(MediaRef? ref);
}

/// The app-documents implementation, following the rules in
/// `assets/data/README.md`.
class LocalMediaStore implements MediaStore {
  LocalMediaStore({Future<Directory> Function()? resolveMediaDir})
      : _resolveMediaDir = resolveMediaDir ?? MediaRef.runtimeMediaDir;

  /// Injectable so tests can write into a temp directory;
  /// `path_provider` has no answer inside a unit test.
  final Future<Directory> Function() _resolveMediaDir;

  /// The single directory runtime media may live in. Everything else is
  /// either read-only (the bundle) or deleted by the OS (the cache).
  static const String folder = 'media';

  @override
  Future<MediaRef> write(
    Uint8List bytes, {
    required String entity,
    required String id,
  }) async {
    // Re-encode first. If the bytes are not an image we want to know before
    // anything has been created or deleted.
    final encoded = ImageEncoder.avatar(bytes);

    final dir = await _resolveMediaDir();
    if (!await dir.exists()) await dir.create(recursive: true);

    // Our name, never the picker's: that one can collide, carry anything, or
    // be absent entirely. The stamp also makes a replacement visible in a
    // file listing, which helps when debugging a leak, and it carries a
    // counter because two writes can land in the same millisecond.
    final name = '${entity}_${id}_${Ids.stamp()}.jpg';
    await File('${dir.path}/$name').writeAsBytes(encoded, flush: true);

    // Relative. An absolute path is invalidated by the next reinstall.
    return MediaRef(MediaSource.file, '$folder/$name');
  }

  @override
  Future<MediaRef> replace(
    Uint8List bytes, {
    required String entity,
    required String id,
    MediaRef? previous,
  }) async {
    final next = await write(bytes, entity: entity, id: id);
    // Only now. Deleting first would lose the old picture whenever the new
    // one fails to encode or the disk is full.
    if (previous != next) await delete(previous);
    return next;
  }

  @override
  Future<void> delete(MediaRef? ref) async {
    if (ref == null) return;
    // A bundled asset is read-only and shipped inside the app.
    if (ref.source != MediaSource.file) return;

    final name = _nameWithin(ref.path);
    if (name == null) return;

    final dir = await _resolveMediaDir();
    final file = File('${dir.path}/$name');
    // Missing is normal: restored backups and cleared storage both leave a
    // record pointing at nothing.
    if (await file.exists()) await file.delete();
  }

  @override
  Future<ImageProvider?> imageFor(MediaRef? ref) async {
    if (ref == null) return null;
    if (ref.source == MediaSource.asset) return AssetImage(ref.assetKey);

    final name = _nameWithin(ref.path);
    if (name == null) return null;

    final dir = await _resolveMediaDir();
    final file = File('${dir.path}/$name');
    return await file.exists() ? FileImage(file) : null;
  }

  /// The bare filename, or null when [path] is not a plain file directly
  /// inside the media folder.
  ///
  /// A stored path is data. Without this check a record containing `../`
  /// could reach the rest of the container.
  static String? _nameWithin(String path) {
    const prefix = '$folder/';
    if (!path.startsWith(prefix)) return null;
    final name = path.substring(prefix.length);
    if (name.isEmpty || name.contains('/') || name.contains('\\')) return null;
    if (name == '.' || name == '..') return null;
    return name;
  }
}
