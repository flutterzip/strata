import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/design_tokens.dart';
import '../../../config/motion.dart';
import '../../../models/payment_card.dart';
import '../../../shared/widgets/card_face.dart';
import 'add_card_tile.dart';

/// The card carousel.
///
/// Two things make this feel different from a stock [PageView]:
///
/// 1. It settles on [Motion.carousel], a spring fitted from frame-by-frame
///    measurement rather than Flutter's default. Because it is a real spring
///    it is velocity-aware and fully interruptible — a hard fling and a slow
///    drag produce genuinely different motion, and grabbing a card mid-flight
///    carries its momentum instead of restarting.
/// 2. Every dependent surface binds to the *continuous* page offset exposed
///    through [onOffsetChanged], not to discrete page-change callbacks. That
///    is what keeps the balance, title and detail rows locked to the cards
///    through the whole gesture instead of snapping at the end.
class CardCarousel extends StatefulWidget {
  const CardCarousel({
    super.key,
    required this.cards,
    required this.onFocusChanged,
    this.onOffsetChanged,
    this.onAddCard,
    this.initialPage = 0,
    this.focusIndex,
  });

  final List<PaymentCard> cards;

  /// Fired when the settled page changes — for haptics and state.
  final ValueChanged<int> onFocusChanged;

  /// Fired continuously through the gesture with the fractional page offset.
  final ValueChanged<double>? onOffsetChanged;

  final VoidCallback? onAddCard;
  final int initialPage;

  /// Page the carousel should move to when this changes — for example after
  /// a card is added, so the user lands on the card they just created
  /// instead of wherever they happened to be.
  final int? focusIndex;

  @override
  State<CardCarousel> createState() => _CardCarouselState();
}

class _CardCarouselState extends State<CardCarousel> {
  static const double _viewport = 0.78;

  late final PageController _controller = PageController(
    viewportFraction: _viewport,
    initialPage: widget.initialPage,
  );
  late int _settled = widget.initialPage;

  /// Total pages = cards + the trailing "add a card" tile.
  int get _count => widget.cards.length + 1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(CardCarousel old) {
    super.didUpdateWidget(old);
    final target = widget.focusIndex;
    // Guard against feeding back into our own scroll notifications.
    if (target == null || target == old.focusIndex || target == _settled) {
      return;
    }
    if (!_controller.hasClients) return;
    final clamped = target.clamp(0, _count - 1);
    if (context.reduceMotion) {
      _controller.jumpToPage(clamped);
    } else {
      _controller.animateToPage(
        clamped,
        duration: Motion.gentle,
        curve: Motion.standard,
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  double get _page {
    if (_controller.hasClients && _controller.position.haveDimensions) {
      return _controller.page ?? widget.initialPage.toDouble();
    }
    return widget.initialPage.toDouble();
  }

  void _onScroll() {
    widget.onOffsetChanged?.call(_page);
    final nearest = _page.round().clamp(0, _count - 1);
    if (nearest != _settled) {
      _settled = nearest;
      // Light tick on settle — a physical cue that a card took focus.
      HapticFeedback.selectionClick();
      widget.onFocusChanged(nearest);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Honour the platform reduce-motion setting: drop the depth transform and
    // let pages simply cross-fade in place.
    final reduce = context.reduceMotion;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.min(constraints.maxWidth, 460.0) /
            kCardAspect *
            _viewport *
            1.06;
        return SizedBox(
          height: height.clamp(170.0, 260.0),
          child: PageView.builder(
            controller: _controller,
            physics: const StrataPagePhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padEnds: true,
            itemCount: _count,
            itemBuilder: (context, i) {
              final isAddTile = i == widget.cards.length;
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  // Signed distance of this page from centre, in pages.
                  final delta = i - _page;
                  final d = delta.abs().clamp(0.0, 1.0);

                  final scale = reduce ? 1.0 : 1 - d * 0.12;
                  final opacity = (1 - d * 0.42).clamp(0.0, 1.0);
                  // Counter-drift keeps neighbours closer than the viewport
                  // would otherwise place them, tightening the stack.
                  final dx = reduce ? 0.0 : delta * 18.0;
                  // Sheen tracks this card's own distance from centre, so the
                  // specular band sweeps as the card crosses the middle.
                  final sheen = reduce ? 0.0 : (1 - d) * 0.9;

                  return Transform.translate(
                    offset: Offset(dx, d * 8),
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: Space.sm),
                          child: isAddTile
                              ? AddCardTile(onTap: widget.onAddCard)
                              : _FocusableCard(
                                  card: widget.cards[i], sheen: sheen),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _FocusableCard extends StatelessWidget {
  const _FocusableCard({required this.card, required this.sheen});

  final PaymentCard card;
  final double sheen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: card.describedForAccessibility,
      button: true,
      // The face repeats the number, holder and expiry as separate text.
      // A screen reader should hear one clean description, not the raw
      // fragments, so the painted content is excluded from semantics.
      child: ExcludeSemantics(
        child: Hero(
          tag: 'card-${card.id}',
          flightShuttleBuilder: (_, __, ___, ____, toCtx) =>
              (toCtx.widget as Hero).child,
          child: CardFace.of(card, sheen: sheen),
        ),
      ),
    );
  }
}
