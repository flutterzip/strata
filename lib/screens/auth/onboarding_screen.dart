import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/auth_models.dart';
import '../../providers/auth_providers.dart';
import '../../providers/spending_providers.dart';
import '../../shared/widgets/status_view.dart';
import '../../shared/widgets/strata_mark.dart';
import 'widgets/auth_backdrop.dart';
import 'widgets/onboarding_motif.dart';

/// First-run intro.
///
/// Slides come from `assets/data/auth.json`, so the copy is editable without
/// touching code. Each slide's illustration builds itself as the slide
/// arrives — driven by distance from centre, not by a timer — so the motion
/// tracks the finger through a drag and reverses cleanly if the user
/// changes their mind halfway.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// Screenshot/automation hook, as elsewhere. `--dart-define=startSlide=1`
  /// opens the intro on the second slide.
  static const int _initialPage = int.fromEnvironment('startSlide');

  final _controller = PageController(initialPage: _initialPage);

  /// Seeded to the starting page. A notifier that began at 0 while the
  /// controller began elsewhere left the visible slide computing a presence
  /// of zero, so it rendered completely blank until the first scroll.
  final _page = ValueNotifier<double>(_initialPage.toDouble());
  int _settled = _initialPage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    _page.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients || !_controller.position.haveDimensions) return;
    final p = _controller.page ?? 0;
    _page.value = p;
    final nearest = p.round();
    if (nearest != _settled) {
      _settled = nearest;
      HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  Future<void> _finish() async {
    await ref.read(authProvider.notifier).completeOnboarding();
  }

  void _next(int count) {
    if (_settled >= count - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: context.motion(Motion.gentle),
      curve: Motion.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slides = ref.watch(onboardingSlidesProvider);
    // The chart motif names the real categories, read from the same seed
    // the real chart uses rather than invented for the intro.
    final categoryLabels = ref
            .watch(spendingProvider)
            .valueOrNull
            ?.categories
            .map((c) => c.label)
            .toList() ??
        const <String>[];
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuthBackdrop(
        child: SafeArea(
          child: slides.when(
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            error: (_, __) => StatusView(
              icon: Icons.error_outline_rounded,
              title: 'Could not load the intro',
              actionLabel: 'Skip for now',
              onAction: _finish,
              emphasised: true,
            ),
            data: (items) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Space.xxl, Space.sm, Space.lg, 0),
                  child: Row(
                    children: [
                      StrataMark(size: 26, color: scheme.onSurface),
                      const Spacer(),
                      TextButton(
                        onPressed: _finish,
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: items.length,
                    physics: const StrataPagePhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    itemBuilder: (context, i) => ValueListenableBuilder<double>(
                      valueListenable: _page,
                      builder: (context, page, _) => _Slide(
                        slide: items[i],
                        delta: i - page,
                        labels: categoryLabels,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Space.xxl, Space.lg, Space.xxl, Space.lg),
                  child: Column(
                    children: [
                      _Progress(page: _page, count: items.length),
                      const SizedBox(height: Space.xl),
                      FilledButton(
                        onPressed: () => _next(items.length),
                        child: Text(
                          _settled >= items.length - 1
                              ? 'Get started'
                              : 'Continue',
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      Text(
                        'No account needed to look around.',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.slide,
    required this.delta,
    required this.labels,
  });

  final OnboardingSlide slide;
  final List<String> labels;

  /// Distance from centre in pages; 0 when this slide is front and centre.
  final double delta;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final d = delta.abs().clamp(0.0, 1.0);
    final presence = 1 - d;
    final reduce = context.reduceMotion;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Art drifts slower than the text, which reads as depth.
          Transform.translate(
            offset: Offset(reduce ? 0 : delta * -42, 0),
            child: Opacity(
              opacity: presence.clamp(0.0, 1.0),
              child: OnboardingMotif(
                motif: slide.motif,
                progress: reduce ? 1 : presence,
                labels: labels,
              ),
            ),
          ),
          const SizedBox(height: Space.xxxl),
          Transform.translate(
            offset: Offset(reduce ? 0 : delta * 26, 0),
            child: Opacity(
              opacity: (presence * presence).clamp(0.0, 1.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slide.eyebrow.toUpperCase(),
                    style: text.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  Text(slide.title, style: text.headlineMedium),
                  const SizedBox(height: Space.md),
                  Text(slide.body, style: text.bodyLarge),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented progress that fills continuously with the drag.
class _Progress extends StatelessWidget {
  const _Progress({required this.page, required this.count});

  final ValueListenable<double> page;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: ValueListenableBuilder<double>(
        valueListenable: page,
        builder: (context, p, _) => Row(
          children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: ClipRRect(
                    borderRadius: Radii.brPill,
                    child: SizedBox(
                      height: 3,
                      child: Stack(
                        children: [
                          ColoredBox(
                            color: scheme.onSurface.withValues(alpha: 0.12),
                            child: const SizedBox.expand(),
                          ),
                          FractionallySizedBox(
                            widthFactor: (p - i + 1).clamp(0.0, 1.0),
                            child: ColoredBox(
                              color: scheme.primary,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
