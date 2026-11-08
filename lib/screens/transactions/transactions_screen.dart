import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_timing.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/payment_card.dart';
import '../../models/transaction.dart';
import '../../models/txn_filter.dart';
import '../../providers/transaction_providers.dart';
import '../../providers/wallet_providers.dart';
import '../../shared/utils/money.dart';
import '../../shared/utils/txn_grouping.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/count_badge.dart';
import '../../shared/widgets/stage_transition.dart';
import '../../shared/widgets/status_view.dart';
import '../../shared/widgets/strata_sheet.dart';
import 'widgets/transaction_detail_sheet.dart';
import 'widgets/transaction_edit_sheet.dart';
import 'widgets/transaction_filter_sheet.dart';
import 'widgets/transaction_row.dart';

/// The activity list: every transaction, grouped by day.
///
/// A [CustomScrollView] with one pinned header per day rather than a flat
/// list with inline dividers — the header has to stay visible while its own
/// day scrolls past, which is what tells you where you are six weeks back.
///
/// The widget keys below are declared here, including the ones used by the
/// sheets this screen opens, so a test has one place to look and the keys
/// cannot drift apart from the screen that owns the flow.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  static const String route = '/transactions';

  static const Key searchKey = Key('txn-search');
  static const Key filterKey = Key('txn-filter');
  static const Key addKey = Key('txn-add');
  static const Key editKey = Key('txn-edit');
  static const Key deleteKey = Key('txn-delete');
  static const Key saveKey = Key('txn-save');
  static const Key noteKey = Key('txn-note');
  static const Key merchantKey = Key('txn-merchant');
  static const Key amountKey = Key('txn-amount');
  static const Key categoryKey = Key('txn-category');
  static const Key clearFiltersKey = Key('txn-clear-filters');

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: Motion.entrance,
  )..forward();

  late final _searchIn = Motion.stage(_entrance, begin: 0.0, end: 0.42);
  late final _listIn = Motion.stage(_entrance, begin: 0.16, end: 0.80);

  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Seeded from the filter rather than from empty: the screen can be
    // reached with a search already in force, and a field that renders blank
    // while the list is narrowed looks broken.
    _search.text = ref.read(txnFilterProvider).query;
    _search.addListener(_onSearch);

    // Screenshot/automation hook, as elsewhere. Goes through _openFilters
    // rather than showing the sheet itself, so what is captured is the real
    // flow — including applying the result on the way back.
    if (const bool.fromEnvironment('startFilter')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFilters();
      });
    }
  }

  @override
  void dispose() {
    _search.removeListener(_onSearch);
    _search.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _onSearch() {
    final filter = ref.read(txnFilterProvider);
    if (filter.query == _search.text) return;
    ref.read(txnFilterProvider.notifier).state =
        filter.copyWith(query: _search.text);
  }

  void _clearFilters() {
    _search.clear();
    ref.read(txnFilterProvider.notifier).state = TxnFilter.none;
  }

  void _clearFacet(TxnFacet facet) {
    if (facet == TxnFacet.query) _search.clear();
    ref.read(txnFilterProvider.notifier).state =
        ref.read(txnFilterProvider).cleared(facet);
  }

  Future<void> _openFilters() async {
    final result = await showStrataSheet<TxnFilter>(
      context,
      builder: (_) => const TransactionFilterSheet(),
    );
    if (result == null || !mounted) return;
    _search.text = result.query;
    ref.read(txnFilterProvider.notifier).state = result;
  }

  Future<void> _record() => showStrataSheet<bool>(
        context,
        builder: (_) => const TransactionEditSheet(),
      );

  Future<void> _openDetail(Transaction txn) async {
    final result = await showStrataSheet<TxnDetailResult>(
      context,
      builder: (_) => TransactionDetailSheet(id: txn.id),
    );
    if (!mounted || result == null) return;

    switch (result) {
      case TxnDetailResult.edit:
        await showStrataSheet<bool>(
          context,
          builder: (_) => TransactionEditSheet(existing: txn),
        );
      case TxnDetailResult.delete:
        await _confirmDelete(txn);
    }
  }

  Future<void> _confirmDelete(Transaction txn) async {
    final ok = await confirmAction(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete this transaction?',
      message: '${txn.merchant}, ${txn.amountLabel}. This removes it from '
          'your history and from the spending chart.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    try {
      await ref.read(transactionsProvider.notifier).remove(txn.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      // Undo, because a delete behind a confirmation is still worth being
      // able to take back — the record is in hand, so putting it back is free.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${txn.merchant} deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => ref.read(transactionsProvider.notifier).restore(txn),
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete that. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(transactionsProvider);
    final filter = ref.watch(txnFilterProvider);
    final groups = ref.watch(transactionGroupsProvider);
    final visible = ref.watch(filteredTransactionsProvider);
    final cards =
        ref.watch(walletProvider).valueOrNull ?? const <PaymentCard>[];
    final byId = {for (final c in cards) c.id: c};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          BadgedIconButton(
            key: TransactionsScreen.filterKey,
            icon: Icons.filter_list_rounded,
            count: filter.activeCount,
            tooltip: 'Filter',
            onPressed: _openFilters,
          ),
          IconButton(
            key: TransactionsScreen.addKey,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Record a transaction',
            onPressed: _record,
          ),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            StageTransition(
              animation: _searchIn,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Space.xl, Space.sm, Space.xl, Space.md),
                child: Column(
                  children: [
                    TextField(
                      key: TransactionsScreen.searchKey,
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search a merchant',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: filter.hasQuery
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                tooltip: 'Clear the search',
                                onPressed: () => _clearFacet(TxnFacet.query),
                              )
                            : null,
                      ),
                    ),
                    if (filter.isActive) ...[
                      const SizedBox(height: Space.md),
                      _FilterSummary(
                        filter: filter,
                        cards: byId,
                        matches: visible.length,
                        onOpen: _openFilters,
                        onClearAll: _clearFilters,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: StageTransition(
                animation: _listIn,
                child: async.when(
                  loading: () => Center(
                    child: Semantics(
                      label: 'Loading your activity',
                      child: const CircularProgressIndicator.adaptive(),
                    ),
                  ),
                  error: (_, __) => StatusView(
                    icon: Icons.cloud_off_rounded,
                    title: 'Activity is unavailable',
                    message: 'We could not read your transactions.',
                    actionLabel: 'Try again',
                    onAction: () => ref.invalidate(transactionsProvider),
                  ),
                  data: (all) {
                    if (groups.isEmpty) {
                      return filter.isActive
                          ? StatusView(
                              icon: Icons.search_off_rounded,
                              title: 'No transactions match',
                              message: 'Nothing here fits the filters you '
                                  'have set. Everything is still saved.',
                              actionLabel: 'Clear filters',
                              onAction: _clearFilters,
                            )
                          : StatusView(
                              icon: Icons.receipt_long_outlined,
                              title: 'No transactions yet',
                              message: 'Payments, transfers and top-ups appear '
                                  'here as they happen.',
                              actionLabel: 'Record one',
                              onAction: _record,
                              emphasised: true,
                            );
                    }

                    return RefreshIndicator(
                      onRefresh: () {
                        ref.invalidate(transactionsProvider);
                        return AppTiming.refreshing(
                            ref.read(transactionsProvider.future));
                      },
                      child: CustomScrollView(
                        slivers: [
                          for (final group in groups)
                            SliverMainAxisGroup(
                              slivers: [
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: _DayHeaderDelegate(group: group),
                                ),
                                SliverList.list(
                                  children: [
                                    for (final txn in group.items)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: Space.xl),
                                        child: TransactionRow(
                                          key: ValueKey(txn.id),
                                          txn: txn,
                                          card: byId[txn.cardId],
                                          onTap: () => _openDetail(txn),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          SliverToBoxAdapter(
                            // The rows above it, not every row in storage.
                            // Counting `all` here meant the footer said 48
                            // under a list of 6 whenever a filter was on.
                            child: _Footer(count: visible.length),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pinned day header.
///
/// Opaque on purpose: a translucent header lets the rows scrolling beneath
/// it show through the date, which is unreadable at any blur radius.
class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DayHeaderDelegate({required this.group});

  final DayGroup group;

  static const double _height = 38;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = TxnGrouping.dayLabel(group.day);

    return Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          // "Net" rather than "total": a day can hold both a payment and a
          // refund, and calling their sum a total would be wrong.
          Text(
            'Net ${Money.signed(group.netMinor, group.currency)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeaderDelegate old) =>
      old.group.day != group.day ||
      old.group.netMinor != group.netMinor ||
      old.group.items.length != group.items.length;
}

/// One line saying what the list is narrowed to, and how much is left.
///
/// This was a [Wrap] of removable chips. Two faults, both of them the same
/// fault: the row had no fixed shape, so setting a third filter reflowed it
/// onto a second line and pushed the list down; and the number of matches
/// lived in the footer at the very bottom of the scroll, so the one fact you
/// want the instant you filter — how many are left — was the one fact you
/// had to scroll to the end to read.
///
/// So: fixed height whatever is in force, the count on it, and the whole bar
/// reopens the sheet where a facet can be changed or dropped.
class _FilterSummary extends StatelessWidget {
  const _FilterSummary({
    required this.filter,
    required this.cards,
    required this.matches,
    required this.onOpen,
    required this.onClearAll,
  });

  final TxnFilter filter;
  final Map<String, PaymentCard> cards;

  /// Rows the filter leaves, not rows that exist.
  final int matches;

  final VoidCallback onOpen;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fmt = MaterialLocalizations.of(context);

    String dateLabel() {
      final f = filter.from, t = filter.to;
      if (f != null && t != null) {
        return '${fmt.formatShortDate(f)} – ${fmt.formatShortDate(t)}';
      }
      if (f != null) return 'From ${fmt.formatShortDate(f)}';
      return 'Until ${fmt.formatShortDate(t!)}';
    }

    // Named rather than counted: "Everyday · Food" says what to expect in
    // the list, where "2 filters" only says that something is missing.
    final facets = <String>[
      if (filter.cardId != null)
        cards[filter.cardId]?.displayLabel ?? 'One card',
      if (filter.category != null) filter.category!,
      if (filter.hasDates) dateLabel(),
      if (filter.hasQuery) '“${filter.query.trim()}”',
    ];
    final summary = facets.join(' · ');
    final count = matches == 1 ? '1 transaction' : '$matches transactions';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: Radii.brLg,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              onTap: onOpen,
              pressedScale: 0.99,
              enforceMinTarget: false,
              semanticLabel: '$summary. $count',
              semanticHint: 'Opens the filters',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Space.md, Space.sm, Space.sm, Space.sm),
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded,
                        size: 17, color: scheme.onSurfaceVariant),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // One line however many facets are in force. A
                          // fourth one ellipsises rather than reflowing the
                          // bar and shoving the list down the screen.
                          Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            count,
                            maxLines: 1,
                            style: text.bodySmall?.copyWith(
                                color: matches == 0
                                    ? scheme.error
                                    : scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Clear every filter',
            child: ExcludeSemantics(
              child: IconButton(
                key: TransactionsScreen.clearFiltersKey,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Clear filters',
                onPressed: onClearAll,
              ),
            ),
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
    );
  }
}

/// Closes the list, so the last day does not sit flush against the edge and
/// the reader knows they have reached the end rather than a loading gap.
class _Footer extends StatelessWidget {
  const _Footer({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Space.xl, Space.xxl, Space.xl, Space.huge),
      child: Text(
        count == 1 ? '1 transaction' : '$count transactions',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
