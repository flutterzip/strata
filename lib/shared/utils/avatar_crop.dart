import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Geometry for the circular avatar crop.
///
/// Kept out of the widget because this is the part that goes wrong: an
/// off-by-one in the mapping from what the finger did to what gets written
/// crops someone's forehead off, and that is far cheaper to catch in a unit
/// test than by looking at photographs.
///
/// The model is deliberately explicit rather than reading an
/// [InteractiveViewer]'s matrix back out:
///
/// - the viewport is a square of side `viewport`;
/// - the image is drawn at [coverScale] so it covers that square with no
///   letterboxing, then multiplied by the user's [scale] (>= 1);
/// - the result is centred, then moved by `offset` in viewport pixels;
/// - the crop is the viewport square, mapped back into source pixels.
abstract final class AvatarCrop {
  /// Smallest zoom the user can pull back to — full cover, nothing blank.
  static const double minScale = 1;

  /// Beyond this a 512px avatar is being enlarged from a handful of pixels.
  static const double maxScale = 4;

  /// Scale at which [image] just covers a square of side [viewport].
  ///
  /// The short edge decides it. Scaling by the long edge would letterbox,
  /// and a crop circle over a letterbox bar is a circle with a hole in it.
  static double coverScale(Size image, double viewport) {
    if (image.width <= 0 || image.height <= 0) return 1;
    return math.max(viewport / image.width, viewport / image.height);
  }

  /// Half the content that hangs outside the viewport, per axis, at [scale].
  /// This is exactly how far the image may be dragged before a gap appears.
  static Offset slack({
    required Size image,
    required double viewport,
    required double scale,
  }) {
    final drawn = coverScale(image, viewport) * scale;
    final w = image.width * drawn;
    final h = image.height * drawn;
    return Offset(
      math.max(0, (w - viewport) / 2),
      math.max(0, (h - viewport) / 2),
    );
  }

  /// Hold a pan inside the image.
  ///
  /// An axis with no slack is pinned to zero rather than merely limited: a
  /// wide photo at rest has nothing to spare vertically, and allowing even a
  /// pixel of drag would show empty space inside the circle.
  static Offset clampOffset(
    Offset offset, {
    required Size image,
    required double viewport,
    required double scale,
  }) {
    final limit = slack(image: image, viewport: viewport, scale: scale);
    return Offset(
      offset.dx.clamp(-limit.dx, limit.dx),
      offset.dy.clamp(-limit.dy, limit.dy),
    );
  }

  /// The square of source pixels currently inside the viewport.
  ///
  /// Returned in image coordinates, ready to hand to a crop. Always square,
  /// and always inside the image when [offset] has been through
  /// [clampOffset].
  static Rect sourceRect({
    required Size image,
    required double viewport,
    required double scale,
    required Offset offset,
  }) {
    if (image.width <= 0 || image.height <= 0 || viewport <= 0 || scale <= 0) {
      return Rect.zero;
    }

    final drawn = coverScale(image, viewport) * scale;
    final limit = slack(image: image, viewport: viewport, scale: scale);

    // Top-left of the visible square, in drawn pixels: the centred overflow,
    // less however far the user dragged.
    final left = (limit.dx - offset.dx) / drawn;
    final top = (limit.dy - offset.dy) / drawn;
    final side = viewport / drawn;

    // Clamp in source space too. The arithmetic above is exact, but a crop
    // that is one pixel over the edge throws rather than rounding.
    final maxLeft = math.max(0.0, image.width - side);
    final maxTop = math.max(0.0, image.height - side);

    return Rect.fromLTWH(
      left.clamp(0.0, maxLeft),
      top.clamp(0.0, maxTop),
      math.min(side, image.width),
      math.min(side, image.height),
    );
  }
}
