import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/models/transaction.dart';
import 'package:strata/screens/home/home_screen.dart';
import 'package:strata/screens/home/widgets/recent_activity.dart';
import 'package:strata/screens/home/widgets/spending_summary.dart';
import 'package:strata/screens/transactions/widgets/transaction_row.dart';

import '../support/harness.dart';

/// Notifications storage is seeded directly, never loaded from the bundle:
/// an asset read makes every test after the first in a file hang on a load
/// that never completes. The home screen reads the unread badge from it.
void seedPrefs({String name = 'Olympicson'}) {
  SharedPreferences.setMockInitialValues({
    'strata.profile.v1': jsonEncode({
      'name': name,
      'email': 'hello@flutterzip.com',
      'handle': '@olympicson',
      'avatar': null,
      'preferredCurrency': 'USD',
      'themeMode': 'system',
      'showDemoHints': true,
    }),
    'strata.notifications.v1': jsonEncode([
      {
        'id': 'n_01',
        'kind': 'payment',
        'title': 'Payment received',
        'body': 'Something landed.',
        'sentAt': '2026-11-07T08:12:00Z',
        'read': true,
      },
    ]),
  });
}

final now = DateTime.now();

Transaction tx(
  String id, {
  String merchant = 'Blue Bottle',
  String category = 'Food',
  int amountMinor = -475,
  int daysAgo = 0,
}) =>
    Transaction(
      id: id,
      cardId: 'c_test',
      kind: TxnKind.payment,
      merchant: merchant,
      category: category,
      amountMinor: amountMinor,
      currency: 'USD',
      occurredAt: DateTime(now.year, now.month, now.day, 12)
          .subtract(Duration(days: daysAgo)),
    );

/// Scrolls the page, not the horizontal card strip.
///
/// The home screen has two scrollables, so `scrollUntilVisible` cannot pick
/// one on its own — it throws "Too many elements" rather than guessing. The
/// outer page list is first in the tree.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(seedPrefs);

  testWidgets('home welcomes the signed-in person by first name',
      (tester) async {
    seedPrefs(name: 'Ada Lovelace');
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Welcome, Ada', findRichText: true), findsOneWidget);
    expect(find.textContaining('Good afternoon'), findsNothing);
  });

  testWidgets('home shows the newest few transactions, not all of them',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const HomeScreen(),
      transactions: [
        tx('a', merchant: 'Newest', daysAgo: 0),
        tx('b', merchant: 'Second', daysAgo: 1),
        tx('c', merchant: 'Third', daysAgo: 2),
        tx('d', merchant: 'Fourth', daysAgo: 3),
      ],
    ));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byType(RecentActivity));

    expect(find.byType(TransactionRow), findsNWidgets(RecentActivity.visible));
    expect(find.text('Newest'), findsOneWidget);
    expect(find.text('Fourth'), findsNothing);
    expect(find.text('See all'), findsWidgets);
  });

  testWidgets('the chart total is derived from those transactions',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const HomeScreen(),
      transactions: [
        tx('a', category: 'Food', amountMinor: -2000),
        tx('b', category: 'Transport', amountMinor: -1500, daysAgo: 1),
      ],
    ));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byType(SpendingSummary));

    expect(find.text('Spent this week'), findsOneWidget);
    expect(find.text(r'$35.00'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
  });

  testWidgets('spending older than the week is not in the chart',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const HomeScreen(),
      transactions: [
        tx('a', category: 'Food', amountMinor: -2000, daysAgo: 0),
        tx('b', category: 'Groceries', amountMinor: -500, daysAgo: 2),
        tx('c', category: 'Travel', amountMinor: -90000, daysAgo: 40),
      ],
    ));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byType(SpendingSummary));

    // The headline total counts only the week; the 40-day-old trip is
    // neither in the figure nor in the legend.
    expect(find.text(r'$25.00'), findsOneWidget);
    expect(find.text('Travel'), findsNothing);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
  });

  testWidgets(
      'no transactions is an empty chart and an empty list, not a crash',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const HomeScreen(),
      transactions: const [],
    ));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byType(RecentActivity));

    expect(find.text('Nothing spent this week'), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.byType(TransactionRow), findsNothing);
  });
}
