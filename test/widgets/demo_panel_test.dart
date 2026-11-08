import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/app.dart';
import 'package:strata/shared/widgets/demo_panel.dart';
import 'package:strata/providers/profile_providers.dart';
import 'package:strata/services/demo_data.dart';

import '../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Every store pre-seeded: an asset-seeded store makes the second test
    // in a file hang on a bundle load that never completes.
    SharedPreferences.setMockInitialValues(fullAppPrefs());
    DemoData.clearCache();
  });

  /// Opens the panel and hands back the scope behind it.
  ///
  /// Animations are deliberately **not** disabled here. Turning them off
  /// freezes the modal route's entrance at zero, which leaves the whole
  /// sheet sitting below the bottom of the screen: its widgets exist, so a
  /// `findsOneWidget` assertion passes, but every control is off-screen and
  /// a tap on one silently misses. `pumpAndSettle` is still avoided — the
  /// app has ambient animations it would wait on forever — so the frames
  /// are pumped by hand instead.
  Future<ProviderContainer> openPanel(WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(const ProviderScope(child: StrataApp()));
    await pumpPastSplash(tester);

    // Found by icon, not by semantics label: a label propagates up through
    // merged semantics, so `find.bySemanticsLabel` can match a full-screen
    // ancestor and a tap on it lands in the middle of the page.
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    return ProviderScope.containerOf(tester.element(find.byType(StrataApp)));
  }

  /// Lets an async write through to storage and back into the UI.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the floating control opens its sheet, fully on screen',
      (tester) async {
    await openPanel(tester);

    // Regression guard: the panel lives in MaterialApp.builder, above the
    // Navigator. Using that context for showModalBottomSheet throws and the
    // button silently does nothing, which is exactly what shipped once.
    expect(find.text('Demo settings'), findsWidgets);
    expect(find.text('Demo hints'), findsOneWidget);
    expect(find.text('Reset demo data'), findsOneWidget);

    // On screen, not merely mounted. Existence is not reachability.
    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    for (final label in ['Demo settings', 'Demo hints', 'Reset demo data']) {
      final rect = tester.getRect(find.text(label).first);
      expect(rect.bottom, lessThanOrEqualTo(screen), reason: label);
      expect(rect.top, greaterThanOrEqualTo(0), reason: label);
    }
  });

  testWidgets('the theme switch changes the mode and holds it', (tester) async {
    final container = await openPanel(tester);
    expect(container.read(themeModeProvider), ThemeMode.system);

    await tester.tap(find.text('Dark'));
    await settle(tester);
    expect(container.read(themeModeProvider), ThemeMode.dark);

    await tester.tap(find.text('Light'));
    await settle(tester);
    expect(container.read(themeModeProvider), ThemeMode.light);

    await tester.tap(find.text('Auto'));
    await settle(tester);
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  testWidgets('the theme switch is stored, not just held in the widget',
      (tester) async {
    // It is read back from the profile on the next launch, so it has to
    // reach storage and not merely the notifier.
    final container = await openPanel(tester);
    await tester.tap(find.text('Dark'));
    await settle(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getString('strata.profile.v1'), contains('"themeMode":"dark"'));
    expect(container.read(profileProvider).value!.themeMode, ThemeMode.dark);
  });

  testWidgets('the hint toggle flips, and says which state it is in',
      (tester) async {
    final container = await openPanel(tester);
    expect(container.read(showDemoHintsProvider), isTrue);
    expect(
        find.textContaining('Showing prefilled credentials'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await settle(tester);

    expect(container.read(showDemoHintsProvider), isFalse);
    // The subtitle carries the state, not just the switch position.
    expect(find.textContaining('are hidden'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(container.read(showDemoHintsProvider), isTrue);
  });

  testWidgets('tapping the hint row works as well as the switch',
      (tester) async {
    // A row with a switch on it should respond to the whole row; aiming at
    // a 40dp control when the label is right there is a needless chore.
    final container = await openPanel(tester);
    await tester.tap(find.text('Demo hints'));
    await settle(tester);
    expect(container.read(showDemoHintsProvider), isFalse);
  });

  testWidgets('reset asks before discarding anything', (tester) async {
    await openPanel(tester);
    await tester.tap(find.text('Reset demo data'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.textContaining('Reset'), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('the floating button steps aside while its sheet is open',
      (tester) async {
    double fade() => tester
        .widget<AnimatedOpacity>(find.byKey(DemoPanelButton.fadeKey))
        .opacity;

    await openPanel(tester);
    expect(fade(), 0, reason: 'it would sit on top of the sheet');

    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(fade(), 1);
  });
}
