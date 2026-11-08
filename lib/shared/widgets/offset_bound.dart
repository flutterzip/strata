import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Renders one child per item, cross-faded against a *continuous* index.
///
/// This is the core of Strata's carousel feel. Instead of swapping content on
/// a page-change callback — which snaps at the end of a gesture — each child's
/// opacity and offset are a direct function of its distance from the live
/// fractional scroll position. Content therefore tracks the user's finger for
/// the whole drag, and inherits the carousel's spring on release for free.
class OffsetBound extends StatelessWidget {
  const OffsetBound({
    super.key,
    required this.offset,
    required this.count,
    required this.builder,
    this.slide = 18,
    this.falloff = 1.0,
    this.alignment = Alignment.topLeft,
  });

  /// Live fractional position, e.g. 1.37 while dragging between pages 1 and 2.
  final ValueListenable<double> offset;

  final int count;
  final Widget Function(BuildContext context, int index) builder;

  /// Vertical travel, in logical pixels, applied per unit of distance.
  final double slide;

  /// How quickly a child fades with distance. 1.0 means fully gone at Â±1.
  final double falloff;

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: offset,
      builder: (context, value, _) {
        // Only the one or two children within range can be visible, so this
        // never builds the whole list.
        final first = (value.floor() - 1).clamp(0, count - 1);
        final last = (value.ceil() + 1).clamp(0, count - 1);

        return Stack(
          alignment: alignment,
          children: [
            for (var i = first; i <= last; i++)
              if ((i - value).abs() < 1)
                _Layer(
                  key: ValueKey(i),
                  delta: i - value,
                  slide: slide,
                  falloff: falloff,
                  child: builder(context, i),
                ),
          ],
        );
      },
    );
  }
}

class _Layer extends StatelessWidget {
  const _Layer({
    super.key,
    required this.delta,
    required this.slide,
    required this.falloff,
    required this.child,
  });

  final double delta, slide, falloff;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = delta.abs();
    final opacity = (1 - d * falloff).clamp(0.0, 1.0);
    // Ease the fade so the midpoint of a swipe is not a flat 50/50 blend,
    // which reads as muddy.
    final eased = opacity * opacity;
    return IgnorePointer(
      ignoring: d > 0.5,
      child: Opacity(
        opacity: eased,
        child: Transform.translate(
          offset: Offset(0, delta * slide),
          child: child,
        ),
      ),
    );
  }
}
