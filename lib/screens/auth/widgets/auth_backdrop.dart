import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../config/motion.dart';
import '../../../config/palette.dart';

/// The ambient background shared by every auth screen.
///
/// Two soft masses drift on a long, non-repeating cycle, with the sediment
/// bands from the card artwork laid faintly over the top. Because the same
/// backdrop persists across onboarding, sign-in and PIN entry, moving between
/// those screens feels like moving within one place rather than between
/// unrelated pages.
///
/// Entirely generated: no image assets, so it costs nothing to ship and
/// recolours itself for light and dark from the theme.
class AuthBackdrop extends StatefulWidget {
  const AuthBackdrop({super.key, required this.child});

  final Widget child;

  @override
  State<AuthBackdrop> createState() => _AuthBackdropState();
}

class _AuthBackdropState extends State<AuthBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    // Long enough that the motion is never recognisably periodic.
    duration: const Duration(seconds: 42),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only run the drift when motion is wanted. A perpetual `repeat()`
    // burns a frame budget forever for someone who asked for reduced
    // motion, and it makes `pumpAndSettle` time out in every test that
    // renders an auth screen, since an endlessly repeating controller can
    // never settle.
    final wantsMotion = !context.reduceMotion;
    if (wantsMotion && !_drift.isAnimating) {
      _drift.repeat();
    } else if (!wantsMotion && _drift.isAnimating) {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    // Reduce-motion freezes the drift at a pleasant phase rather than
    // removing the artwork.
    final still = context.reduceMotion;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: scheme.surface),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _drift,
            builder: (context, _) => CustomPaint(
              painter: _DriftPainter(
                t: still ? 0.18 : _drift.value,
                isDark: isDark,
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _DriftPainter extends CustomPainter {
  const _DriftPainter({required this.t, required this.isDark});

  final double t;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final tau = t * math.pi * 2;

    void mass(Offset centre, double radius, Color colour) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [colour, colour.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    // Two masses on different periods, so they never line up the same way
    // twice within a session.
    mass(
      Offset(w * (0.22 + 0.10 * math.sin(tau)),
          h * (0.18 + 0.06 * math.cos(tau * 0.7))),
      w * 0.78,
      (isDark ? Brand.leafDark : Brand.leaf)
          .withValues(alpha: isDark ? 0.14 : 0.16),
    );
    mass(
      Offset(w * (0.86 + 0.08 * math.cos(tau * 1.3)),
          h * (0.74 + 0.05 * math.sin(tau * 0.9))),
      w * 0.70,
      (isDark ? Brand.sageMass : Brand.claySoft)
          .withValues(alpha: isDark ? 0.12 : 0.55),
    );

    // Sediment bands, the same motif as the card faces.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = (isDark ? Brand.inkDark : Brand.ink).withValues(alpha: 0.05);
    for (var i = 0; i < 7; i++) {
      final base = h * (0.30 + i * 0.09);
      final amp = h * 0.018 * (1 - i / 9);
      final phase = tau * 0.5 + i * 0.8;
      line.strokeWidth = 1 + i * 0.25;
      final path = Path()..moveTo(-w * 0.1, base);
      for (var x = -w * 0.1; x <= w * 1.1; x += w / 26) {
        path.lineTo(x, base + math.sin(x / w * math.pi * 2 + phase) * amp);
      }
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(_DriftPainter old) => old.t != t || old.isDark != isDark;
}
