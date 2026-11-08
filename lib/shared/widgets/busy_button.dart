import 'package:flutter/material.dart';

import '../../config/motion.dart';
import 'strata_mark.dart';

/// A full-width button with a built-in loading state.
///
/// While [busy] it keeps its colour — a button that greys out the moment
/// you press it reads as "refused", not "working" — swaps its label for a
/// [StrataLoader] and ignores further taps. The height never changes, so
/// nothing below it jumps.
///
/// [onPressed] null is the real disabled state (another action is running,
/// or the form is not ready), and that one *does* dim.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.leading,
    this.style,
    this.loaderColor,
    this.busyLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  /// An icon or glyph before the label (Apple, Google).
  final Widget? leading;

  /// Overrides the theme's `FilledButton` style.
  final ButtonStyle? style;

  /// Defaults to the button's foreground colour.
  final Color? loaderColor;

  /// What a screen reader hears while busy. Defaults to "[label], loading".
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = loaderColor ??
        style?.foregroundColor?.resolve(const {}) ??
        scheme.onPrimary;

    final content = AnimatedSwitcher(
      duration: context.motion(Motion.busySwap),
      switchInCurve: Motion.standard,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.86, end: 1.0).animate(a),
          child: child,
        ),
      ),
      child: busy
          ? StrataLoader(
              key: const ValueKey('busy'),
              size: 24,
              color: fg,
              label: busyLabel ?? '$label, loading',
            )
          : Row(
              key: const ValueKey('idle'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    return IgnorePointer(
      ignoring: busy,
      child: FilledButton(
        style: style,
        // Busy keeps an (inert) handler so the enabled colours stay.
        onPressed: busy ? () {} : onPressed,
        child: content,
      ),
    );
  }
}
