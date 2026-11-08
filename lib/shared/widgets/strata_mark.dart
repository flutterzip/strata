import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../config/motion.dart';

/// Strata's own logo glyph: three offset layers, drawn in code.
///
/// The same geometry is rendered to the app icon and launch image by
/// `tool/make_icons.py` — change one, change the other.
///
/// [reveal] animates the layers independently, top to bottom. At 1 a layer
/// sits in place at full strength; towards 0 it fades and slides out to
/// alternating sides by [travel] × width. The splash deals the layers in
/// with it and [StrataLoader] breathes through them.
class StrataMark extends StatelessWidget {
  const StrataMark({
    super.key,
    this.size = 28,
    this.color,
    this.reveal = const [1, 1, 1],
    this.travel = 0.5,
  }) : assert(reveal.length == 3);

  /// Width. Height is always 0.72 × width.
  final double size;
  final Color? color;
  final List<double> reveal;
  final double travel;

  static const double aspect = 0.72;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(size, size * aspect),
        painter: _MarkPainter(
          color ?? Theme.of(context).colorScheme.onSurface,
          reveal,
          travel,
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color, this.reveal, this.travel);
  final Color color;
  final List<double> reveal;
  final double travel;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final slab = h * 0.26;
    final skew = w * 0.16;
    final paint = Paint()..style = PaintingStyle.fill;

    // Three stacked strata, each offset and progressively more transparent.
    for (var i = 0; i < 3; i++) {
      final r = reveal[i].clamp(0.0, 1.2);
      if (r <= 0) continue;
      final top = i * (h - slab) / 2;
      final slide = (1 - r) * w * travel * (i.isEven ? -1 : 1);
      final dx = (i.isEven ? 0.0 : skew) + slide;
      paint.color = color.withValues(alpha: (1 - i * 0.28) * r.clamp(0.0, 1.0));
      final path = Path()
        ..moveTo(dx, top + slab)
        ..lineTo(dx + skew, top)
        ..lineTo(w - (i.isEven ? skew : 0) + slide, top)
        ..lineTo(w - (i.isEven ? 0 : skew) + slide, top + slab)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.color != color ||
      old.travel != travel ||
      !listEquals(old.reveal, reveal);
}

/// Strata's loading indicator: the mark's three layers breathing in turn.
///
/// Replaces the stock spinner wherever the app is waiting on purpose (see
/// `AppTiming`). It only animates while it is mounted, and under
/// reduce-motion it is the still mark at reduced strength.
class StrataLoader extends StatefulWidget {
  const StrataLoader({super.key, this.size = 22, this.color, this.label});

  final double size;
  final Color? color;

  /// Read to screen readers. Defaults to "Loading".
  final String? label;

  @override
  State<StrataLoader> createState() => _StrataLoaderState();
}

class _StrataLoaderState extends State<StrataLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Motion.loaderCycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: widget.label ?? 'Loading',
      liveRegion: true,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          if (context.reduceMotion) {
            return StrataMark(
                size: widget.size, color: color.withValues(alpha: 0.7));
          }
          // A wave running down the stack: each layer lags the one above by
          // a third of a cycle, dipping to 30% and nudging sideways.
          final t = _pulse.value;
          final reveal = [
            for (var i = 0; i < 3; i++)
              0.3 + 0.7 * (0.5 + 0.5 * math.cos((t - i / 3) * math.pi * 2)),
          ];
          return StrataMark(
            size: widget.size,
            color: color,
            reveal: reveal,
            travel: 0.18,
          );
        },
      ),
    );
  }
}

/// The layered line texture on a card face. Original composition: a set of
/// phase-shifted sediment bands whose amplitude decays toward the top.
class StrataTexturePainter extends CustomPainter {
  const StrataTexturePainter({
    required this.tint,
    required this.highlight,
    this.seed = 0,
    this.sheen = 0,
  });

  final Color tint;
  final Color highlight;
  final int seed;

  /// 0..1 — position of the moving specular band across the face.
  final double sheen;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rnd = math.Random(seed);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const bands = 9;
    for (var i = 0; i < bands; i++) {
      final t = i / (bands - 1);
      final baseY = h * (0.34 + t * 0.78);
      final amp = h * 0.055 * (1 - t * 0.55);
      final phase = rnd.nextDouble() * math.pi * 2;
      stroke
        ..strokeWidth = 1.1 + t * 1.5
        ..color = tint.withValues(alpha: 0.05 + 0.07 * (1 - t));

      final path = Path()..moveTo(-w * 0.1, baseY);
      for (var x = -w * 0.1; x <= w * 1.1; x += w / 28) {
        final y = baseY + math.sin(x / w * math.pi * 2.1 + phase) * amp;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, stroke);
    }

    // Corner bloom.
    canvas.drawCircle(
      Offset(w * 0.86, h * 0.1),
      w * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            highlight.withValues(alpha: 0.26),
            highlight.withValues(alpha: 0)
          ],
        ).createShader(Rect.fromCircle(
            center: Offset(w * 0.86, h * 0.1), radius: w * 0.42)),
    );

    // Specular sweep, bound to [sheen] so it can track scroll or tilt.
    if (sheen > 0) {
      final cx = (sheen * 1.6 - 0.3) * w;
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              highlight.withValues(alpha: 0),
              highlight.withValues(alpha: 0.13),
              highlight.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(
              Rect.fromLTWH(cx - w * 0.45, -h * 0.2, w * 0.9, h * 1.4)),
      );
    }
  }

  @override
  bool shouldRepaint(StrataTexturePainter old) =>
      old.tint != tint || old.highlight != highlight || old.sheen != sheen;
}
