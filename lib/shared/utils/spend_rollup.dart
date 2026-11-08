import '../../config/palette.dart';
import '../../models/spend_category.dart';
import '../../models/transaction.dart';

/// Derives the home "Spent this week" summary from transactions.
///
/// The chart used to read its own seed file, which meant editing a
/// transaction left the chart stating something that was no longer true.
/// One source of truth: the chart is a view over the same records the list
/// shows.
abstract final class SpendRollup {
  /// How many slices the chart can draw. [ChartRamp] is one hue stepped by
  /// lightness and has exactly this many steps; a sixth slice would need a
  /// second hue, and there is only one accent in this app.
  static int get maxSlices => ChartRamp.light.length;

  /// Money that left the account in the last [days] days, by category.
  ///
  /// Only negative amounts count: the chart answers "what did I spend",
  /// so a refund is not a negative expense, it is simply not spending.
  ///
  /// Mixed currencies are never added together. [preferredCurrency] — the
  /// wallet's own, the one the headline balance is in — wins whenever any
  /// spending is in it, so one holiday purchase abroad cannot silently
  /// redenominate the home chart. Only when nothing was spent in it does the
  /// largest other currency take over, and the rest are then left out rather
  /// than summed into a figure that means nothing.
  static SpendSummary fromTransactions(
    List<Transaction> txns, {
    required DateTime now,
    int days = 7,
    String preferredCurrency = 'USD',
    String periodLabel = 'Spent this week',
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final since = today.subtract(Duration(days: days - 1));
    // The window closes at the end of today, not at this instant. Clipping
    // at `now` hides anything stamped later in the day — which the seed's
    // evening rows are, and which an opening balance written at 18:00 would
    // be if you looked at the chart at breakfast.
    final until = today
        .add(const Duration(days: 1))
        .subtract(const Duration(microseconds: 1));

    final spend = [
      for (final t in txns)
        if (t.isMoneyOut &&
            !t.occurredAt.isBefore(since) &&
            !t.occurredAt.isAfter(until))
          t,
    ];

    if (spend.isEmpty) {
      return SpendSummary(
        periodLabel: periodLabel,
        currency: preferredCurrency,
        categories: const [],
      );
    }

    final byCurrency = <String, int>{};
    for (final t in spend) {
      byCurrency[t.currency] =
          (byCurrency[t.currency] ?? 0) + t.amountMinor.abs();
    }
    // The wallet's own currency if anything at all was spent in it;
    // otherwise whichever currency the most money moved in. Counting rows
    // instead of amounts would let twenty small coffees outvote the rent.
    final currency = byCurrency.containsKey(preferredCurrency)
        ? preferredCurrency
        : byCurrency.entries.reduce((a, b) => b.value > a.value ? b : a).key;

    final totals = <String, int>{};
    for (final t in spend.where((t) => t.currency == currency)) {
      totals[t.categoryLabel] =
          (totals[t.categoryLabel] ?? 0) + t.amountMinor.abs();
    }

    final ordered = totals.entries.toList()
      ..sort((a, b) {
        final byValue = b.value.compareTo(a.value);
        // Ties would otherwise order by hash and the chart would reshuffle
        // itself between builds.
        return byValue != 0 ? byValue : a.key.compareTo(b.key);
      });

    final categories = <SpendCategory>[];
    if (ordered.length <= maxSlices) {
      for (final e in ordered) {
        categories.add(SpendCategory(label: e.key, minor: e.value));
      }
    } else {
      for (final e in ordered.take(maxSlices - 1)) {
        categories.add(SpendCategory(label: e.key, minor: e.value));
      }
      final rest =
          ordered.skip(maxSlices - 1).fold<int>(0, (sum, e) => sum + e.value);
      categories.add(SpendCategory(label: 'Other', minor: rest));
    }

    return SpendSummary(
      periodLabel: periodLabel,
      currency: currency,
      categories: categories,
    );
  }
}
