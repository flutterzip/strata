import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../models/transaction.dart';

/// One day's worth of transactions, newest first.
@immutable
class DayGroup {
  const DayGroup({required this.day, required this.items});

  /// Midnight on the day these happened.
  final DateTime day;

  final List<Transaction> items;

  /// Signed net for the day — what the balance moved by.
  int get netMinor => items.fold<int>(0, (sum, t) => sum + t.amountMinor);

  /// Currency to print [netMinor] in. Mixed-currency days are possible in a
  /// multi-currency wallet, so this is the first row's currency and the
  /// header says "net" rather than claiming a total.
  String get currency => items.isEmpty ? 'USD' : items.first.currency;
}

/// Grouping and labelling for the transaction list.
///
/// Pure functions, kept out of the widget so the day boundaries and the
/// month/year rollovers can be tested without pumping a frame.
abstract final class TxnGrouping {
  /// Group by calendar day, newest day first, newest row first within a day.
  ///
  /// Sorting on the full [DateTime] rather than the day of the month is what
  /// makes 31 January sit below 1 February instead of above it.
  static List<DayGroup> byDay(List<Transaction> txns) {
    if (txns.isEmpty) return const [];

    final buckets = <DateTime, List<Transaction>>{};
    for (final t in txns) {
      buckets.putIfAbsent(t.day, () => []).add(t);
    }

    final days = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days)
        DayGroup(
          day: day,
          items: buckets[day]!
            ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt)),
        ),
    ];
  }

  static final DateFormat _sameYear = DateFormat('EEE d MMM');
  static final DateFormat _otherYear = DateFormat('EEE d MMM y');

  /// Header text for a day. Relative for the two days a reader can place
  /// without thinking; dated after that, with the year only once it matters.
  static String dayLabel(DateTime day, {DateTime? now}) {
    final today = _midnight(now ?? DateTime.now());
    final d = _midnight(day);
    final delta = today.difference(d).inDays;
    if (delta == 0) return 'Today';
    if (delta == 1) return 'Yesterday';
    return d.year == today.year ? _sameYear.format(d) : _otherYear.format(d);
  }

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Distinct categories present, alphabetically — the filter sheet's
  /// options, so it can never offer a category nothing is filed under.
  static List<String> categoriesIn(List<Transaction> txns) {
    final set = {for (final t in txns) t.categoryLabel};
    return set.toList()..sort();
  }
}
