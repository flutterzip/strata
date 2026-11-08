import 'package:flutter/material.dart';

/// Strata's motion system.
///
/// The carousel spring is not a guess. It was fitted from 60fps frame-by-frame
/// tracking of card displacement: per-frame velocity decayed at a constant
/// ratio (0.835-0.859), which is the signature of exponential decay — a spring,
/// not a fixed-duration curve. Measured decay sigma ~= 9.1-10.8/s, and the
/// velocity sign reverses on settle, so the system is slightly underdamped.
///
///   sigma = zeta * omega_n   =>   with zeta 0.90 and mass 0.5,
///   omega_n = 11.1 rad/s  =>  stiffness = m * omega_n^2 = 61.7
///
/// Flutter's stock PageView spring decays at sigma = 15.6/s, which is visibly
/// snappier and less fluid than what we are matching.
abstract final class Motion {
  // ---------------------------------------------------------------- springs
  /// Fitted carousel spring. Interruptible and velocity-aware by construction.
  static final SpringDescription carousel = SpringDescription.withDampingRatio(
    mass: 0.5,
    stiffness: 62,
    ratio: 0.9,
  );

  /// Slightly firmer spring for small UI elements that should feel crisp
  /// (selection chips, toggles) without the carousel's long tail.
  static final SpringDescription snappy = SpringDescription.withDampingRatio(
    mass: 0.5,
    stiffness: 140,
    ratio: 0.92,
  );

  /// Gentle spring for large surfaces entering the screen.
  static final SpringDescription sheet = SpringDescription.withDampingRatio(
    mass: 0.6,
    stiffness: 90,
    ratio: 1.0,
  );

  // -------------------------------------------------------------- durations
  /// Tight band for ordinary UI feedback.
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration quick = Duration(milliseconds: 130);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration gentle = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 380);

  /// One breath of [StrataLoader] — the wave through all three layers.
  static const Duration loaderCycle = Duration(milliseconds: 1100);

  /// Label ↔ loader cross-fade inside a busy button.
  static const Duration busySwap = Duration(milliseconds: 220);

  /// Staged entrance for a full screen.
  static const Duration entrance = Duration(milliseconds: 900);

  // ----------------------------------------------------------------- curves
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasised = Curves.easeOutBack;
  static const Curve exit = Curves.easeInCubic;
  static const Curve inOut = Curves.easeInOutCubic;

  /// Long, soft deceleration for large brand moments (the splash). Quintic
  /// rather than cubic so the last 30% is almost all settle.
  static const Curve brand = Curves.easeOutQuint;

  /// A small overshoot for the splash's dealt layers — enough to read as
  /// physical, not enough to wobble.
  static const Curve deal = Cubic(0.2, 1.25, 0.32, 1);

  // --------------------------------------------------------------- stagger
  /// Slice a single 0..1 controller into an overlapping stagger step.
  ///
  /// One controller driving N intervals costs one ticker instead of N, and
  /// guarantees the steps can never drift out of sync.
  static Animation<double> stage(
    Animation<double> parent, {
    required double begin,
    required double end,
    Curve curve = standard,
  }) {
    assert(begin >= 0 && end <= 1 && begin < end);
    return parent.drive(CurveTween(curve: Interval(begin, end, curve: curve)));
  }
}

/// Respects the platform "reduce motion" accessibility setting.
///
/// Every animated surface in Strata routes through this. When a user has asked
/// the system to reduce motion we collapse animations to near-zero rather than
/// shipping vestibular triggers.
extension MotionAccess on BuildContext {
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// Scales a duration to zero when reduce-motion is on.
  Duration motion(Duration d) => reduceMotion ? Duration.zero : d;

  /// Returns [value] normally, or [reduced] when reduce-motion is on.
  T ifMotion<T>(T value, T reduced) => reduceMotion ? reduced : value;
}

/// [ScrollPhysics] for the card carousel, driven by [Motion.carousel].
///
/// Extends [PageScrollPhysics] so page snapping and fling targeting still
/// apply; only the settle spring is replaced.
class StrataPagePhysics extends PageScrollPhysics {
  const StrataPagePhysics({super.parent});

  @override
  StrataPagePhysics applyTo(ScrollPhysics? ancestor) =>
      StrataPagePhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => Motion.carousel;
}
