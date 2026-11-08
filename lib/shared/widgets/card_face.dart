import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';
import '../../config/palette.dart';
import '../../models/card_brand.dart';
import '../../models/payment_card.dart';
import 'strata_mark.dart';

/// A rendered card face.
///
/// The content is laid out once at [_designWidth] and scaled to fit with a
/// [FittedBox]. A card appears here at three very different sizes — 110dp in
/// the home mini-row, ~300dp in the carousel, full-width on the confirmation
/// screen — and type that is laid out fresh at each size would either overflow
/// at the small end or look wrong at the large end. Scaling one layout keeps
/// every proportion identical and makes overflow structurally impossible.
///
/// All artwork is generated in code — the gradient, the sediment texture and
/// the Strata glyph. The network is shown as its plain name; no network's
/// logo is reproduced.
class CardFace extends StatelessWidget {
  const CardFace({
    super.key,
    required this.skin,
    this.brand = CardBrand.unknown,
    this.funding,
    this.label,
    this.numberText,
    this.holder,
    this.expiry,
    this.sheen = 0,
    this.elevation = 1,
    this.seed = 0,
    this.frozen = false,
  });

  /// Build a face from a stored card.
  CardFace.of(
    PaymentCard card, {
    super.key,
    this.sheen = 0,
    this.elevation = 1,
  })  : frozen = card.frozen,
        skin = card.skin,
        brand = card.brand,
        funding = card.funding,
        label = card.displayLabel,
        numberText = card.maskedNumber,
        holder = card.holder,
        expiry = card.expiryLabel,
        seed = card.id.hashCode;

  final CardSkin skin;
  final CardBrand brand;
  final CardFunding? funding;

  /// Shown top-right. Falls back to the funding type when the card has no
  /// nickname of its own.
  final String? label;

  final String? numberText;
  final String? holder;
  final String? expiry;
  final double sheen;
  final double elevation;
  final int seed;

  /// Frozen cards are drawn muted, with a badge.
  ///
  /// Both, not either: colour alone is not a state, and a badge alone on a
  /// 110dp mini-card is too small to notice. The mute is what catches the
  /// eye across a carousel; the badge is what names it.
  final bool frozen;

  @override
  Widget build(BuildContext context) {
    final on = skin.onFace;
    final soft = on.withValues(alpha: 0.62);

    return AspectRatio(
      aspectRatio: kCardAspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: Radii.brCard,
          gradient: skin.gradient,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22 * elevation),
              blurRadius: 28 * elevation,
              offset: Offset(0, 12 * elevation),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: Radii.brCard,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: StrataTexturePainter(
                  tint: on,
                  highlight: skin.highlight,
                  seed: seed,
                  sheen: sheen,
                ),
              ),
              FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _designWidth,
                  height: _designWidth / kCardAspect,
                  child: Padding(
                    padding: Insets.cardFace,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StrataMark(size: 30, color: on),
                            const Spacer(),
                            if (label != null || funding != null)
                              Flexible(
                                child: Text(
                                  label ?? funding!.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: soft,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: Space.md),
                        Row(
                          children: [
                            _Chip(color: on),
                            const SizedBox(width: Space.md),
                            _Contactless(color: soft),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          numberText ?? '•••• •••• •••• ••••',
                          style: TextStyle(
                            color: on,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _Field(
                                label: 'Cardholder',
                                value: (holder?.isNotEmpty ?? false)
                                    ? holder!.toUpperCase()
                                    : 'YOUR NAME',
                                on: on,
                                soft: soft,
                              ),
                            ),
                            _Field(
                              label: 'Valid thru',
                              value: (expiry?.isNotEmpty ?? false)
                                  ? expiry!
                                  : 'MM/YY',
                              on: on,
                              soft: soft,
                            ),
                            const SizedBox(width: Space.lg),
                            // The network is named, never drawn as its logo.
                            // The abbreviated form is used here because the
                            // full name does not fit beside the other fields.
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              switchInCurve: Curves.easeOutBack,
                              transitionBuilder: (child, a) => FadeTransition(
                                opacity: a,
                                child: ScaleTransition(scale: a, child: child),
                              ),
                              child: brand.isKnown
                                  ? Text(
                                      brand.short.toUpperCase(),
                                      key: ValueKey(brand),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: on,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (frozen) ...[
                // A cold wash over the whole face, drawn rather than a
                // colour swap: the skin's gradient still shows through, so
                // it is recognisably the same card, just not usable.
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1A24).withValues(alpha: 0.46),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Center(child: _FrozenBadge(onFace: on)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The word, not just the icon. A snowflake alone is decoration; "Frozen" is
/// the state.
class _FrozenBadge extends StatelessWidget {
  const _FrozenBadge({required this.onFace});

  final Color onFace;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: Space.md, vertical: Space.sm),
        decoration: BoxDecoration(
          borderRadius: Radii.brPill,
          color: Colors.black.withValues(alpha: 0.42),
          border: Border.all(color: onFace.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ac_unit_rounded, size: 15, color: onFace),
            const SizedBox(width: Space.sm),
            Text(
              'Frozen',
              style: TextStyle(
                color: onFace,
                fontSize: 13,
                height: 1,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reference width the face is composed at before scaling.
const double _designWidth = 340;

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.on,
    required this.soft,
  });

  final String label, value;
  final Color on, soft;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            // Never wraps. "CARDHOLDER" is as wide as the field it labels,
            // so a brand abbreviation that takes a little more room beside
            // it is enough to push the label onto a second line, which adds
            // height the design-size box does not have and overflows the
            // whole face.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: soft,
                fontSize: 8.5,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: on,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
        ],
      );
}

/// Generic EMV contact plate.
class _Chip extends StatelessWidget {
  const _Chip({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.85),
              color.withValues(alpha: 0.45),
            ],
          ),
        ),
        child: CustomPaint(painter: _ChipPainter(color)),
      );
}

class _ChipPainter extends CustomPainter {
  const _ChipPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height * 0.33),
        Offset(size.width, size.height * 0.33), p);
    canvas.drawLine(Offset(0, size.height * 0.67),
        Offset(size.width, size.height * 0.67), p);
    canvas.drawLine(Offset(size.width * 0.34, 0),
        Offset(size.width * 0.34, size.height), p);
    canvas.drawLine(Offset(size.width * 0.66, 0),
        Offset(size.width * 0.66, size.height), p);
  }

  @override
  bool shouldRepaint(_ChipPainter old) => old.color != color;
}

/// Generic contactless indicator: four nested arcs.
class _Contactless extends StatelessWidget {
  const _Contactless({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
      width: 18, height: 22, child: CustomPaint(painter: _WavePainter(color)));
}

class _WavePainter extends CustomPainter {
  const _WavePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (var i = 0; i < 4; i++) {
      final r = size.width * (0.22 + i * 0.26);
      p.strokeWidth = 1.5;
      canvas.drawArc(
        Rect.fromCircle(
            center: Offset(-size.width * 0.1, size.height / 2), radius: r),
        -0.75,
        1.5,
        false,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.color != color;
}
