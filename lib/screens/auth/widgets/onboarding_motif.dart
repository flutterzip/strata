import 'package:flutter/material.dart';

import '../../../config/palette.dart';

/// The illustration on an onboarding slide.
///
/// Drawn in code from the same geometry as the rest of the app — layered
/// slabs, sediment bands, the chart ramp — so the intro looks like the
/// product rather than like stock art bolted on the front.
///
/// [progress] runs 0 to 1 and drives the build-on, so each motif assembles
/// itself as its slide arrives rather than simply fading in.
class OnboardingMotif extends StatelessWidget {
  const OnboardingMotif({
    super.key,
    required this.motif,
    required this.progress,
    this.labels = const [],
  });

  final String motif;
  final double progress;

  /// Category names for the chart motif. Passed in from the same seed data
  /// the real chart uses, so the intro shows the actual product rather than
  /// abstract coloured blocks.
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 1.25,
        child: CustomPaint(
          painter: switch (motif) {
            'bars' => _BarsMotif(progress, isDark, labels),
            'shield' => _PrivacyMotif(progress, isDark),
            _ => _StackMotif(progress, isDark),
          },
        ),
      ),
    );
  }
}

/// Eased 0..1 slice of [t] for the [i]th of [n] elements, so parts of a
/// motif arrive in sequence instead of together.
double _step(double t, int i, int n) {
  const overlap = 0.45;
  final span = 1 / (n - (n - 1) * overlap);
  final start = i * span * (1 - overlap);
  final v = ((t - start) / span).clamp(0.0, 1.0);
  return Curves.easeOutCubic.transform(v);
}

/// Cards settling into a stack.
///
/// Drawn back to front and fanned downward, the way cards actually sit in a
/// wallet: the front card is lowest and fully visible, the ones behind it
/// show only their top edge. Each slab carries a rim and its own shadow, or
/// the overlapping gradients merge into one block of stripes.
class _StackMotif extends CustomPainter {
  const _StackMotif(this.t, this.isDark);
  final double t;
  final bool isDark;

  // Back to front, so the darkest card ends up in front.
  static const _skins = [CardSkin.sage, CardSkin.moss, CardSkin.forest];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cardW = w * 0.58, cardH = cardW / 1.586;
    // Enough travel between slabs that each top edge reads clearly.
    final step = cardH * 0.42;
    final firstTop = (h - (cardH + step * 2)) / 2;

    for (var i = 0; i < _skins.length; i++) {
      final p = _step(t, i, _skins.length);
      if (p <= 0) continue;

      // Each slab drops into place and straightens as it lands.
      final lift = (1 - p) * h * 0.22;
      final tilt = (1 - p) * 0.10 * (i.isEven ? 1 : -1);
      final centre = Offset(w * 0.5, firstTop + cardH / 2 + i * step + lift);

      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(tilt);

      final rect =
          Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(13));

      canvas.drawRRect(
        rrect.shift(const Offset(0, 8)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.22 * p)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawRRect(
        rrect,
        Paint()..shader = _skins[i].gradient.createShader(rect),
      );
      // Rim: without it the slabs blend into a single striped block.
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.22 * p),
      );

      // Chip and a masked number, so each slab reads as a card.
      final on = Colors.white.withValues(alpha: 0.65 * p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-cardW / 2 + 14, -cardH / 2 + 12, 19, 14),
          const Radius.circular(3.5),
        ),
        Paint()..color = on,
      );
      for (var d = 0; d < 4; d++) {
        canvas.drawCircle(
          Offset(-cardW / 2 + 16 + d * 7.0, cardH / 2 - 16),
          2,
          Paint()..color = on,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StackMotif old) => old.t != t || old.isDark != isDark;
}

/// The spending bar assembling, segment by segment, with the real category
/// names beside it.
///
/// An earlier version drew anonymous coloured pills, which told a new user
/// nothing. Naming the categories is the whole point of the screen.
class _BarsMotif extends CustomPainter {
  const _BarsMotif(this.t, this.isDark, this.labels);

  final double t;
  final bool isDark;
  final List<String> labels;

  static const _weights = [0.34, 0.26, 0.16, 0.14, 0.10];
  static const _fallback = [
    'Transfers',
    'Food',
    'Transport',
    'Groceries',
    'Subscriptions',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final names = labels.isEmpty ? _fallback : labels;
    final count = _weights.length;
    final w = size.width, h = size.height;
    final barW = w * 0.80, barH = h * 0.075;
    final left = (w - barW) / 2;
    final top = h * 0.10;

    final track = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barW, barH), Radius.circular(barH));
    canvas.drawRRect(
      track,
      Paint()
        ..color = (isDark ? Brand.inkDark : Brand.ink).withValues(alpha: 0.07),
    );

    // Clip to the track and draw plain rects inside it, exactly as the real
    // chart does. Rounding each segment separately turned one bar into a
    // row of unrelated capsules.
    canvas.save();
    canvas.clipRRect(track);
    var x = left;
    for (var i = 0; i < count; i++) {
      final p = _step(t, i, count);
      final segW = barW * _weights[i] * p;
      if (segW > 1) {
        canvas.drawRect(
          Rect.fromLTWH(x, top, segW - 2, barH),
          Paint()..color = ChartRamp.at(i, isDark),
        );
      }
      x += barW * _weights[i];
    }
    canvas.restore();

    // Named legend, two columns, rising into place with its segment.
    const rowH = 26.0;
    for (var i = 0; i < count && i < names.length; i++) {
      final p = _step(t, i, count);
      if (p <= 0.02) continue;
      final col = i % 2, row = i ~/ 2;
      final cx = left + col * (barW / 2);
      final cy = top + barH * 2.4 + row * rowH + (1 - p) * 10;

      canvas.drawCircle(Offset(cx + 5, cy + 5), 4.5,
          Paint()..color = ChartRamp.at(i, isDark).withValues(alpha: p));

      final tp = TextPainter(
        text: TextSpan(
          text: names[i],
          style: TextStyle(
            fontFamily: 'Bricolage',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: (isDark ? Brand.inkDark : Brand.ink)
                .withValues(alpha: 0.78 * p),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '\u2026',
      )..layout(maxWidth: barW / 2 - 24);
      tp.paint(canvas, Offset(cx + 16, cy - tp.height / 2 + 5));
    }
  }

  @override
  bool shouldRepaint(_BarsMotif old) =>
      old.t != t || old.isDark != isDark || old.labels != labels;
}

/// A card whose number dissolves, leaving only the last four.
///
/// Replaces an earlier shield, which was generic and read as a lump at
/// small sizes. This shows the actual promise: the digits are typed, then
/// they are gone, and only the tail survives.
class _PrivacyMotif extends CustomPainter {
  const _PrivacyMotif(this.t, this.isDark);
  final double t;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cardW = w * 0.72, cardH = cardW / 1.586;
    final rect = Rect.fromCenter(
        center: Offset(w / 2, h * 0.46), width: cardW, height: cardH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    final appear = _step(t, 0, 3);
    if (appear <= 0) return;

    canvas.drawRRect(
      rrect.shift(const Offset(0, 10)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20 * appear)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRRect(
      rrect,
      Paint()..shader = CardSkin.forest.gradient.createShader(rect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.20 * appear),
    );

    // Twelve digits fade and lift away; the final four settle in place.
    final vanish = _step(t, 1, 3);
    final keep = _step(t, 2, 3);
    final y = rect.center.dy + cardH * 0.10;
    const groups = 4, perGroup = 4;
    final slotW = cardW * 0.80 / (groups * perGroup);
    final startX = rect.left + cardW * 0.10 + slotW / 2;

    for (var i = 0; i < groups * perGroup; i++) {
      final isTail = i >= 12;
      final x = startX + i * slotW + (i ~/ perGroup) * slotW * 0.22;
      if (isTail) {
        // The last four arrive and stay.
        final tp = TextPainter(
          text: TextSpan(
            text: '4242'[i - 12],
            style: TextStyle(
              fontFamily: 'Bricolage',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: keep),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
      } else {
        // The rest lift and dissolve into a masking dot.
        final gone = vanish;
        if (gone < 1) {
          final tp = TextPainter(
            text: TextSpan(
              text: '8',
              style: TextStyle(
                fontFamily: 'Bricolage',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: (1 - gone) * 0.9),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(
              canvas, Offset(x - tp.width / 2, y - tp.height / 2 - gone * 14));
        }
        canvas.drawCircle(
          Offset(x, y),
          2.6 * gone,
          Paint()..color = Colors.white.withValues(alpha: 0.75 * gone),
        );
      }
    }

    // A small lock, closing as the digits go.
    final lockY = rect.top + cardH * 0.22;
    final lockX = rect.right - cardW * 0.14;
    final body = Rect.fromCenter(
        center: Offset(lockX, lockY + 4), width: 15, height: 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: 0.85 * vanish),
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(lockX, lockY - 3), width: 10, height: 11),
      3.14159,
      3.14159,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.85 * vanish),
    );
  }

  @override
  bool shouldRepaint(_PrivacyMotif old) => old.t != t || old.isDark != isDark;
}
