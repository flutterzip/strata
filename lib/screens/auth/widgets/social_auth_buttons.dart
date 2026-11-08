import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';
import '../../../models/auth_models.dart';
import '../../../shared/widgets/busy_button.dart';

/// "Sign in with Apple" and "Sign in with Google", stacked, followed by an
/// "or with email" rule leading into the form.
///
/// These two buttons are the one place the app steps outside its own
/// palette. Apple and Google both publish button rules — Apple's mark on
/// black (or white in dark mode), Google's four-colour G on a neutral
/// surface — and a sign-in button that ignores them is rejected in review
/// and, worse, is not recognised at a glance. Everything else (height,
/// radius, type, the loading state) matches the rest of the form.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    required this.verb,
    required this.onPressed,
    this.pending,
    this.enabled = true,
  });

  /// "Sign in" or "Sign up" — the provider's name is appended.
  final String verb;

  final ValueChanged<SocialProvider> onPressed;

  /// The provider currently working, if any. It shows the loader; the
  /// other button is disabled.
  final SocialProvider? pending;

  /// False while the email form is submitting.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final idle = enabled && pending == null;

    // Apple: black in light mode, white in dark.
    final appleBg = isDark ? Colors.white : Colors.black;
    final appleFg = isDark ? Colors.black : Colors.white;
    // Google: their neutral light / dark button surfaces.
    final googleBg = isDark ? const Color(0xFF131314) : Colors.white;
    final googleFg = isDark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F);
    final googleLine =
        isDark ? const Color(0xFF8E918F) : const Color(0xFF747775);

    ButtonStyle style(Color bg, Color fg, {Color? line}) =>
        FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.5),
          disabledForegroundColor: fg.withValues(alpha: 0.5),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: Radii.brLg,
            side: line == null ? BorderSide.none : BorderSide(color: line),
          ),
          textStyle: text.labelLarge,
          elevation: 0,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BusyButton(
          label: '$verb with Apple',
          busy: pending == SocialProvider.apple,
          onPressed: idle ? () => onPressed(SocialProvider.apple) : null,
          style: style(appleBg, appleFg),
          loaderColor: appleFg,
          leading: Padding(
            // The glyph's optical centre sits high; nudge it onto the
            // text's baseline band.
            padding: const EdgeInsets.only(bottom: 2),
            child: Icon(Icons.apple, size: 22, color: appleFg),
          ),
        ),
        const SizedBox(height: Space.md),
        BusyButton(
          label: '$verb with Google',
          busy: pending == SocialProvider.google,
          onPressed: idle ? () => onPressed(SocialProvider.google) : null,
          style: style(googleBg, googleFg, line: googleLine),
          loaderColor: googleFg,
          leading: const GoogleGlyph(size: 18),
        ),
        const SizedBox(height: Space.xxl),
        ExcludeSemantics(
          child: Row(
            children: [
              Expanded(child: Divider(color: scheme.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: Text('or with email', style: text.labelSmall),
              ),
              Expanded(child: Divider(color: scheme.outlineVariant)),
            ],
          ),
        ),
        const SizedBox(height: Space.xxl),
      ],
    );
  }
}

/// Google's "G", drawn in code in its four brand colours.
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: const _GooglePainter(),
        ),
      );
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.2;
    final c = Offset(s / 2, s / 2);
    final r = (s - stroke) / 2;
    final ring = Rect.fromCircle(center: c, radius: r);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    double deg(double d) => d * math.pi / 180;

    // Clockwise from 3 o'clock. The opening sits at the upper right.
    canvas.drawArc(ring, deg(-2), deg(48), false, p..color = _blue);
    canvas.drawArc(ring, deg(44), deg(98), false, p..color = _green);
    canvas.drawArc(ring, deg(140), deg(72), false, p..color = _yellow);
    canvas.drawArc(ring, deg(210), deg(106), false, p..color = _red);

    // The crossbar, from the centre out to the ring's outer edge.
    canvas.drawRect(
      Rect.fromLTRB(
          c.dx - stroke * 0.05, c.dy - stroke / 2, s, c.dy + stroke / 2),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GooglePainter old) => false;
}
