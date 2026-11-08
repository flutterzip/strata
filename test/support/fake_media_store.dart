import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:strata/services/avatar_store.dart';
import 'package:strata/services/image_encoder.dart';
import 'package:strata/services/media_ref.dart';

/// An in-memory [MediaStore] for widget tests.
///
/// Widget tests cannot touch the filesystem: real async I/O never completes
/// inside `testWidgets`' fake-async zone, so a `File.writeAsBytes` awaited
/// from a tap handler hangs the whole test until `pumpAndSettle` times out.
///
/// So the split is: this fake proves the *flow* — picked, cropped, stored,
/// shown, replaced, removed — and `test/services/avatar_media_test.dart`
/// proves the *disk rules* (naming, relative paths, re-encoding, deleting
/// the replaced file, refusing to escape the media directory) against a real
/// temp directory from plain `test()` bodies, where I/O does complete.
class FakeMediaStore implements MediaStore {
  FakeMediaStore({this.failWrites = false});

  /// Written media, keyed by the same relative path a record would store.
  final Map<String, Uint8List> files = {};

  /// Paths handed to [delete], in order.
  final List<String> deleted = [];

  /// Makes every write fail, for the rollback path.
  bool failWrites;

  int _writes = 0;

  @override
  Future<MediaRef> write(
    Uint8List bytes, {
    required String entity,
    required String id,
  }) async {
    // Encode first, exactly as the real store does, so bad bytes fail the
    // same way here and the test is not proving something kinder.
    final encoded = ImageEncoder.avatar(bytes);
    if (failWrites) throw const _WriteRefused();

    final path = '${LocalMediaStore.folder}/${entity}_${id}_${++_writes}.jpg';
    files[path] = encoded;
    return MediaRef(MediaSource.file, path);
  }

  @override
  Future<MediaRef> replace(
    Uint8List bytes, {
    required String entity,
    required String id,
    MediaRef? previous,
  }) async {
    final next = await write(bytes, entity: entity, id: id);
    if (previous != next) await delete(previous);
    return next;
  }

  @override
  Future<void> delete(MediaRef? ref) async {
    if (ref == null || ref.source != MediaSource.file) return;
    deleted.add(ref.path);
    files.remove(ref.path);
  }

  @override
  Future<ImageProvider?> imageFor(MediaRef? ref) async {
    if (ref == null) return null;
    if (ref.source == MediaSource.asset) return AssetImage(ref.assetKey);
    final bytes = files[ref.path];
    // Null for a record whose file is gone, like the real one.
    return bytes == null ? null : MemoryImage(bytes);
  }
}

class _WriteRefused implements Exception {
  const _WriteRefused();
  @override
  String toString() => 'no space left on device';
}
