import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import 'pressable.dart';

typedef NavItem = ({IconData icon, IconData activeIcon, String label});

/// Strata's bottom navigation.
///
/// A floating bar rather than a full-width shelf, with a single pill that
/// slides between destinations on the same spring as the carousel. The label
/// belongs to the pill, not to every item: inactive destinations are icons
/// alone, so the bar stays quiet and the current position is unmistakable.
///
/// Two things keep it from reading as a stock tab bar:
///
/// * **The pill is the slot, inset uniformly.** Both the bar and the pill
///   are stadiums, so each one's radius is half its own height. Inset the
///   pill by the same amount on all four sides and the end caps become
///   circles about one centre — a constant ring of bar all the way round.
///   Sizing the pill to its label instead and centring it in a wider slot
///   breaks that: the radii stay concentric but the first pill picks up
///   `inset + (slot - pillWidth) / 2` on its left against `inset` on top,
///   so the ring is thin above and fat beside, which reads as a botched
///   radius. The pill fills its slot for that reason.
/// * **Two shadows, not one.** A tight contact shadow under the edge and a
///   wide ambient one further down. A single soft shadow reads as a drop
///   shadow; the pair reads as an object above a surface.
///
/// Generic over any number of destinations, and it never hardcodes a colour —
/// the pill is the one accent, everything else is ink on paper.
class StrataNavBar extends StatelessWidget {
  const StrataNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  /// The bar, and the travelling pill inside it. Exposed so a test can
  /// measure the gap between them on all four sides — the thing that is
  /// wrong whenever the radius "looks off".
  static const Key barKey = Key('nav-bar');
  static const Key pillKey = Key('nav-pill');

  static const double _barHeight = 60;

  /// Inset of the pill's track from the bar's edge — **uniform**, and it has
  /// to be.
  ///
  /// Both the bar and the pill are stadiums, so each one's corner radius is
  /// half its own height. Inset the pill by the same amount on every side
  /// and the two end caps become circles about the same centre: radius 30
  /// outside, 30 − 4 inside, a constant 4 of ink all the way round. Inset it
  /// more horizontally than vertically — which is what this was doing — and
  /// the inner curve no longer follows the outer one, which reads as a
  /// wrong radius even though both shapes are "fully rounded".
  static const double _inset = 4;

  static const double _iconSize = 21;

  /// Between the icon and the label it belongs to.
  static const double _iconGap = Space.sm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reduce = context.reduceMotion;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final labelStyle = text.labelSmall?.copyWith(fontWeight: FontWeight.w700);

    return SafeArea(
      top: false,
      child: Padding(
        // No bottom padding: the bar sits straight on the safe-area edge,
        // which is as low as it can go without crossing the home indicator.
        padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: Radii.brPill,
            boxShadow: [
              // Contact: tight, close, directly under the edge.
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.44 : 0.07),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
              // Ambient: wide and low, the light from the room.
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.34 : 0.09),
                blurRadius: 30,
                spreadRadius: -4,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Container(
            key: barKey,
            height: _barHeight,
            padding: const EdgeInsets.all(_inset),
            decoration: BoxDecoration(
              borderRadius: Radii.brPill,
              color: scheme.surfaceContainer,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slot = constraints.maxWidth / items.length;

                return Stack(
                  children: [
                    // The travelling pill. One widget, not one per item,
                    // so the motion is continuous rather than a
                    // cross-fade.
                    //
                    // It is exactly one slot wide and sits exactly on
                    // the slot. That is what makes the gap identical on
                    // all four sides at either end of the bar: the
                    // track is already inset by `_inset`, so the first
                    // pill's left edge *is* the inset, the same figure
                    // as its top and bottom.
                    AnimatedPositioned(
                      duration: reduce ? Duration.zero : Motion.gentle,
                      curve: Motion.emphasised,
                      left: slot * index,
                      width: slot,
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        key: pillKey,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: Radii.brPill,
                          boxShadow: [
                            // Sits the pill *on* the bar rather than
                            // painting it into the surface.
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final (i, item) in items.indexed)
                          Expanded(
                            child: _NavDestination(
                              item: item,
                              selected: i == index,
                              reduce: reduce,
                              textStyle: labelStyle,
                              onTap: () {
                                if (i == index) return;
                                HapticFeedback.selectionClick();
                                onChanged(i);
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination extends StatelessWidget {
  const _NavDestination({
    required this.item,
    required this.selected,
    required this.reduce,
    required this.textStyle,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final bool reduce;
  final TextStyle? textStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active =
        selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: item.label,
      child: ExcludeSemantics(
        child: Pressable(
          onTap: onTap,
          pressedScale: 0.92,
          // The tab change already plays `selectionClick`, which is the
          // right haptic for it; Pressable's own would double it up.
          haptic: false,
          enforceMinTarget: false,
          // The row is the hit target and it fills the slot, so there is
          // nothing to pad out — and dimming a destination that is simply
          // not current would read as disabled.
          dimWhenDisabled: false,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: reduce ? Duration.zero : Motion.base,
                  child: Icon(
                    selected ? item.activeIcon : item.icon,
                    key: ValueKey(selected),
                    size: StrataNavBar._iconSize,
                    color: active,
                  ),
                ),
                // The label belongs to the active pill only. Animating the
                // width rather than the opacity keeps the icon centred when
                // there is no label beside it, and matches the pill, which
                // is animating its own width to the same beat.
                AnimatedSize(
                  duration: reduce ? Duration.zero : Motion.gentle,
                  curve: Motion.standard,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(
                              left: StrataNavBar._iconGap),
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                            style: textStyle?.copyWith(color: active),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
