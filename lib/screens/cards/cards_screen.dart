import '../../config/app_brand.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/design_tokens.dart';
import '../../models/payment_card.dart';
import '../../providers/wallet_providers.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/offset_bound.dart';
import '../../shared/widgets/status_view.dart';
import '../../shared/widgets/strata_sheet.dart';
import 'widgets/edit_card_sheet.dart';
import 'widgets/card_carousel.dart';
import '../../shared/widgets/segmented_toggle.dart';
import 'widgets/card_detail_block.dart';
import 'widgets/wallet_stack.dart';

class CardsScreen extends ConsumerStatefulWidget {
  const CardsScreen({super.key, this.onAddCard});

  final VoidCallback? onAddCard;

  @override
  ConsumerState<CardsScreen> createState() => _CardsScreenState();
}

/// How the wallet is laid out. Both modes drive the same selection state,
/// so everything below the cards is identical between them.
enum CardsLayout { carousel, wallet }

class _CardsScreenState extends ConsumerState<CardsScreen> {
  /// Screenshot/automation hook, as elsewhere. Defaults to the wallet
  /// stack, which is what the screen opens on; `--dart-define=startLayout=0`
  /// opens on the carousel.
  CardsLayout _layout = CardsLayout
      .values[const int.fromEnvironment('startLayout', defaultValue: 1)];

  /// Which card the stack has open, or null for the closed stack — which is
  /// how the screen starts. The carousel has no such state: it always has
  /// exactly one card in frame.
  int? _openedIndex;

  /// Whether anything below the cards has a card to describe.
  bool get _hasFocus => _layout == CardsLayout.carousel || _openedIndex != null;

  /// Live fractional carousel position. A [ValueNotifier] rather than
  /// setState so a drag repaints only the bound subtrees, not the screen.
  final _offset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Update and Delete for the card currently in focus.
  Future<void> _manageCard(PaymentCard card) async {
    final action = await showStrataSheet<String>(
      context,
      builder: (sheetContext) => StrataSheet(
        icon: Icons.credit_card_rounded,
        title: card.shortMask,
        message: '${card.brand.label} ${card.funding.label.toLowerCase()}, '
            'expires ${card.expiryLabel}.',
        actions: [
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(sheetContext).pop('edit'),
            icon: const Icon(Icons.tune_rounded, size: 19),
            label: const Text('Edit card'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(sheetContext).pop('delete'),
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            label: const Text('Remove card'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'edit') {
      final saved = await showStrataSheet<bool>(
        context,
        builder: (_) => EditCardSheet(card: card),
      );
      if (saved == true && mounted) _toast('Card updated');
      return;
    }

    final ok = await confirmAction(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Remove this card?',
      message: '${card.brand.label} ${card.shortMask} will be taken out of '
          'your wallet. You can add it again later.',
      confirmLabel: 'Remove card',
      destructive: true,
    );
    if (!ok || !mounted) return;

    await ref.read(walletProvider.notifier).remove(card.id);
    if (!mounted) return;
    // Keep focus inside the new, shorter list.
    final remaining = ref.read(walletProvider).valueOrNull?.length ?? 0;
    final focus = ref.read(focusedCardIndexProvider);
    if (focus > remaining) {
      ref.read(focusedCardIndexProvider.notifier).state =
          remaining == 0 ? 0 : remaining - 1;
    }
    _toast('Card removed');
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: wallet.when(
          loading: () => const _CardsSkeleton(),
          error: (e, _) => _CardsError(
            onRetry: () => ref.invalidate(walletProvider),
          ),
          data: (cards) {
            if (cards.isEmpty) {
              return _CardsEmpty(onAddCard: widget.onAddCard);
            }
            // One extra slot for the trailing "add a card" tile.
            final slots = cards.length + 1;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Space.xl, Space.md, Space.xl, Space.lg),
                    child: Row(
                      children: [
                        Text('Cards', style: text.headlineSmall),
                        const Spacer(),
                        IconButton(
                          onPressed: widget.onAddCard,
                          icon: const Icon(Icons.add_rounded),
                          tooltip: 'Add a card',
                        ),
                        Builder(builder: (context) {
                          final focus = ref.watch(focusedCardIndexProvider);
                          // Nothing is open on a closed stack, so there is
                          // no "this card" to manage yet.
                          final canManage = _hasFocus && focus < cards.length;
                          return IconButton(
                            onPressed: canManage
                                ? () => _manageCard(cards[focus])
                                : null,
                            icon: const Icon(Icons.more_horiz_rounded),
                            tooltip: 'Manage this card',
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Space.xl, 0, Space.xl, Space.lg),
                    child: SegmentedToggle(
                      segments: const [
                        (icon: Icons.view_carousel_outlined, label: 'Carousel'),
                        (
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Wallet'
                        ),
                      ],
                      index: _layout.index,
                      onChanged: (i) => setState(() {
                        _layout = CardsLayout.values[i];
                        // Coming back to the wallet shows the whole wallet,
                        // not whatever was last open in it.
                        if (_layout == CardsLayout.wallet) {
                          _openedIndex = null;
                        }
                      }),
                    ),
                  ),
                ),
                if (_layout == CardsLayout.wallet)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: Space.xxl),
                      child: WalletStack(
                        cards: cards,
                        selectedIndex: _openedIndex?.clamp(0, cards.length),
                        onAddCard: widget.onAddCard,
                        onSelected: (i) {
                          setState(() {
                            // Tapping the open card shuts the stack, which
                            // is the way back to seeing the whole wallet.
                            _openedIndex = _openedIndex == i ? null : i;
                          });
                          if (_openedIndex == null) return;
                          ref.read(focusedCardIndexProvider.notifier).state = i;
                          // Keep the shared detail binding in step; the stack
                          // selects discretely where the carousel scrubs.
                          _offset.value = i.toDouble();
                        },
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: CardCarousel(
                      cards: cards,
                      focusIndex: ref.watch(focusedCardIndexProvider),
                      onOffsetChanged: (v) => _offset.value = v,
                      onFocusChanged: (i) =>
                          ref.read(focusedCardIndexProvider.notifier).state = i,
                      onAddCard: widget.onAddCard,
                    ),
                  ),
                if (_layout == CardsLayout.carousel)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: Space.xl),
                      child: _PageDots(offset: _offset, count: slots),
                    ),
                  ),
                // Headline balance, bound to the live carousel offset.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Space.xl, Space.xl, Space.xl, 0),
                    child: SizedBox(
                      height: 84,
                      child: _hasFocus
                          ? OffsetBound(
                              offset: _offset,
                              count: slots,
                              alignment: Alignment.center,
                              slide: 26,
                              builder: (context, i) => i >= cards.length
                                  ? _AddHeadline(text: text)
                                  : _BalanceHeadline(
                                      card: cards[i], text: text),
                            )
                          : _WalletHeadline(cards: cards, text: text),
                    ),
                  ),
                ),
                // Only once a card is open. There is no honest per-card
                // detail to show for a closed stack, and a block of dashes
                // reads as a loading failure.
                if (_hasFocus)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Space.xl, Space.xxl, Space.xl, Space.huge),
                      child: SizedBox(
                        // Four info lines now, not three: the card's status
                        // and monthly limit were added.
                        height: 312,
                        child: OffsetBound(
                          offset: _offset,
                          count: slots,
                          slide: 34,
                          builder: (context, i) => i >= cards.length
                              ? const AddCardPrompt()
                              : CardDetailBlock(card: cards[i]),
                        ),
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(
                    child: SizedBox(height: Space.huge),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BalanceHeadline extends StatelessWidget {
  const _BalanceHeadline({required this.card, required this.text});

  final PaymentCard card;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AmountText(
          minor: card.balanceMinor,
          currency: card.currency,
          semanticsPrefix: 'Balance on card ending ${card.last4},',
        ),
        const SizedBox(height: Space.xs),
        Text('${card.funding.label} \u00B7 ${card.shortMask}',
            style: text.bodySmall),
      ],
    );
  }
}

/// What the headline says while the stack is shut.
///
/// Deliberately not a combined balance. The demo wallet holds USD, EUR and
/// USD; adding them would print a number that is not true of any currency,
/// and a wallet total is the kind of figure people act on.
class _WalletHeadline extends StatelessWidget {
  const _WalletHeadline({required this.cards, required this.text});

  final List<PaymentCard> cards;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final frozen = cards.where((c) => c.frozen).length;

    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Your wallet', style: text.headlineMedium),
          const SizedBox(height: Space.xs),
          Text(
            [
              cards.length == 1 ? '1 card' : '${cards.length} cards',
              if (frozen > 0) '$frozen frozen',
              'tap one to open',
            ].join(' · '),
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _AddHeadline extends StatelessWidget {
  const _AddHeadline({required this.text});
  final TextTheme text;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('New card', style: text.headlineMedium),
          const SizedBox(height: Space.xs),
          Text('Takes about a minute', style: text.bodySmall),
        ],
      );
}

class AddCardPrompt extends StatelessWidget {
  const AddCardPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            'Add a debit or credit card. ${AppBrand.name} works out the network '
            'the number as you type, so there is nothing to choose.',
            style: text.bodyMedium),
        const SizedBox(height: Space.lg),
        Row(children: [
          Icon(Icons.lock_outline_rounded,
              size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: Space.sm),
          Expanded(
              child: Text('Details are encrypted on this device',
                  style: text.bodySmall)),
        ]),
      ],
    );
  }
}

/// Page indicator whose active pip slides continuously with the gesture.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.offset, required this.count});

  final ValueListenable<double> offset;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        height: 8,
        child: ValueListenableBuilder<double>(
          valueListenable: offset,
          builder: (context, value, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Builder(builder: (_) {
                    final d = (i - value).abs().clamp(0.0, 1.0);
                    final t = 1 - d;
                    return Container(
                      width: 6 + 14 * t,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: Radii.brPill,
                        color: Color.lerp(
                          scheme.onSurface.withValues(alpha: 0.18),
                          scheme.primary,
                          t,
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardsSkeleton extends StatelessWidget {
  const _CardsSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Loading your cards',
      child: ListView(
        padding: const EdgeInsets.all(Space.xl),
        children: [
          const SizedBox(height: Space.huge),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: AspectRatio(
                aspectRatio: kCardAspect,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: Radii.brCard,
                    color: scheme.surfaceContainerHigh,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.xxl),
          const Center(child: CircularProgressIndicator.adaptive()),
        ],
      ),
    );
  }
}

class _CardsError extends StatelessWidget {
  const _CardsError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StatusView(
        icon: Icons.cloud_off_rounded,
        title: 'We could not load your cards',
        message: 'Check your connection and try again.',
        actionLabel: 'Try again',
        onAction: onRetry,
      );
}

class _CardsEmpty extends StatelessWidget {
  const _CardsEmpty({this.onAddCard});
  final VoidCallback? onAddCard;

  @override
  Widget build(BuildContext context) => StatusView(
        icon: Icons.credit_card_off_rounded,
        title: 'No cards yet',
        message: 'Add your first card to get started.',
        actionLabel: 'Add a card',
        onAction: onAddCard,
        emphasised: true,
      );
}
