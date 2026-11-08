import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/app.dart';
import 'package:strata/models/auth_models.dart';
import 'package:strata/services/auth_repository.dart';
import 'package:strata/shared/widgets/strata_nav_bar.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Start past the auth gate. A fresh install opens on the intro, so
    // without this there is no Home screen and no "Add" action to tap.
    SharedPreferences.setMockInitialValues({
      DemoAuthRepository.stageKey: AuthStage.signedIn.name,
    });
  });

  testWidgets('a card can be added end to end', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StrataApp()));
    // The splash waits on timers, not frames, so pumpAndSettle can return
    // while it is still showing. Pump real frames until the shell is up.
    final shell = find.byType(StrataNavBar);
    for (var i = 0; i < 100 && shell.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(shell, findsOneWidget, reason: 'the app should open on the shell');
    await tester.pumpAndSettle();

    // Home -> Add
    await tester.tap(find.text('Add').first);
    await tester.pumpAndSettle();
    expect(find.text('Add card'), findsWidgets, reason: 'form should open');

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Card number'), '4242424242424242');
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Expiry'), '1230');
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Security code'), '123');
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name on card'), 'Ada Lovelace');
    await tester.pumpAndSettle();

    final cta = find.widgetWithText(FilledButton, 'Add card');
    expect(tester.widget<FilledButton>(cta).onPressed, isNotNull,
        reason: 'CTA must enable once every field is valid');

    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(find.text('Card added'), findsOneWidget,
        reason: 'confirmation should appear');

    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    // Back on the shell, the new card should be in the wallet. The nav bar
    // labels only the active destination, so the Cards tab is found by icon.
    await tester.tap(find.byIcon(Icons.credit_card_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('4242'), findsWidgets,
        reason: 'the added card should now be in the carousel');
  });
}
