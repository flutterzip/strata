import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/design_tokens.dart';
import '../../../config/motion.dart';
import '../../../models/payment_card.dart';
import '../../../shared/widgets/card_face.dart';
import 'add_card_tile.dart';

/// Cards stacked the way they sit in a real wallet.
///
/// The alternative to the carousel. Where the carousel shows one card at a
/// time and hides the rest, the stack shows the whole wallet at once: every
/// card's top edge is visible, and selecting one slides the cards below it
/// down to reveal it in full.
///
/// Trade-offs against the carousel, so the choice is an informed one:
///
/// * **Stack** — the whole wallet is legible without scrolling, and picking a
///   specific card is one tap rather than several swipes. Vertical space is
///   the cost: each extra card eats [_peek] whether or not you need it.
/// * **Carousel** — one card gets the full frame, so artwork and balance read
///   larger, and the gesture is continuous. But everything other than the
///   current card is off-screen.
///
/// Both drive the same selection state, so the detail below is identical.
///
/// It opens **closed**: every card an even sliver, nothing revealed, which is
/// how a wallet actually sits. Revealing the first card by default answered a
/// question nobody had asked yet and made a wallet of six look like one card
/// with some edges behind it.
class WalletStack extends StatelessWidget {
  const WalletStack({
    super.key,
    required this.cards,
    required this.selectedIndex,
    required this.onSelected,
    this.onAddCard,
  });

  final List<PaymentCard> cards;

  /// Which card is open, or null for the closed stack.
  final int? selectedIndex;

  final ValueChanged<int> onSelected;
  final VoidCallback? onAddCard;

  /// Visible sliver of each unselected card.
  static const double _peek = 64;

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    // One slot per card, plus the add tile.
    final count = cards.length + 1;
    final selected = selectedIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = cardWidth / kCardAspect;
        // Selecting a card pushes everything beneath it down far enough to
        // show the whole face.
        final reveal = cardHeight - _peek;
        final open = selected != null;

        // Shut, every card is an equal sliver and the add tile — always a
        // full card, never a strip — closes the stack. Open, the chosen
        // card is revealed and everything below it is pushed down.
        final totalHeight = open
            ? cards.length * _peek + reveal + cardHeight
            : cards.length * _peek + cardHeight;

        double topFor(int i) => i * _peek + (open && i > selected ? reveal : 0);

        // No clip is needed: the lowest slot is the add tile, whose bottom
        // is exactly `totalHeight` in both states, so nothing can spill out
        // of the box or show past it.
        return AnimatedContainer(
            // Same duration and curve as the cards, so the box and the cards
            // it holds open and shut together.
            duration: reduce ? Duration.zero : Motion.gentle,
            curve: Motion.standard,
            height: totalHeight,
            child: Stack(
              children: [
                for (var i = 0; i < count; i++)
                  AnimatedPositioned(
                    key: ValueKey(i == cards.length ? 'add' : cards[i].id),
                    duration: reduce ? Duration.zero : Motion.gentle,
                    curve: Motion.standard,
                    top: topFor(i),
                    left: 0,
                    right: 0,
                    height: cardHeight,
                    child: AnimatedScale(
                      duration: reduce ? Duration.zero : Motion.gentle,
                      curve: Motion.standard,
                      // The selected card sits fractionally proud of the rest.
                      scale: i == selected ? 1 : 0.97,
                      child: i == cards.length
                          // The add tile is an action, not a card to inspect,
                          // so it adds on the first tap rather than needing
                          // one to open it and another to act.
                          ? _StackSlot(
                              selected: false,
                              onTap: () => onAddCard?.call(),
                              semanticLabel: 'Add a card',
                              // Always give the tile a handler. A null one
                              // makes Pressable dim it to 45% opacity, which
                              // is right for a disabled control and wrong for
                              // a surface stacked on a card — the card below
                              // shows straight through it.
                              child: AddCardTile(
                                onTap: () => onAddCard?.call(),
                              ),
                            )
                          : _StackSlot(
                              selected: i == selected,
                              // Tapping the open card shuts the stack again,
                              // so the whole wallet is one tap away from any
                              // card in it.
                              onTap: () => onSelected(i),
                              semanticLabel: cards[i].describedForAccessibility,
                              child: CardFace.of(
                                cards[i],
                                sheen: i == selected ? 0.8 : 0.2,
                                elevation: i == selected ? 1.2 : 0.5,
                              ),
                            ),
                    ),
                  ),
              ],
            ));
      },
    );
  }
}

class _StackSlot extends StatelessWidget {
  const _StackSlot({
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: child,
        ),
      ),
    );
  }
}
