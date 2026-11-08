import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_brand.dart';
import '../../config/app_timing.dart';
import '../../config/motion.dart';
import '../../config/palette.dart';
import '../../providers/auth_providers.dart';
import '../../shared/widgets/strata_mark.dart';

/// The branded splash, laid over the app's first screen until it is ready.
///
/// The native launch screen is plain paper in the same colour as this
/// widget's first frame, so the hand-off from iOS / Android is invisible.
/// From there, one timeline ([AppTiming.splashIntro]):
///
///   1. the mark's three strata are dealt in from alternating sides, each
///      landing with a small overshoot, a light haptic on the last;
///   2. the mark lifts, and the wordmark rises letter by letter out of a
///      clipped baseline beneath it;
///   3. a hairline draws outward and the tagline settles in, its tracking
///      tightening as it arrives.
///
/// It then rests ([AppTiming.splashHold]) and waits for the stored auth
/// stage, so it can never leave onto a half-loaded screen. Only then is the
/// real first screen mounted underneath — so *its* entrance animation plays
/// as the splash dissolves ([AppTiming.splashExit]) rather than finishing
/// unseen behind it.
///
/// All timings live in `config/app_timing.dart`. Reduce-motion gets a still
/// logo and a plain fade. `--dart-define=timingScale=0` skips it entirely.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  /// On the splash's own view, so tests can tell whether it is up.
  static const Key viewKey = ValueKey('splash');

  /// True while the splash is on screen. Overlays mounted above the
  /// Navigator (the demo control) listen to it and stay out of the way.
  static final ValueNotifier<bool> showing =
      ValueNotifier<bool>(AppTiming.scale > 0);

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate>
    with TickerProviderStateMixin {
  static final bool _skip = AppTiming.scale <= 0;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: AppTiming.splashIntro * AppTiming.scale,
  )..addListener(_hapticOnLanding);

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: AppTiming.splashExit * AppTiming.scale,
  );

  /// The first screen is mounted (under the splash).
  bool _revealed = _skip;

  /// The splash is fully gone and removed from the tree.
  bool _gone = _skip;

  static const Key _appKey = ValueKey('splash-gate-app');
  static const Key _overlayKey = ValueKey('splash-gate-overlay');

  bool _started = false;
  bool _buzzed = false;

  /// Where on the intro timeline the last stratum lands.
  static const double _landing = 0.56;

  @override
  void initState() {
    super.initState();
    SplashGate.showing.value = !_skip;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !_skip) {
      _started = true;
      unawaited(_run(reduce: context.reduceMotion));
    }
  }

  void _hapticOnLanding() {
    if (!_buzzed && _intro.value >= _landing) {
      _buzzed = true;
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _run({required bool reduce}) async {
    // Start loading where to go next while the intro plays.
    final ready = ref
        .read(authProvider.future)
        .then<void>((_) {}, onError: (Object _) {});

    if (reduce) {
      _intro.value = 1;
      _buzzed = true;
      await AppTiming.wait(AppTiming.splashStill);
    } else {
      await _intro.forward().orCancel.catchError((Object _) {});
    }
    await Future.wait([AppTiming.wait(AppTiming.splashHold), ready]);
    if (!mounted) return;

    setState(() => _revealed = true);
    SplashGate.showing.value = false;
    if (reduce) _exit.duration = Motion.slow;
    await _exit.forward().orCancel.catchError((Object _) {});
    if (mounted) setState(() => _gone = true);
  }

  @override
  void dispose() {
    SplashGate.showing.value = false;
    _intro.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The tree keeps one shape from first frame to last, and the app is a
    // keyed child of it. Returning `widget.child` bare once the splash had
    // gone moved it to a new place in the tree, so Flutter discarded the
    // first screen and built it again — it played its entrance twice, a
    // visible flash straight after the splash. Removing the overlay now
    // only drops the trailing child; the app's element survives.
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_revealed) KeyedSubtree(key: _appKey, child: widget.child),
        if (!_gone)
          // Inert once the first screen is underneath, so a quick tap
          // during the dissolve reaches it.
          IgnorePointer(
            key: _overlayKey,
            ignoring: _revealed,
            child: _SplashView(
              key: SplashGate.viewKey,
              intro: _intro,
              exit: _exit,
              reduce: context.reduceMotion,
            ),
          ),
      ],
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView({
    super.key,
    required this.intro,
    required this.exit,
    required this.reduce,
  });

  final Animation<double> intro;
  final Animation<double> exit;
  final bool reduce;

  /// Opening mark width. Lands at the optical centre of the screen.
  static const double _markWidth = 76;

  /// How far the mark lifts to make room for the wordmark.
  static const double _lift = 50;

  /// Interval-curved slice of [intro] at [t].
  static double _at(double t, double begin, double end,
      [Curve curve = Motion.brand]) {
    if (t <= begin) return 0;
    if (t >= end) return 1;
    return curve.transform((t - begin) / (end - begin));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final text = theme.textTheme;

    return Semantics(
      label: '${AppBrand.name}. ${AppBrand.tagline}',
      container: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: Listenable.merge([intro, exit]),
          builder: (context, _) {
            final t = intro.value;
            final e = exit.value;

            // --- exit: background dissolves a beat after the content.
            final fadeContent = 1 - _at(e, 0.0, 0.62, Curves.easeInCubic);
            final fadeGround = 1 - _at(e, 0.18, 1.0, Curves.easeInOutCubic);
            final exitLift = reduce ? 0.0 : -26 * _at(e, 0, 1, Curves.easeIn);
            final exitScale = reduce ? 1.0 : 1 + 0.035 * _at(e, 0, 1);

            // --- 1. the strata are dealt in, top layer first.
            final reveal = [
              for (var i = 0; i < 3; i++)
                _at(t, 0.04 + i * 0.08, 0.40 + i * 0.08, Motion.deal),
            ];
            final markScale = 0.9 + 0.1 * _at(t, 0.0, 0.55);

            // --- 2. lift and wordmark.
            final up = _at(t, 0.42, 0.80);

            // --- 3. hairline and tagline.
            final line = _at(t, 0.62, 0.92);
            final tag = _at(t, 0.68, 1.0);

            final bloom = _at(t, 0.0, 0.75);
            final markColor = scheme.onSurface;

            return Opacity(
              opacity: fadeGround,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: scheme.surface),
                  // A soft accent bloom that gathers behind the mark and
                  // spreads as the splash leaves.
                  CustomPaint(
                    painter: _BloomPainter(
                      strength: bloom * (1 - _at(e, 0.0, 0.8)),
                      spread: 0.55 + 0.45 * bloom + 0.6 * _at(e, 0, 1),
                      lift: -_lift * up * 0.6,
                      color: (isDark ? Brand.leafDark : Brand.leaf)
                          .withValues(alpha: isDark ? 0.10 : 0.07),
                    ),
                  ),
                  Opacity(
                    opacity: fadeContent,
                    child: Transform.translate(
                      offset: Offset(0, exitLift),
                      child: Transform.scale(
                        scale: exitScale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.translate(
                              offset: Offset(0, -_lift * up),
                              child: Transform.scale(
                                scale: markScale,
                                child: StrataMark(
                                  size: _markWidth,
                                  color: markColor,
                                  reveal: reveal,
                                  travel: 0.62,
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(0, 46 - 12 * (1 - up)),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _Wordmark(
                                    t: t,
                                    style: text.displaySmall!.copyWith(
                                      fontSize: 42,
                                      height: 1.0,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    width: 56 * line,
                                    height: 1.5,
                                    decoration: BoxDecoration(
                                      color: scheme.primary
                                          .withValues(alpha: 0.7 * line),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Opacity(
                                    opacity: tag,
                                    child: Transform.translate(
                                      offset: Offset(0, 10 * (1 - tag)),
                                      child: Text(
                                        AppBrand.tagline,
                                        style: text.bodyMedium?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          letterSpacing: 0.2 + 2.2 * (1 - tag),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The product name, each letter rising out of a clipped baseline in turn.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.t, required this.style});

  final double t;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final letters = AppBrand.name.characters.toList();
    // Spread the letters across a fixed window whatever the name's length,
    // so a rename does not change the splash's timing.
    const begin = 0.46, window = 0.22, each = 0.30;
    final step = letters.length > 1 ? window / (letters.length - 1) : 0.0;
    final h = (style.fontSize ?? 40) * 1.25;

    return ClipRect(
      child: SizedBox(
        height: h,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < letters.length; i++)
              Builder(builder: (context) {
                final u = _SplashView._at(
                    t, begin + i * step, math.min(1, begin + i * step + each));
                return Opacity(
                  opacity: u.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, h * 0.9 * (1 - u)),
                    child: Text(letters[i], style: style),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _BloomPainter extends CustomPainter {
  const _BloomPainter({
    required this.strength,
    required this.spread,
    required this.lift,
    required this.color,
  });

  final double strength;
  final double spread;
  final double lift;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final c = Offset(size.width / 2, size.height / 2 + lift);
    final r = size.width * 0.9 * spread;
    final a = color.a * strength;
    canvas.drawCircle(
      c,
      r,
      Paint()
        // Three stops so the falloff is gaussian-ish rather than a cone:
        // a linear ramp to zero shows its rim as a visible disc.
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: a),
            color.withValues(alpha: a * 0.45),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_BloomPainter old) =>
      old.strength != strength ||
      old.spread != spread ||
      old.lift != lift ||
      old.color != color;
}
