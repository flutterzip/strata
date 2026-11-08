import '../models/transaction.dart';

/// Seed handling for transactions.
///
/// Where the other entities can ship fixed dates, this one cannot. The home
/// chart shows the **last seven days**, so a template whose newest
/// transaction is three months old opens on an empty chart and the buyer
/// concludes the feature is broken. The seed therefore records the date it
/// was written (`asOf`) and every row is shifted forward by however long the
/// template has been sitting on a shelf.
abstract final class TransactionSeed {
  static const String seedFile = 'transactions.json';
  static const String seedKey = 'transactions';
  static const String asOfKey = 'asOf';

  /// Whole days to move the seed forward.
  ///
  /// Never negative: if the clock is behind the seed date — a template dated
  /// ahead of release, or a device with its date set back — the rows stay
  /// where they are rather than becoming history that has not happened yet.
  static int shiftDays({required DateTime asOf, required DateTime now}) {
    final from = DateTime(asOf.year, asOf.month, asOf.day);
    final to = DateTime(now.year, now.month, now.day);
    final days = to.difference(from).inDays;
    return days > 0 ? days : 0;
  }

  /// Shift [rows] so the newest sits near [now], preserving each row's time
  /// of day and the gaps between them.
  static List<Transaction> rebase(
    List<Transaction> rows, {
    required DateTime asOf,
    required DateTime now,
  }) {
    final days = shiftDays(asOf: asOf, now: now);
    if (days == 0) return rows;
    final shift = Duration(days: days);
    return [
      for (final t in rows) t.copyWith(occurredAt: t.occurredAt.add(shift)),
    ];
  }

  /// Read `asOf` out of the seed document. Falls back to now, which makes the
  /// shift zero, so a seed file without the key simply keeps its own dates.
  static DateTime asOfIn(Map<String, dynamic> doc) =>
      DateTime.tryParse(doc[asOfKey] as String? ?? '') ?? DateTime.now();
}
