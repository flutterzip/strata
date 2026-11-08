import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:strata/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a card can be added end to end', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StrataApp()));
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

    // Back on the shell, the new card should be in the wallet.
    await tester.tap(find.text('Cards').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('4242'), findsWidgets,
        reason: 'the added card should now be in the carousel');
  });
}
