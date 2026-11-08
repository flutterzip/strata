import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/design_tokens.dart';
import '../../config/motion.dart';

/// A tappable surface that dips under the finger.
///
/// The press response is what makes a custom control feel native when it is
/// not a Material button. Handles the haptic, the disabled state, the
/// accessibility annotation and the minimum target size in one place.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.semanticHint,
    this.pressedScale = 0.96,
    this.haptic = true,
    this.enforceMinTarget = true,
    this.dimWhenDisabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final String? semanticHint;

  /// Scale applied while held. Smaller surfaces want a shallower dip.
  final double pressedScale;

  final bool haptic;

  /// Pads the hit area out to the 48dp minimum when the visual is smaller.
  final bool enforceMinTarget;

  /// Fades the child when there is no handler. Correct for a control, wrong
  /// for an opaque surface that something is stacked beneath — set false
  /// there or the layer below shows through.
  final bool dimWhenDisabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    Widget result = AnimatedScale(
      scale: _pressed ? widget.pressedScale : 1,
      duration: context.motion(Motion.quick),
      curve: Motion.standard,
      child: Opacity(
        opacity: _enabled || !widget.dimWhenDisabled ? 1 : 0.45,
        child: widget.child,
      ),
    );

    if (widget.enforceMinTarget) {
      result = ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: Hit.min,
          minHeight: Hit.min,
        ),
        child: result,
      );
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _set(true) : null,
          onTapCancel: _enabled ? () => _set(false) : null,
          onTapUp: _enabled ? (_) => _set(false) : null,
          onTap: _enabled
              ? () {
                  if (widget.haptic) HapticFeedback.lightImpact();
                  widget.onTap!();
                }
              : null,
          child: result,
        ),
      ),
    );
  }
}
