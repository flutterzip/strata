import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strata/config/app_theme.dart';
import 'package:strata/shared/widgets/strata_nav_bar.dart';

import '../support/harness.dart';

const _items = <NavItem>[
  (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
  (
    icon: Icons.credit_card_outlined,
    activeIcon: Icons.credit_card_rounded,
    label: 'Cards'
  ),
  (
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profile'
  ),
];

Widget host(int index, {bool dark = false}) => MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      home: Scaffold(
        extendBody: true,
        body: const SizedBox.expand(),
        bottomNavigationBar: StrataNavBar(
          items: _items,
          index: index,
          onChanged: (_) {},
        ),
      ),
    );

/// Gap between the bar's edge and the pill's, on each side.
({double left, double top, double right, double bottom}) gaps(
    WidgetTester tester) {
  final bar = tester.getRect(find.byKey(StrataNavBar.barKey));
  final pill = tester.getRect(find.byKey(StrataNavBar.pillKey));
  return (
    left: pill.left - bar.left,
    top: pill.top - bar.top,
    right: bar.right - pill.right,
    bottom: bar.bottom - pill.bottom,
  );
}

void main() {
  testWidgets('the first pill is inset equally on every side it touches',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(host(0));
    await tester.pumpAndSettle();

    final g = gaps(tester);
    // Left, top and bottom are the three sides the first pill shares with
    // the bar. They have to be the same number, or the ring of bar around
    // the pill's end cap is thin above and fat beside — which is what a
    // "wrong radius" on a pair of stadiums actually is.
    expect(g.left, moreOrLessEquals(g.top, epsilon: 0.01));
    expect(g.left, moreOrLessEquals(g.bottom, epsilon: 0.01));
  });

  testWidgets('the last pill is inset equally on its own three sides',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(host(2));
    await tester.pumpAndSettle();

    final g = gaps(tester);
    expect(g.right, moreOrLessEquals(g.top, epsilon: 0.01));
    expect(g.right, moreOrLessEquals(g.bottom, epsilon: 0.01));
  });

  testWidgets('bar and pill are concentric stadiums', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(host(0));
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byKey(StrataNavBar.barKey));
    final pill = tester.getRect(find.byKey(StrataNavBar.pillKey));
    final g = gaps(tester);

    // Each shape is fully rounded, so its radius is half its own height.
    // Concentric end caps mean the radii differ by exactly the inset.
    expect(bar.height / 2 - pill.height / 2,
        moreOrLessEquals(g.top, epsilon: 0.01));
  });

  testWidgets('the pill covers its whole slot', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(host(1));
    await tester.pumpAndSettle();

    final bar = tester.getRect(find.byKey(StrataNavBar.barKey));
    final pill = tester.getRect(find.byKey(StrataNavBar.pillKey));
    final track = bar.width - 2 * (pill.top - bar.top);

    expect(pill.width, moreOrLessEquals(track / _items.length, epsilon: 0.01));
  });

  testWidgets('the gaps hold in dark mode too', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(host(0, dark: true));
    await tester.pumpAndSettle();

    final g = gaps(tester);
    expect(g.left, moreOrLessEquals(g.top, epsilon: 0.01));
    expect(g.left, moreOrLessEquals(g.bottom, epsilon: 0.01));
  });

  testWidgets('only the selected destination is labelled', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(host(1));
    await tester.pumpAndSettle();

    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Profile'), findsNothing);
  });
}
