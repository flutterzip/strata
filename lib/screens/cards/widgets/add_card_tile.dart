import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/pressable.dart';

/// The trailing tile in the carousel that starts the add-card flow.
class AddCardTile extends StatelessWidget {
  const AddCardTile({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Pressable(
      onTap: onTap,
      pressedScale: 0.97,
      semanticLabel: 'Add a card',
      semanticHint: 'Opens the form to add a debit or credit card',
      child: AspectRatio(
        aspectRatio: kCardAspect,
        child: DecoratedBox(
          // Opaque, not just a dashed outline. In the wallet stack this tile
          // sits on top of a real card, and a transparent fill lets the card
          // beneath show straight through it.
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: Radii.brCard,
          ),
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: scheme.outlineVariant,
              radius: Radii.card,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: Hit.min,
                    height: Hit.min,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary.withValues(alpha: 0.12),
                    ),
                    child: Icon(Icons.add_rounded,
                        color: scheme.primary, size: 24),
                  ),
                  const SizedBox(height: Space.md),
                  Text('Add a card', style: text.titleMedium),
                  const SizedBox(height: Space.xxs),
                  Text('Debit or credit, detected as you type',
                      style: text.bodySmall, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;

    const dash = 7.0, gap = 6.0;
    for (final m in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
