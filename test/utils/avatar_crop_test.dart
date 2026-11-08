import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strata/shared/utils/avatar_crop.dart';

void main() {
  const viewport = 300.0;

  group('cover scale', () {
    test('a square image fills a square viewport exactly', () {
      expect(AvatarCrop.coverScale(const Size(600, 600), viewport), 0.5);
    });

    test('a wide image is scaled by its short edge, so nothing is letterboxed',
        () {
      // Scaling by the long edge would leave bars above and below, and a
      // crop circle over a bar is a circle with a hole in it.
      expect(AvatarCrop.coverScale(const Size(1200, 600), viewport), 0.5);
      expect(AvatarCrop.coverScale(const Size(600, 1200), viewport), 0.5);
    });
  });

  group('source rect at rest', () {
    test('a square image crops to the whole image', () {
      final r = AvatarCrop.sourceRect(
        image: const Size(600, 600),
        viewport: viewport,
        scale: 1,
        offset: Offset.zero,
      );
      expect(r.left, closeTo(0, 0.01));
      expect(r.top, closeTo(0, 0.01));
      expect(r.width, closeTo(600, 0.01));
      expect(r.height, closeTo(600, 0.01));
    });

    test('a wide image crops to its centre square', () {
      final r = AvatarCrop.sourceRect(
        image: const Size(2000, 1000),
        viewport: viewport,
        scale: 1,
        offset: Offset.zero,
      );
      expect(r.width, closeTo(1000, 0.01));
      expect(r.height, closeTo(1000, 0.01));
      expect(r.left, closeTo(500, 0.01));
      expect(r.top, closeTo(0, 0.01));
    });

    test('a tall image crops to its centre square', () {
      final r = AvatarCrop.sourceRect(
        image: const Size(1000, 2000),
        viewport: viewport,
        scale: 1,
        offset: Offset.zero,
      );
      expect(r.left, closeTo(0, 0.01));
      expect(r.top, closeTo(500, 0.01));
      expect(r.width, closeTo(1000, 0.01));
    });

    test('the crop is always square, whatever the source', () {
      for (final size in const [
        Size(4032, 3024),
        Size(3024, 4032),
        Size(1, 900),
        Size(900, 1),
      ]) {
        final r = AvatarCrop.sourceRect(
          image: size,
          viewport: viewport,
          scale: 1,
          offset: Offset.zero,
        );
        expect(r.width, closeTo(r.height, 0.01), reason: '$size');
      }
    });
  });

  group('zoom', () {
    test('doubling the zoom halves the source square, about the centre', () {
      final r = AvatarCrop.sourceRect(
        image: const Size(600, 600),
        viewport: viewport,
        scale: 2,
        offset: Offset.zero,
      );
      expect(r.width, closeTo(300, 0.01));
      expect(r.left, closeTo(150, 0.01));
      expect(r.top, closeTo(150, 0.01));
    });
  });

  group('panning', () {
    test('panning to the limit reaches the edge of the image, not past it', () {
      const image = Size(2000, 1000);
      final limit = AvatarCrop.clampOffset(
        const Offset(100000, 0),
        image: image,
        viewport: viewport,
        scale: 1,
      );
      final r = AvatarCrop.sourceRect(
        image: image,
        viewport: viewport,
        scale: 1,
        offset: limit,
      );
      expect(r.left, closeTo(0, 0.01));
      expect(r.right, closeTo(1000, 0.01));
    });

    test('panning the other way reaches the far edge', () {
      const image = Size(2000, 1000);
      final limit = AvatarCrop.clampOffset(
        const Offset(-100000, 0),
        image: image,
        viewport: viewport,
        scale: 1,
      );
      final r = AvatarCrop.sourceRect(
        image: image,
        viewport: viewport,
        scale: 1,
        offset: limit,
      );
      expect(r.right, closeTo(2000, 0.01));
    });

    test('an axis with nothing to spare cannot be panned at all', () {
      // A wide image at rest has no vertical slack; letting it drag would
      // expose empty space inside the crop circle.
      final clamped = AvatarCrop.clampOffset(
        const Offset(0, 500),
        image: const Size(2000, 1000),
        viewport: viewport,
        scale: 1,
      );
      expect(clamped.dy, 0);
    });

    test('zooming in creates slack on the axis that had none', () {
      final clamped = AvatarCrop.clampOffset(
        const Offset(0, 500),
        image: const Size(2000, 1000),
        viewport: viewport,
        scale: 2,
      );
      expect(clamped.dy, greaterThan(0));
    });

    test('the crop never leaves the image, however it is dragged', () {
      const image = Size(1280, 960);
      for (final scale in const [1.0, 1.7, 3.0]) {
        for (final drag in const [
          Offset(9999, 9999),
          Offset(-9999, -9999),
          Offset(9999, -9999),
        ]) {
          final r = AvatarCrop.sourceRect(
            image: image,
            viewport: viewport,
            scale: scale,
            offset: AvatarCrop.clampOffset(drag,
                image: image, viewport: viewport, scale: scale),
          );
          expect(r.left, greaterThanOrEqualTo(-0.01), reason: '$scale $drag');
          expect(r.top, greaterThanOrEqualTo(-0.01), reason: '$scale $drag');
          expect(r.right, lessThanOrEqualTo(image.width + 0.01),
              reason: '$scale $drag');
          expect(r.bottom, lessThanOrEqualTo(image.height + 0.01),
              reason: '$scale $drag');
        }
      }
    });
  });

  group('degenerate input', () {
    test('a zero-sized image does not divide by zero', () {
      final r = AvatarCrop.sourceRect(
        image: Size.zero,
        viewport: viewport,
        scale: 1,
        offset: Offset.zero,
      );
      expect(r, Rect.zero);
    });

    test('a zero viewport does not divide by zero', () {
      final r = AvatarCrop.sourceRect(
        image: const Size(600, 600),
        viewport: 0,
        scale: 1,
        offset: Offset.zero,
      );
      expect(r, Rect.zero);
    });
  });
}
