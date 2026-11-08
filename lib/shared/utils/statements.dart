import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../models/transaction.dart';

/// One month of activity on one card.
@immutable
class Statement {
  const Statement({
    required this.month,
    required this.currency,
    required this.inMinor,
    required this.outMinor,
    required this.count,
  });

  /// First day of the month this covers.
  final DateTime month;

  final String currency;

  /// Positive figures: money in and money out, kept apart rather than netted,
  /// because a month where £3,000 arrived and £3,000 left is not the same as
  /// a month where nothing happened.
  final int inMinor;
  final int outMinor;

  final int count;

  int get netMinor => inMinor - outMinor;

  static final DateFormat _label = DateFormat('MMMM y');

  String get label => _label.format(month);
}

/// Monthly statements, derived from transactions.
///
/// Nothing is stored: a statement is a view over the rows that are already
/// there. Generating and keeping them would create a second record to
/// disagree with the first every time a transaction is edited.
abstract final class Statements {
  static List<Statement> forCard(List<Transaction> txns, String cardId) {
    final byMonth = <DateTime, List<Transaction>>{};
    for (final t in txns) {
      if (t.cardId != cardId) continue;
      final key = DateTime(t.occurredAt.year, t.occurredAt.month);
      byMonth.putIfAbsent(key, () => []).add(t);
    }

    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final month in months)
        Statement(
          month: month,
          currency: byMonth[month]!.first.currency,
          inMinor: byMonth[month]!
              .where((t) => !t.isMoneyOut)
              .fold<int>(0, (s, t) => s + t.amountMinor),
          outMinor: byMonth[month]!
              .where((t) => t.isMoneyOut)
              .fold<int>(0, (s, t) => s + t.amountMinor.abs()),
          count: byMonth[month]!.length,
        ),
    ];
  }
}
