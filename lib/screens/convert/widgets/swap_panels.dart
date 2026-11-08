import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../config/design_tokens.dart';
import '../../../config/motion.dart';

/// Two panels that exchange places on a spring.
///
/// This is the screen's one piece of real motion, so it is an exchange
/// rather than a cross-fade: each panel travels to the other's slot and bows
/// outwards on the way, so the eye can follow which one went where. A fade
/// would leave the reader with no idea whether the cards swapped or the
/// labels did.
///
/// Driven by [Motion.carousel] — the spring measured from the reference
/// clip — through [AnimationController.animateWith], so the overshoot and
/// settle match the card carousel instead of being a second, unrelated
/// feel. Reduce-motion skips straight to the result.
class SwapPanels extends StatefulWidget {
  const SwapPanels({
    super.key,
    required this.first,
    required this.second,
    required this.middle,
    required this.swapToken,
    this.panelHeight = 116,
    this.gap = Space.xxl,
  });

  /// The panel that starts on top.
  final Widget first;

  /// The panel that starts underneath.
  final Widget second;

  /// Sits between them, over the gap — the swap control.
  final Widget middle;

  /// Changes whenever the owner swaps. Each change runs one exchange; the
  /// parent has already swapped its own data by then, so the animation runs
  /// on the new content moving into place.
  final int swapToken;

  final double panelHeight;
  final double gap;

  @override
  State<SwapPanels> createState() => _SwapPanelsState();
}

class _SwapPanelsState extends State<SwapPanels>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swap =
      AnimationController(vsync: this, upperBound: double.infinity);

  @override
  void didUpdateWidget(SwapPanels old) {
    super.didUpdateWidget(old);
    if (old.swapToken == widget.swapToken) return;
    if (context.reduceMotion) {
      _swap.value = 0;
      return;
    }
    // From 1 back to 0: the content has already swapped, so the panels start
    // in each other's old slots and spring home. One pass, no repeat — an
    // ambient loop here would burn frames for as long as the screen is open.
    _swap.value = 1;
    _swap.animateWith(
      SpringSimulation(Motion.carousel, 1, 0, 0),
    );
  }

  @override
  void dispose() {
    _swap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final span = widget.panelHeight + widget.gap;

    return SizedBox(
      height: widget.panelHeight * 2 + widget.gap,
      child: AnimatedBuilder(
        animation: _swap,
        builder: (context, _) {
          final t = _swap.value;
          // Bow outwards as they pass, so two panels crossing read as two
          // objects rather than one dissolving into the other. Clamped
          // because the spring overshoots past its endpoint.
          final arc = math.sin(math.pi * t.clamp(0.0, 1.0)) * 16;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: span * t,
                left: arc,
                right: -arc,
                height: widget.panelHeight,
                child: widget.first,
              ),
              Positioned(
                top: span * (1 - t),
                left: -arc,
                right: arc,
                height: widget.panelHeight,
                child: widget.second,
              ),
              Positioned(
                top: widget.panelHeight - widget.gap / 2 - 22,
                left: 0,
                right: 0,
                height: 44,
                child: Center(child: widget.middle),
              ),
            ],
          );
        },
      ),
    );
  }
}
