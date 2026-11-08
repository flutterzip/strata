import 'package:flutter_test/flutter_test.dart';
import 'package:strata/models/transaction.dart';
import 'package:strata/shared/utils/spend_rollup.dart';

final now = DateTime(2026, 3, 4, 12);

Transaction out(String category, int minor,
        {int daysAgo = 1, String currency = 'USD'}) =>
    Transaction(
      id: 't_${category}_$minor$daysAgo',
      cardId: 'c_forest',
      kind: TxnKind.payment,
      merchant: 'M',
      category: category,
      amountMinor: -minor,
      currency: currency,
      occurredAt: now.subtract(Duration(days: daysAgo)),
    );

void main() {
  test('sums money out by category, biggest first', () {
    final s = SpendRollup.fromTransactions([
      out('Food', 1000),
      out('Transport', 3000),
      out('Food', 500, daysAgo: 2),
    ], now: now);

    expect(s.categories.map((c) => c.label), ['Transport', 'Food']);
    expect(s.categories.map((c) => c.minor), [3000, 1500]);
    expect(s.totalMinor, 4500);
  });

  test('money in is not spending', () {
    final s = SpendRollup.fromTransactions([
      out('Food', 1000),
      Transaction(
        id: 'r',
        cardId: 'c_forest',
        kind: TxnKind.refund,
        merchant: 'M',
        category: 'Food',
        amountMinor: 400,
        currency: 'USD',
        occurredAt: now.subtract(const Duration(days: 1)),
      ),
    ], now: now);

    // A refund reduces nothing here: the chart shows what left the account.
    expect(s.totalMinor, 1000);
  });

  test('only the last seven days count', () {
    final s = SpendRollup.fromTransactions([
      out('Food', 1000, daysAgo: 1),
      out('Food', 9999, daysAgo: 30),
    ], now: now);
    expect(s.totalMinor, 1000);
  });

  test('something that happened moments ago is inside the window', () {
    final s =
        SpendRollup.fromTransactions([out('Food', 700, daysAgo: 0)], now: now);
    expect(s.totalMinor, 700);
  });

  test('something stamped later today is still part of today', () {
    // Clipping the window at the current instant hides the evening's
    // transactions from anyone who opens the app in the morning.
    final s = SpendRollup.fromTransactions([
      Transaction(
        id: 'tonight',
        cardId: 'c_forest',
        kind: TxnKind.payment,
        merchant: 'M',
        category: 'Food',
        amountMinor: -900,
        currency: 'USD',
        occurredAt: DateTime(now.year, now.month, now.day, 23, 30),
      ),
    ], now: DateTime(now.year, now.month, now.day, 7));

    expect(s.totalMinor, 900);
  });

  test('tomorrow is not part of this week', () {
    final s = SpendRollup.fromTransactions([
      Transaction(
        id: 'tomorrow',
        cardId: 'c_forest',
        kind: TxnKind.payment,
        merchant: 'M',
        category: 'Food',
        amountMinor: -900,
        currency: 'USD',
        occurredAt: now.add(const Duration(days: 1)),
      ),
    ], now: now);

    expect(s.totalMinor, 0);
  });

  test('the seventh day back is in, the eighth is out', () {
    final boundary =
        SpendRollup.fromTransactions([out('Food', 100, daysAgo: 6)], now: now);
    expect(boundary.totalMinor, 100);

    final past =
        SpendRollup.fromTransactions([out('Food', 100, daysAgo: 7)], now: now);
    expect(past.totalMinor, 0);
  });

  test('mixing currencies keeps the wallet currency rather than adding them',
      () {
    // Adding 10 EUR to 10 USD is the classic money bug. The chart stays in
    // the currency the headline balance is in and leaves the rest out, even
    // when the foreign spending is larger.
    final s = SpendRollup.fromTransactions([
      out('Food', 1000),
      out('Transport', 2000),
      out('Travel', 5000, currency: 'EUR'),
    ], now: now);

    expect(s.currency, 'USD');
    expect(s.totalMinor, 3000);
    expect(s.categories.map((c) => c.label), isNot(contains('Travel')));
  });

  test('falls back to the largest currency when the wallet currency is unused',
      () {
    // A EUR-only card must still get a chart, not an empty one.
    final s = SpendRollup.fromTransactions([
      out('Travel', 5000, currency: 'EUR'),
      out('Food', 1000, currency: 'GBP'),
    ], now: now, preferredCurrency: 'USD');

    expect(s.currency, 'EUR');
    expect(s.totalMinor, 5000);
  });

  test('more categories than the chart ramp collapse into Other', () {
    // ChartRamp has five steps; a sixth hue would have to come from
    // somewhere, and there is only one accent.
    final s = SpendRollup.fromTransactions([
      out('A', 6000),
      out('B', 5000),
      out('C', 4000),
      out('D', 3000),
      out('E', 200),
      out('F', 100),
    ], now: now);

    expect(s.categories, hasLength(5));
    expect(s.categories.last.label, 'Other');
    expect(s.categories.last.minor, 300);
    expect(s.totalMinor, 18300);
  });

  test('exactly five categories are all named', () {
    final s = SpendRollup.fromTransactions([
      out('A', 500),
      out('B', 400),
      out('C', 300),
      out('D', 200),
      out('E', 100),
    ], now: now);
    expect(s.categories.map((c) => c.label), ['A', 'B', 'C', 'D', 'E']);
  });

  test('nothing spent is an empty summary, not a crash', () {
    final s = SpendRollup.fromTransactions(const [], now: now);
    expect(s.categories, isEmpty);
    expect(s.totalMinor, 0);
    expect(s.currency, 'USD');
    expect(s.periodLabel, 'Spent this week');
  });

  test('an untitled category is still shown, not dropped', () {
    final s = SpendRollup.fromTransactions([out('', 1000)], now: now);
    expect(s.categories.single.label, 'Uncategorised');
  });
}
