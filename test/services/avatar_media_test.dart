import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:strata/services/avatar_store.dart';
import 'package:strata/services/image_encoder.dart';
import 'package:strata/services/media_ref.dart';

/// A recognisable test photo: a gradient, so a crop can be told from the
/// original by looking at a pixel.
Uint8List photo(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(
          x, y, (x * 255 / width).round(), (y * 255 / height).round(), 120);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('avatar encoding', () {
    test('downscales the long edge and keeps the aspect ratio', () {
      final out = ImageEncoder.avatar(photo(3000, 2000), maxEdge: 512);
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 512);
      expect(decoded.height, 341);
    });

    test('downscales a portrait photo on its own long edge', () {
      final out = ImageEncoder.avatar(photo(2000, 3000), maxEdge: 512);
      final decoded = img.decodeImage(out)!;
      expect(decoded.height, 512);
      expect(decoded.width, 341);
    });

    test('leaves an already-small photo alone rather than upscaling it', () {
      // Upscaling invents detail and costs bytes for nothing.
      final out = ImageEncoder.avatar(photo(200, 150), maxEdge: 512);
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 200);
      expect(decoded.height, 150);
    });

    test('re-encodes as JPEG, small enough to store', () {
      // A 12MP camera photo stored raw bloats every backup and stalls the
      // first paint; this is the whole reason the step exists. The absolute
      // ceiling is what matters — a synthetic gradient is not a photograph
      // and PNG happens to compress it better than JPEG does.
      final out = ImageEncoder.avatar(photo(3000, 2000));
      expect(img.findFormatForData(out), img.ImageFormat.jpg);
      expect(out.length, lessThan(64 * 1024));
    });

    test('rejects bytes that are not an image, rather than writing rubbish',
        () {
      expect(() => ImageEncoder.avatar(Uint8List.fromList([1, 2, 3, 4])),
          throwsA(isA<ImageDecodeException>()));
    });
  });

  group('avatar storage', () {
    late Directory dir;
    late LocalMediaStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('strata_media_test');
      store = LocalMediaStore(resolveMediaDir: () async => dir);
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('names the file itself and stores a relative reference', () async {
      // The picker's own name can collide, contain anything, or be absent.
      // An absolute path breaks on reinstall, because the app container is
      // a new UUID every time — this is the most common way photo features
      // break.
      final ref =
          await store.write(photo(600, 600), entity: 'avatar', id: 'me');

      expect(ref.source, MediaSource.file);
      expect(ref.path, startsWith('media/avatar_me_'));
      expect(ref.path, endsWith('.jpg'));
      expect(ref.encoded, isNot(contains(dir.path)));
      expect(ref.encoded, startsWith('file:media/'));
    });

    test('actually writes the bytes, re-encoded', () async {
      final ref =
          await store.write(photo(2000, 2000), entity: 'avatar', id: 'me');
      final file = File('${dir.path}/${ref.path.split('/').last}');

      expect(await file.exists(), isTrue);
      final decoded = img.decodeImage(await file.readAsBytes())!;
      expect(decoded.width, 512);
    });

    test('two writes in a row cannot collide', () async {
      final a = await store.write(photo(100, 100), entity: 'avatar', id: 'me');
      final b = await store.write(photo(100, 100), entity: 'avatar', id: 'me');
      expect(a.path, isNot(b.path));
    });

    test('deleting removes the file from disk', () async {
      final ref =
          await store.write(photo(100, 100), entity: 'avatar', id: 'me');
      final file = File('${dir.path}/${ref.path.split('/').last}');
      expect(await file.exists(), isTrue);

      await store.delete(ref);
      expect(await file.exists(), isFalse);
    });

    test('deleting a file that is already gone is not an error', () async {
      // The record can outlive the file — restored backups, cleared storage.
      await store.delete(const MediaRef(MediaSource.file, 'media/ghost.jpg'));
    });

    test('refuses to delete a bundled asset', () async {
      // An asset ref is read-only and shipped with the app; treating it like
      // user media would try to unlink something inside the bundle.
      await store.delete(const MediaRef(MediaSource.asset, 'avatars/demo.png'));
      expect(await dir.list().isEmpty, isTrue);
    });

    test('refuses to delete outside the media directory', () async {
      // A stored path is data, and data with "../" in it must not be able to
      // reach the rest of the container.
      final outside = File('${dir.parent.path}/strata_do_not_delete.txt');
      await outside.writeAsString('keep me');
      addTearDown(() async {
        if (await outside.exists()) await outside.delete();
      });

      await store.delete(const MediaRef(
          MediaSource.file, 'media/../strata_do_not_delete.txt'));

      expect(await outside.exists(), isTrue);
    });

    test('replacing deletes the file it replaced', () async {
      final old =
          await store.write(photo(100, 100), entity: 'avatar', id: 'me');
      final oldFile = File('${dir.path}/${old.path.split('/').last}');

      final next = await store.replace(
        photo(120, 120),
        entity: 'avatar',
        id: 'me',
        previous: old,
      );

      expect(await oldFile.exists(), isFalse);
      expect(await File('${dir.path}/${next.path.split('/').last}').exists(),
          isTrue);
    });

    test('a written avatar is still there on the next launch', () async {
      // Same storage, a fresh store instance: what the next launch does.
      final written =
          await store.write(photo(700, 700), entity: 'avatar', id: 'me');

      final relaunched = LocalMediaStore(resolveMediaDir: () async => dir);
      final image = await relaunched.imageFor(written);

      expect(image, isA<FileImage>());
      expect(
        await File('${dir.path}/${written.path.split('/').last}').exists(),
        isTrue,
      );
    });

    test('a record whose file is gone resolves to nothing, not a crash',
        () async {
      final image = await store
          .imageFor(const MediaRef(MediaSource.file, 'media/ghost.jpg'));
      expect(image, isNull);
    });

    test('an asset reference resolves without touching the media directory',
        () async {
      final image = await store
          .imageFor(const MediaRef(MediaSource.asset, 'avatars/demo.png'));
      expect(image, isA<AssetImage>());
    });

    test('refuses to read outside the media directory', () async {
      final image = await store
          .imageFor(const MediaRef(MediaSource.file, 'media/../../etc/passwd'));
      expect(image, isNull);
    });

    test('a failed write leaves the old file in place', () async {
      final old =
          await store.write(photo(100, 100), entity: 'avatar', id: 'me');
      final oldFile = File('${dir.path}/${old.path.split('/').last}');

      await expectLater(
        store.replace(Uint8List.fromList([0, 1, 2]),
            entity: 'avatar', id: 'me', previous: old),
        throwsA(isA<ImageDecodeException>()),
      );

      expect(await oldFile.exists(), isTrue);
    });
  });
}
