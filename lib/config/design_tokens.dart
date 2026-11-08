import 'package:flutter/widgets.dart';

/// Design tokens for Strata. Nothing in the UI layer hardcodes a raw value;
/// everything resolves through here or through [Theme.of].
abstract final class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

abstract final class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
  static const double xl = 24;
  static const double card = 22;
  static const double sheet = 28;
  static const double pill = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brCard = BorderRadius.all(Radius.circular(card));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}

/// Minimum interactive target, per WCAG / Material guidance.
abstract final class Hit {
  static const double min = 48;
  static const Size minSize = Size(min, min);
}

abstract final class Insets {
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: Space.xl);
  static const EdgeInsets field =
      EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md);
  static const EdgeInsets cardFace = EdgeInsets.all(Space.xl);
}

/// Responsive breakpoints (Material 3 window size classes).
abstract final class Breakpoints {
  static const double compact = 600;
  static const double medium = 840;

  static WindowClass of(double width) => width < compact
      ? WindowClass.compact
      : width < medium
          ? WindowClass.medium
          : WindowClass.expanded;
}

enum WindowClass { compact, medium, expanded }

/// Aspect ratio of a physical payment card (ISO/IEC 7810 ID-1).
const double kCardAspect = 1.586;
