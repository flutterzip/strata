import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The bytes handed over were not a picture we can read.
///
/// Typed rather than a bare [FormatException] so the UI can tell "that file
/// is not an image" apart from "the disk is full", and say the right thing.
class ImageDecodeException implements Exception {
  const ImageDecodeException([this.message = 'That file is not an image.']);

  final String message;

  @override
  String toString() => 'ImageDecodeException: $message';
}

/// Re-encoding for user-supplied images.
///
/// A 12MP camera photo is ~4MB and 4000px wide. Stored raw it bloats every
/// backup, stalls the first paint and is displayed at 62dp regardless. The
/// rule from `assets/data/README.md` is: downscale to the largest size
/// actually shown, then JPEG at ~85%.
abstract final class ImageEncoder {
  /// Longest edge of a stored avatar. 512 covers the 62dp circle on a 3x
  /// screen four times over, which leaves room for the crop step.
  static const int avatarMaxEdge = 512;

  static const int defaultQuality = 85;

  /// Downscale [bytes] so its long edge is at most [maxEdge], and re-encode
  /// as JPEG.
  ///
  /// Never upscales: enlarging a small photo invents detail and costs bytes
  /// for nothing.
  static Uint8List avatar(
    Uint8List bytes, {
    int maxEdge = avatarMaxEdge,
    int quality = defaultQuality,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const ImageDecodeException();

    final longEdge =
        decoded.width > decoded.height ? decoded.width : decoded.height;

    final sized = longEdge <= maxEdge
        ? decoded
        : img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxEdge : null,
            height: decoded.height > decoded.width ? maxEdge : null,
            interpolation: img.Interpolation.average,
          );

    return Uint8List.fromList(img.encodeJpg(sized, quality: quality));
  }

  /// Crop [bytes] to [rect] in source-pixel coordinates, then size and
  /// encode it as an avatar.
  ///
  /// The rect is clamped to the image, so a crop box dragged past the edge
  /// yields the edge rather than throwing or wrapping.
  static Uint8List croppedAvatar(
    Uint8List bytes, {
    required int x,
    required int y,
    required int width,
    required int height,
    int maxEdge = avatarMaxEdge,
    int quality = defaultQuality,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const ImageDecodeException();

    final left = x.clamp(0, decoded.width - 1);
    final top = y.clamp(0, decoded.height - 1);
    final w = width.clamp(1, decoded.width - left);
    final h = height.clamp(1, decoded.height - top);

    final cropped = img.copyCrop(decoded, x: left, y: top, width: w, height: h);

    final longEdge =
        cropped.width > cropped.height ? cropped.width : cropped.height;
    final sized = longEdge <= maxEdge
        ? cropped
        : img.copyResize(
            cropped,
            width: cropped.width >= cropped.height ? maxEdge : null,
            height: cropped.height > cropped.width ? maxEdge : null,
            interpolation: img.Interpolation.average,
          );

    return Uint8List.fromList(img.encodeJpg(sized, quality: quality));
  }
}
