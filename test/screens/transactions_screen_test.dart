import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strata/models/transaction.dart';
import 'package:strata/screens/transactions/transactions_screen.dart';
import 'package:strata/screens/transactions/widgets/transaction_row.dart';
import 'package:strata/services/transaction_repository.dart';
import 'package:strata/screens/transactions/widgets/transaction_filter_sheet.dart';
import 'package:strata/screens/transactions/widgets/transaction_edit_sheet.dart';
import 'package:strata/shared/widgets/pressable.dart';
import 'package:strata/shared/widgets/segmented_toggle.dart';
import 'package:strata/shared/widgets/select_row.dart';
import 'package:strata/shared/widgets/status_view.dart';

import '../support/harness.dart';

final now = DateTime.now();

Transaction tx(
  String id, {
  String merchant = 'Blue Bottle',
  String category = 'Food',
  int amountMinor = -475,
  int daysAgo = 0,
  String cardId = 'c_test',
  String? note,
  TxnKind kind = TxnKind.payment,
}) =>
    Transaction(
      id: id,
      cardId: cardId,
      kind: kind,
      merchant: merchant,
      category: category,
      amountMinor: amountMinor,
      currency: 'USD',
      // Midday, so a test running just after midnight cannot roll a row
      // into the previous day and change its header.
      occurredAt: DateTime(now.year, now.month, now.day, 12)
          .subtract(Duration(days: daysAgo)),
      note: note,
    );

void main() {
  testWidgets('shows a loading state before transactions arrive',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      txnRepository: InMemoryTransactionRepository(
        seed: [tx('a')],
        latency: const Duration(milliseconds: 60),
      ),
    ));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('groups rows under a day header, newest day first',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [
        tx('a', merchant: 'Blue Bottle', daysAgo: 0),
        tx('b', merchant: 'City Rail', daysAgo: 1),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Blue Bottle'), findsOneWidget);
    expect(find.text('City Rail'), findsOneWidget);
    expect(find.byType(TransactionRow), findsNWidgets(2));

    // Today's header must sit above yesterday's.
    expect(tester.getTopLeft(find.text('Today')).dy,
        lessThan(tester.getTopLeft(find.text('Yesterday')).dy));
  });

  testWidgets('grouping survives a month boundary', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [
        Transaction(
          id: 'feb',
          cardId: 'c_test',
          kind: TxnKind.payment,
          merchant: 'Rollover later',
          category: 'Food',
          amountMinor: -100,
          currency: 'USD',
          occurredAt: DateTime(2026, 2, 1, 9),
        ),
        Transaction(
          id: 'jan',
          cardId: 'c_test',
          kind: TxnKind.payment,
          merchant: 'Rollover earlier',
          category: 'Food',
          amountMinor: -100,
          currency: 'USD',
          occurredAt: DateTime(2026, 1, 31, 18),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    // Two separate headers, February above January. The exact label format
    // is asserted in transaction_test.dart; what matters here is that the
    // rollover does not collapse the two days into one group or invert them.
    expect(find.textContaining('Feb'), findsOneWidget);
    expect(find.textContaining('Jan'), findsOneWidget);
    expect(tester.getTopLeft(find.textContaining('Feb')).dy,
        lessThan(tester.getTopLeft(find.textContaining('Jan')).dy));
    expect(tester.getTopLeft(find.text('Rollover later')).dy,
        lessThan(tester.getTopLeft(find.text('Rollover earlier')).dy));
  });

  testWidgets('a signed amount is announced as paid or received',
      (tester) async {
    usePhoneSurface(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [
        tx('a', merchant: 'Blue Bottle', amountMinor: -475),
        tx('b', merchant: 'Payroll', amountMinor: 412000, kind: TxnKind.topUp),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text(r'-$4.75'), findsOneWidget);
    expect(find.text(r'+$4,120.00'), findsOneWidget);
    expect(hasSemanticsLabel(tester, r'Blue Bottle, paid $4.75, Food'), isTrue);
    expect(hasSemanticsLabel(tester, r'Payroll, received $4,120.00, Food'),
        isTrue);
    handle.dispose();
  });

  testWidgets('search narrows by merchant', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [
        tx('a', merchant: 'Blue Bottle'),
        tx('b', merchant: 'City Rail'),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(TransactionsScreen.searchKey), 'rail');
    await tester.pumpAndSettle();

    expect(find.text('City Rail'), findsOneWidget);
    expect(find.text('Blue Bottle'), findsNothing);
  });

  testWidgets(
      'a filter that matches nothing explains itself and offers a way back',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [tx('a', merchant: 'Blue Bottle')],
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(TransactionsScreen.searchKey), 'nothing matches this');
    await tester.pumpAndSettle();

    expect(find.byType(TransactionRow), findsNothing);
    expect(find.byType(StatusView), findsOneWidget);
    expect(find.text('No transactions match'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionRow), findsOneWidget);
    expect(find.byType(StatusView), findsNothing);
  });

  testWidgets(
      'an empty wallet history is a different message from a filter miss',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: const [],
    ));
    await tester.pumpAndSettle();

    expect(find.text('No transactions yet'), findsOneWidget);
    expect(find.text('Clear filters'), findsNothing);
  });

  testWidgets('loading failure offers a retry', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      txnRepository: FailingTransactionRepository(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(StatusView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('tapping a row opens its detail, with the note shown',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [
        tx('a', merchant: 'Blue Bottle', note: 'morning flat white')
      ],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TransactionRow));
    await tester.pumpAndSettle();

    expect(find.text('morning flat white'), findsOneWidget);
    expect(find.byKey(TransactionsScreen.editKey), findsOneWidget);
    expect(find.byKey(TransactionsScreen.deleteKey), findsOneWidget);
  });

  testWidgets('editing the note from the detail sheet updates the list',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [tx('a', merchant: 'Blue Bottle', note: 'old note')],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TransactionRow));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TransactionsScreen.editKey));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(TransactionsScreen.noteKey), 'new note');
    await tester.tap(find.byKey(TransactionsScreen.saveKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TransactionRow));
    await tester.pumpAndSettle();
    expect(find.text('new note'), findsOneWidget);
    expect(find.text('old note'), findsNothing);
  });

  testWidgets('deleting asks first, and a refusal keeps the row',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [tx('a', merchant: 'Blue Bottle')],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TransactionRow));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TransactionsScreen.deleteKey));
    await tester.pumpAndSettle();

    expect(find.text('Delete this transaction?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionRow), findsOneWidget);
  });

  testWidgets('confirming a delete removes the row', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [
        tx('a', merchant: 'Blue Bottle'),
        tx('b', merchant: 'City Rail'),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blue Bottle'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TransactionsScreen.deleteKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Blue Bottle'), findsNothing);
    expect(find.text('City Rail'), findsOneWidget);
  });

  testWidgets('a new transaction can be recorded and appears in the list',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [tx('a', merchant: 'Blue Bottle')],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TransactionsScreen.addKey));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(TransactionsScreen.merchantKey), 'Thornfield Hardware');
    await tester.enterText(find.byKey(TransactionsScreen.amountKey), '42.50');
    await tester.tap(find.byKey(TransactionsScreen.saveKey));
    await tester.pumpAndSettle();

    expect(find.text('Thornfield Hardware'), findsOneWidget);
    expect(find.text(r'-$42.50'), findsOneWidget);
  });

  testWidgets(
      'saving with nothing entered says what is missing rather than going dead',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [tx('a')],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TransactionsScreen.addKey));
    await tester.pumpAndSettle();

    // The button stays pressable and names the first failing field — a
    // disabled control that explains nothing is the thing this app forbids.
    await tester.tap(find.byKey(TransactionsScreen.saveKey));
    await tester.pumpAndSettle();

    expect(find.text('Enter who was paid'), findsOneWidget);
  });

  testWidgets('the category is one control, with a way to type a new one',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [tx('a', merchant: 'Blue Bottle', category: 'Food')],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TransactionsScreen.addKey));
    await tester.pumpAndSettle();

    // One control for the value. It was a text field *and* a wrap of
    // suggestion pills, with nothing saying which was in force.
    expect(find.byKey(TransactionEditSheet.categoryRow), findsOneWidget);
    expect(find.byKey(TransactionsScreen.categoryKey), findsNothing);

    // The sheet scrolls, so the row has to be brought into view before it
    // can be tapped — existence is not reachability.
    await tester.ensureVisible(find.byKey(TransactionEditSheet.categoryRow));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TransactionEditSheet.categoryRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsWidgets);

    // And the escape hatch reveals the field for a category that does not
    // exist yet.
    await tester.ensureVisible(find.byKey(TransactionEditSheet.categoryRow));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TransactionEditSheet.categoryRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New category…'));
    await tester.pumpAndSettle();

    expect(find.byKey(TransactionsScreen.categoryKey), findsOneWidget);
    await tester.enterText(
        find.byKey(TransactionsScreen.categoryKey), 'Bicycle');
    await tester.pumpAndSettle();
    expect(find.text('Bicycle'), findsWidgets);
  });

  testWidgets('money in and out is a two-way toggle, not a pair of pills',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [tx('a', merchant: 'Blue Bottle')],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TransactionsScreen.addKey));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedToggle), findsOneWidget);
    // Two symmetrical choices get equal halves by construction.
    final toggle = tester.getSize(find.byType(SegmentedToggle));
    expect(toggle.width, greaterThan(0));
    expect(find.text('Out'), findsOneWidget);
    expect(find.text('In'), findsOneWidget);
  });

  testWidgets('the match count is on screen the moment you filter',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [
        tx('a', merchant: 'Blue Bottle', category: 'Food'),
        tx('b', merchant: 'Metro', category: 'Transport'),
        tx('c', merchant: 'Greenmarket', category: 'Groceries'),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(TransactionsScreen.searchKey), 'blue');
    await tester.pumpAndSettle();

    // Without scrolling: this used to live in the footer at the bottom of
    // the whole list.
    expect(find.text('1 transaction'), findsWidgets);
    final summary = tester.getRect(find.text('1 transaction').first);
    expect(summary.bottom, lessThan(844),
        reason: 'the count must be visible without scrolling');
  });

  testWidgets('the count is of the rows shown, not of every row stored',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [
        tx('a', merchant: 'Blue Bottle', category: 'Food'),
        tx('b', merchant: 'Metro', category: 'Transport'),
        tx('c', merchant: 'Greenmarket', category: 'Groceries'),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(TransactionsScreen.searchKey), 'blue');
    await tester.pumpAndSettle();

    // The footer counted the unfiltered list, so it said "3 transactions"
    // under a list of one.
    expect(find.text('3 transactions'), findsNothing);
    expect(find.text('1 transaction'), findsWidgets);
  });

  testWidgets('three facets at once stay on one line and do not grow the bar',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [tx('a', merchant: 'Blue Bottle', category: 'Food')],
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(TransactionsScreen.searchKey), 'blue');
    await tester.pumpAndSettle();
    final oneFacet = tester.getSize(find.byKey(TransactionsScreen.searchKey));
    final listTop = tester.getRect(find.byType(TransactionRow).first).top;

    // Add two more facets.
    await tester.tap(find.byKey(TransactionsScreen.filterKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TransactionFilterSheet.categoryRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TransactionFilterSheet.datesRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 30 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show these'));
    await tester.pumpAndSettle();

    // Three chips in a wrap reflowed onto a second line and pushed the list
    // down the screen. One line does not.
    expect(tester.getSize(find.byKey(TransactionsScreen.searchKey)), oneFacet);
    expect(tester.getRect(find.byType(TransactionRow).first).top, listTop,
        reason: 'the list must not move when a third filter is set');
  });

  testWidgets('the summary bar clears every filter at once', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [
        tx('a', merchant: 'Blue Bottle', category: 'Food'),
        tx('b', merchant: 'Metro', category: 'Transport'),
      ],
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(TransactionsScreen.searchKey), 'blue');
    await tester.pumpAndSettle();
    expect(find.byType(TransactionRow), findsOneWidget);

    await tester.tap(find.byKey(TransactionsScreen.clearFiltersKey));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionRow), findsNWidgets(2));
    expect(find.byKey(TransactionsScreen.clearFiltersKey), findsNothing);
  });

  testWidgets('the summary bar reopens the filters', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [tx('a', merchant: 'Blue Bottle', category: 'Food')],
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(TransactionsScreen.searchKey), 'blue');
    await tester.pumpAndSettle();

    await tester.tap(find.text('1 transaction').first);
    await tester.pumpAndSettle();

    expect(find.byType(SelectRow), findsNWidgets(3));
  });

  testWidgets('the filter rows and their options meet the tap target',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [tx('a', merchant: 'Blue Bottle')],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TransactionsScreen.filterKey));
    await tester.pumpAndSettle();

    final rows = find.byType(SelectRow);
    expect(rows, findsNWidgets(3));
    for (final row in rows.evaluate()) {
      expect(tester.getSize(find.byWidget(row.widget)).height,
          greaterThanOrEqualTo(48),
          reason: 'a filter row must be hittable');
    }

    // And every option inside a picker.
    await tester.tap(find.byKey(TransactionFilterSheet.categoryRow));
    await tester.pumpAndSettle();

    final options = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Pressable),
    );
    expect(options, findsWidgets);
    for (final option in options.evaluate()) {
      expect(tester.getSize(find.byWidget(option.widget)).height,
          greaterThanOrEqualTo(48),
          reason: 'an option must be hittable');
    }
  });

  testWidgets('the filter rows say what is in force before being opened',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [tx('a', merchant: 'Blue Bottle', category: 'Food')],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(TransactionsScreen.filterKey));
    await tester.pumpAndSettle();

    // At rest the sheet reads as a summary, which is the whole reason these
    // are rows and not a wrap of pills.
    expect(find.text('All cards'), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('Any time'), findsOneWidget);

    await tester.tap(find.byKey(TransactionFilterSheet.categoryRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();

    expect(find.text('Food'), findsOneWidget);
    expect(find.text('All categories'), findsNothing);
  });

  testWidgets('a picker keeps its order and never reorders on selection',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [
        tx('a', merchant: 'Blue Bottle', category: 'Food'),
        tx('b', merchant: 'Metro', category: 'Transport'),
      ],
    ));
    await tester.pumpAndSettle();

    Future<List<String>> openAndReadOptions() async {
      await tester.tap(find.byKey(TransactionsScreen.filterKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TransactionFilterSheet.categoryRow));
      await tester.pumpAndSettle();
      return find
          .descendant(of: find.byType(ListView), matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data!)
          .toList();
    }

    final before = await openAndReadOptions();
    expect(before, ['All categories', 'Food', 'Transport']);

    // Pick the last one, then reopen: the chosen option must still be where
    // it was. Floating it to the top would mean the list rearranges itself
    // as a consequence of the reader's own tap.
    await tester.tap(find.text('Transport').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show these'));
    await tester.pumpAndSettle();

    final after = await openAndReadOptions();
    expect(after, before, reason: 'the order must not depend on the choice');
  });

  testWidgets('renders in dark mode without overflowing', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      dark: true,
      transactions: [
        tx('a', merchant: 'Blue Bottle', daysAgo: 0),
        tx('b', merchant: 'Payroll', amountMinor: 412000, kind: TxnKind.topUp),
        tx('c', merchant: 'City Rail', daysAgo: 1),
      ],
    ));
    await tester.pumpAndSettle();

    // An overflow raises a framework exception, which the harness surfaces
    // as a test failure, so reaching here with the rows drawn is the check.
    expect(find.byType(TransactionRow), findsNWidgets(3));
    expect(find.text('Today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every row meets the minimum tap target', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const TransactionsScreen(),
      transactions: [tx('a'), tx('b', daysAgo: 1)],
    ));
    await tester.pumpAndSettle();

    for (final row in find.byType(TransactionRow).evaluate()) {
      final size = tester.getSize(find.byWidget(row.widget));
      expect(size.height, greaterThanOrEqualTo(48),
          reason: 'a row shorter than 48dp cannot be hit reliably');
    }
  });
}
