import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strata/config/app_theme.dart';
import 'package:strata/shared/widgets/pressable.dart';
import 'package:strata/shared/widgets/select_row.dart';

import '../support/harness.dart';

/// A bare host, so these assertions are about the widget rather than about
/// any screen that happens to use it.
Widget host({
  required List<SelectOption<String?>> options,
  String? selected,
  String? customLabel,
  void Function(SelectResult<String?>?)? onResult,
  TextScaler scale = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        textScaler: scale,
      ),
      child: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await showSelectSheet<String?>(
                  context,
                  title: 'Category',
                  options: options,
                  selected: selected,
                  customLabel: customLabel,
                );
                onResult?.call(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

List<SelectOption<String?>> get _categories => const [
      SelectOption(value: null, label: 'All categories'),
      SelectOption(value: 'Food', label: 'Food', startsGroup: true),
      SelectOption(value: 'Groceries', label: 'Groceries'),
      SelectOption(value: 'Health', label: 'Health'),
      SelectOption(value: 'Home', label: 'Home'),
      SelectOption(value: 'Subscriptions', label: 'Subscriptions'),
      SelectOption(value: 'Transfers', label: 'Transfers'),
      SelectOption(value: 'Transport', label: 'Transport'),
      SelectOption(value: 'Travel', label: 'Travel'),
    ];

void main() {
  testWidgets('every option is the same width, whatever its label is',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(host(options: _categories));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final rows = find
        .descendant(of: find.byType(ListView), matching: find.byType(Pressable))
        .evaluate()
        .map((e) => tester.getSize(find.byWidget(e.widget)).width)
        .toList();

    // The list is lazy, so not every option of a long set is built at once.
    expect(rows.length, greaterThanOrEqualTo(7));
    // The whole point. "Everyday", "Travel" and "Subscriptions" in a wrap of
    // pills are three different widths on two ragged lines; as rows they are
    // one column, and a ninth option changes nothing about the shape.
    expect(rows.toSet(), hasLength(1),
        reason: 'option rows must not vary in width with their label');
  });

  testWidgets('the row says what is in force without being opened',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SelectRow(
          label: 'Category',
          value: 'Food',
          onTap: () {},
        ),
      ),
    ));

    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
  });

  testWidgets('the row carries the minimum tap target', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SelectRow(label: 'Card', value: 'Everyday', onTap: () {}),
      ),
    ));

    expect(tester.getSize(find.byType(SelectRow)).height,
        greaterThanOrEqualTo(48));
  });

  testWidgets('a long label and a long value share the row without overflow',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        // The top of the range the app clamps to.
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.35),
        ),
        child: Scaffold(
          body: SelectRow(
            label: 'Monthly spending limit',
            value: 'American Express ·· 8152 · frozen',
            onTap: () {},
          ),
        ),
      ),
    ));

    // A RenderFlex overflow is reported as a thrown exception, so a clean
    // pump is the assertion.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the selected option is checked, and keeps its place',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(host(options: _categories, selected: 'Travel'));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    final labels = find
        .descendant(of: find.byType(ListView), matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .toList();
    // Last in, last shown. Floating the choice to the top would move it out
    // from under the finger that picked it.
    expect(labels.last, 'Travel');
  });

  testWidgets('a long list opens scrolled to the current choice',
      (tester) async {
    usePhoneSurface(tester, size: const Size(390, 560));
    await tester.pumpWidget(host(
      options: [
        for (var i = 0; i < 40; i++)
          SelectOption(value: 'c$i', label: 'Category $i'),
      ],
      selected: 'c35',
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Category 35'), findsOneWidget);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.controller!.position.pixels, greaterThan(0),
        reason: 'a selection far down the list must not need hunting for');
  });

  testWidgets('dismissing changes nothing, which is not the same as clearing',
      (tester) async {
    usePhoneSurface(tester);
    SelectResult<String?>? captured;
    var called = false;
    await tester.pumpWidget(host(
      options: _categories,
      selected: 'Food',
      onResult: (r) {
        captured = r;
        called = true;
      },
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap the scrim above the sheet.
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    // null, not SelectValue(null): swiping a picker away must not be read as
    // choosing "All categories" and clearing the filter.
    expect(captured, isNull);
  });

  testWidgets('choosing an option returns it', (tester) async {
    usePhoneSurface(tester);
    SelectResult<String?>? captured;
    await tester
        .pumpWidget(host(options: _categories, onResult: (r) => captured = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();

    expect(captured, isA<SelectValue<String?>>());
    expect((captured! as SelectValue<String?>).value, 'Groceries');
  });

  testWidgets('the escape hatch is reported apart from the options',
      (tester) async {
    usePhoneSurface(tester);
    SelectResult<String?>? captured;
    await tester.pumpWidget(host(
      options: _categories,
      customLabel: 'New category…',
      onResult: (r) => captured = r,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New category…'));
    await tester.pumpAndSettle();

    expect(captured, isA<SelectCustom<String?>>());
  });

  testWidgets('a nine-option picker fits the sheet and scrolls',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(host(options: _categories));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The sheet is bounded, so nothing runs off the top of the screen — the
    // failure mode a tall wrap of pills has inside a modal.
    final sheet = tester.getRect(find.byType(ListView));
    expect(sheet.top, greaterThanOrEqualTo(0));
    expect(sheet.bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });
}
