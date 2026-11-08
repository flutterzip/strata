import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_timing.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/payment_card.dart';
import '../../providers/notification_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/wallet_providers.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/card_face.dart';
import '../../shared/widgets/count_badge.dart';
import '../../shared/widgets/strata_sheet.dart';
import '../../shared/widgets/stage_transition.dart';
import '../profile/widgets/notifications_sheet.dart';
import '../convert/convert_screen.dart';
import '../more/more_sheet.dart';
import '../send/send_screen.dart';
import '../transactions/transactions_screen.dart';
import 'widgets/quick_actions.dart';
import 'widgets/recent_activity.dart';
import 'widgets/spending_summary.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onAddCard, this.onSeeCards});

  final VoidCallback? onAddCard;
  final VoidCallback? onSeeCards;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: Motion.entrance,
  )..forward();

  late final _balanceIn = Motion.stage(_entrance, begin: 0.0, end: 0.40);
  late final _cardsIn = Motion.stage(_entrance, begin: 0.14, end: 0.56);
  late final _actionsIn = Motion.stage(_entrance, begin: 0.28, end: 0.72);
  late final _spendIn = Motion.stage(_entrance, begin: 0.40, end: 0.88);
  late final _activityIn = Motion.stage(_entrance, begin: 0.52, end: 1.0);

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _openNotifications() => showStrataSheet<void>(
        context,
        builder: (_) => const NotificationsSheet(),
      );

  void _openActivity() =>
      Navigator.of(context).pushNamed(TransactionsScreen.route);

  void _openSend() => Navigator.of(context).pushNamed(SendScreen.route);

  void _openConvert() => Navigator.of(context).pushNamed(ConvertScreen.route);

  Future<void> _openMore() => showStrataSheet<void>(
        context,
        builder: (_) => const MoreSheet(),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = ref.watch(totalBalanceProvider);
    // First name only: "Welcome, Ada", not "Welcome, Ada Lovelace". Empty
    // while the profile loads, so the line never flashes a placeholder.
    final firstName = (ref.watch(profileProvider).valueOrNull?.name ?? '')
        .trim()
        .split(' ')
        .first;
    final cards =
        ref.watch(walletProvider).valueOrNull ?? const <PaymentCard>[];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () {
            ref.invalidate(walletProvider);
            return AppTiming.refreshing(ref.read(walletProvider.future));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                Space.xl, Space.md, Space.xl, Space.huge),
            children: [
              Row(
                children: [
                  Expanded(child: _Welcome(name: firstName)),
                  BadgedIconButton(
                    icon: Icons.notifications_none_rounded,
                    count: ref.watch(unreadCountProvider),
                    tooltip: 'Notifications',
                    onPressed: _openNotifications,
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              StageTransition(
                animation: _balanceIn,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total balance', style: text.bodySmall),
                    const SizedBox(height: Space.xs),
                    AmountText(
                      minor: total.minor,
                      currency: total.currency,
                      semanticsPrefix: 'Total balance',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xxl),
              StageTransition(
                animation: _cardsIn,
                child: _MiniCardRow(
                  cards: cards,
                  onSeeAll: widget.onSeeCards,
                  onAdd: widget.onAddCard,
                ),
              ),
              const SizedBox(height: Space.xxl),
              StageTransition(
                animation: _actionsIn,
                child: QuickActions(
                  actions: [
                    (
                      icon: Icons.add_rounded,
                      label: 'Add',
                      onTap: widget.onAddCard
                    ),
                    (
                      icon: Icons.north_east_rounded,
                      label: 'Send',
                      onTap: _openSend
                    ),
                    (
                      icon: Icons.swap_horiz_rounded,
                      label: 'Convert',
                      onTap: _openConvert
                    ),
                    (
                      icon: Icons.more_horiz_rounded,
                      label: 'More',
                      onTap: _openMore
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xxl),
              StageTransition(
                  animation: _spendIn, child: const SpendingSummary()),
              const SizedBox(height: Space.xxl),
              StageTransition(
                animation: _activityIn,
                child: RecentActivity(onSeeAll: _openActivity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact preview of the wallet, tappable through to the carousel.
class _MiniCardRow extends StatelessWidget {
  const _MiniCardRow({required this.cards, this.onSeeAll, this.onAdd});

  final List<PaymentCard> cards;
  final VoidCallback? onSeeAll, onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Expanded, not Spacer: a section heading plus a trailing button
            // overflows a narrow phone at the top of the text-scale range,
            // and a bare Row has nowhere to put the excess.
            Expanded(
              child: Text(
                'Your cards',
                style: text.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(onPressed: onSeeAll, child: const Text('See all')),
          ],
        ),
        const SizedBox(height: Space.md),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: Space.md),
            itemBuilder: (context, i) {
              if (i == cards.length) {
                return Semantics(
                  button: true,
                  label: 'Add a card',
                  child: InkWell(
                    onTap: onAdd,
                    borderRadius: Radii.brLg,
                    child: Container(
                      width: 96,
                      decoration: BoxDecoration(
                        borderRadius: Radii.brLg,
                        border: Border.all(
                            color:
                                Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: const Icon(Icons.add_rounded),
                    ),
                  ),
                );
              }
              final card = cards[i];
              return Semantics(
                label: card.describedForAccessibility,
                button: true,
                child: GestureDetector(
                  onTap: onSeeAll,
                  child: ExcludeSemantics(
                    child: SizedBox(
                      width: 112 * kCardAspect,
                      child: CardFace.of(card, elevation: 0.6),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// "Welcome, Olympicson" — the signed-in person's first name, set a step
/// stronger than the greeting around it. Reads just "Welcome" until the
/// profile has loaded or when no name is set.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final base = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: name.isEmpty ? 'Welcome' : 'Welcome, '),
          if (name.isNotEmpty)
            TextSpan(
              text: name,
              style: base?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation('wght', 640)],
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
