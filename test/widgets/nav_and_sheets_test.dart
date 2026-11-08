import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strata/shared/widgets/strata_nav_bar.dart';
import 'package:strata/shared/widgets/strata_sheet.dart';

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

void main() {
  group('StrataNavBar', () {
    testWidgets('labels only the active destination', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(harness(
        Scaffold(
          bottomNavigationBar:
              StrataNavBar(items: _items, index: 0, onChanged: (_) {}),
        ),
      ));
      await tester.pumpAndSettle();

      // The quiet bar: one label, not three.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Cards'), findsNothing);
      expect(find.text('Profile'), findsNothing);
    });

    testWidgets('reports the tapped destination', (tester) async {
      usePhoneSurface(tester);
      var selected = -1;
      await tester.pumpWidget(harness(
        Scaffold(
          bottomNavigationBar: StrataNavBar(
            items: _items,
            index: 0,
            onChanged: (i) => selected = i,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Profile'));
      expect(selected, 2);
    });

    testWidgets('tapping the current destination does not re-fire',
        (tester) async {
      usePhoneSurface(tester);
      var calls = 0;
      await tester.pumpWidget(harness(
        Scaffold(
          bottomNavigationBar: StrataNavBar(
            items: _items,
            index: 1,
            onChanged: (_) => calls++,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Cards'));
      expect(calls, 0);
    });

    testWidgets('marks the active destination for a screen reader',
        (tester) async {
      usePhoneSurface(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(harness(
        Scaffold(
          bottomNavigationBar:
              StrataNavBar(items: _items, index: 1, onChanged: (_) {}),
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('Cards')),
        containsSemantics(
          label: 'Cards',
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      handle.dispose();
    });
  });

  group('confirmAction', () {
    testWidgets('returns true only on explicit confirmation', (tester) async {
      usePhoneSurface(tester);
      bool? result;

      await tester.pumpWidget(harness(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await confirmAction(
                    context,
                    title: 'Remove this card?',
                    message: 'You can add it again later.',
                    confirmLabel: 'Remove card',
                    destructive: true,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The destructive action is named, never "OK".
      expect(find.text('Remove card'), findsOneWidget);
      expect(find.text('OK'), findsNothing);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove card'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });
}
