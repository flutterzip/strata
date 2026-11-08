import 'package:flutter/widgets.dart';

import '../../config/motion.dart';

/// Fades and lifts a child into place from one slice of an entrance
/// controller.
///
/// Pair with [Motion.stage] to cut a single controller into overlapping
/// steps: one ticker for the whole screen, and the steps cannot drift apart.
/// Collapses to a plain pass-through when the platform asks for reduced
/// motion.
class StageTransition extends StatelessWidget {
  const StageTransition({
    super.key,
    required this.animation,
    required this.child,
    this.rise = 18,
  });

  final Animation<double> animation;

  /// Distance in logical pixels the child travels upward as it appears.
  final double rise;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * rise),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
