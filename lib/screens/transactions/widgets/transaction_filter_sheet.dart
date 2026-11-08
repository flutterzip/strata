import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/payment_card.dart';
import '../../../models/txn_filter.dart';
import '../../../providers/transaction_providers.dart';
import '../../../providers/wallet_providers.dart';
import '../../../shared/widgets/select_row.dart';
import '../../../shared/widgets/settings_row.dart';
import '../../../shared/widgets/strata_sheet.dart';

/// A named date window, so the common cases need no calendar at all.
enum DateWindow {
  all('Any time'),
  last7('Last 7 days'),
  last30('Last 30 days'),
  thisMonth('This month'),
  lastMonth('Last month'),
  custom('Pick dates…');

  const DateWindow(this.label);

  final String label;

  /// Resolve to inclusive day bounds. [all] and [custom] resolve to nothing;
  /// [custom] is answered by the date-range picker instead.
  (DateTime?, DateTime?) bounds(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      DateWindow.all => (null, null),
      DateWindow.custom => (null, null),
      DateWindow.last7 => (today.subtract(const Duration(days: 6)), today),
      DateWindow.last30 => (today.subtract(const Duration(days: 29)), today),
      DateWindow.thisMonth => (DateTime(now.year, now.month), today),
      DateWindow.lastMonth => (
          DateTime(now.year, now.month - 1),
          DateTime(now.year, now.month).subtract(const Duration(days: 1)),
        ),
    };
  }
}

/// Narrow the transaction list by card, category and date.
///
/// Edits a draft and applies on confirm, so backing out of the sheet leaves
/// the list exactly as it was. The search field stays on the screen — it is
/// the one filter that wants to take effect as you type.
class TransactionFilterSheet extends ConsumerStatefulWidget {
  const TransactionFilterSheet({super.key});

  static const Key cardRow = Key('filter-card');
  static const Key categoryRow = Key('filter-category');
  static const Key datesRow = Key('filter-dates');

  @override
  ConsumerState<TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState
    extends ConsumerState<TransactionFilterSheet> {
  late TxnFilter _draft = ref.read(txnFilterProvider);
  late DateWindow _window = _windowFor(_draft);

  /// Which preset the current bounds correspond to, so reopening the sheet
  /// shows the choice that is actually in force rather than resetting it.
  static DateWindow _windowFor(TxnFilter f) {
    if (!f.hasDates) return DateWindow.all;
    final now = DateTime.now();
    for (final w in DateWindow.values) {
      if (w == DateWindow.all || w == DateWindow.custom) continue;
      final (from, to) = w.bounds(now);
      if (from == f.from && to == f.to) return w;
    }
    return DateWindow.custom;
  }

  /// Pick the card the list is narrowed to. `null` is every card.
  Future<void> _chooseCard(List<PaymentCard> cards) async {
    final result = await showSelectSheet<String?>(
      context,
      title: 'Card',
      icon: Icons.credit_card_rounded,
      selected: _draft.cardId,
      options: [
        const SelectOption(value: null, label: 'All cards'),
        for (final c in cards)
          SelectOption(
            value: c.id,
            label: c.displayLabel,
            detail: c.shortMask,
            startsGroup: c == cards.first,
            semanticLabel: c.describedForAccessibility,
          ),
      ],
    );
    if (result == null || !mounted) return;
    setState(() {
      _draft = switch (result) {
        SelectValue(value: final id?) => _draft.copyWith(cardId: id),
        _ => _draft.cleared(TxnFacet.card),
      };
    });
  }

  /// Pick the category. `null` is every category.
  Future<void> _chooseCategory(List<String> categories) async {
    final result = await showSelectSheet<String?>(
      context,
      title: 'Category',
      icon: Icons.sell_outlined,
      selected: _draft.category,
      options: [
        const SelectOption(value: null, label: 'All categories'),
        for (final c in categories)
          SelectOption(
            value: c,
            label: c,
            startsGroup: c == categories.first,
          ),
      ],
    );
    if (result == null || !mounted) return;
    setState(() {
      _draft = switch (result) {
        SelectValue(value: final c?) => _draft.copyWith(category: c),
        _ => _draft.cleared(TxnFacet.category),
      };
    });
  }

  Future<void> _chooseDates() async {
    final result = await showSelectSheet<DateWindow>(
      context,
      title: 'Dates',
      icon: Icons.event_outlined,
      selected: _window,
      options: [
        for (final w in DateWindow.values)
          SelectOption(
            value: w,
            label: w == DateWindow.custom && _window == DateWindow.custom
                ? _customLabel()
                : w.label,
            startsGroup: w == DateWindow.last7,
          ),
      ],
    );
    if (result == null || !mounted) return;
    if (result case SelectValue(value: final w)) await _choose(w);
  }

  Future<void> _choose(DateWindow w) async {
    if (w == DateWindow.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: now,
        initialDateRange: _draft.from != null && _draft.to != null
            ? DateTimeRange(start: _draft.from!, end: _draft.to!)
            : null,
        helpText: 'Which dates?',
      );
      if (picked == null || !mounted) return;
      setState(() {
        _window = DateWindow.custom;
        _draft = _draft.copyWith(from: picked.start, to: picked.end);
      });
      return;
    }
    final (from, to) = w.bounds(DateTime.now());
    setState(() {
      _window = w;
      _draft = _draft.cleared(TxnFacet.dates).copyWith(from: from, to: to);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(walletProvider).valueOrNull ?? const [];
    final categories = ref.watch(txnCategoriesProvider);

    return StrataSheet(
      icon: Icons.filter_list_rounded,
      title: 'Filter',
      message: 'Narrowing the list does not change the week on the home '
          'chart, which always shows everything.',
      scrollable: true,
      body: SettingsGroup(
        children: [
          SelectRow(
            key: TransactionFilterSheet.cardRow,
            label: 'Card',
            value: _draft.cardId == null
                ? 'All cards'
                : cards
                        .where((c) => c.id == _draft.cardId)
                        .map((c) => '${c.displayLabel} ${c.shortMask}')
                        .firstOrNull ??
                    'All cards',
            placeholder: _draft.cardId == null,
            onTap: () => _chooseCard(cards),
          ),
          SelectRow(
            key: TransactionFilterSheet.categoryRow,
            label: 'Category',
            value: _draft.category ?? 'All categories',
            placeholder: _draft.category == null,
            onTap: () => _chooseCategory(categories),
          ),
          SelectRow(
            key: TransactionFilterSheet.datesRow,
            label: 'Dates',
            value:
                _window == DateWindow.custom ? _customLabel() : _window.label,
            placeholder: _window == DateWindow.all,
            onTap: _chooseDates,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_draft),
          child: const Text('Show these'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(
            // Keep whatever is in the search field; that control is not here.
            TxnFilter.none.copyWith(query: _draft.query),
          ),
          child: const Text('Clear all'),
        ),
      ],
    );
  }

  String _customLabel() {
    final f = _draft.from, t = _draft.to;
    if (f == null || t == null) return DateWindow.custom.label;
    final fmt = MaterialLocalizations.of(context);
    return '${fmt.formatShortDate(f)} – ${fmt.formatShortDate(t)}';
  }
}
