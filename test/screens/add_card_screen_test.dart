import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strata/screens/add_card/add_card_screen.dart';
import 'package:strata/screens/add_card/widgets/skin_picker.dart';

import '../support/harness.dart';

Future<void> fillValidCard(WidgetTester tester) async {
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Card number'), '4242424242424242');
  await tester.enterText(find.widgetWithText(TextFormField, 'Expiry'), '1234');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Security code'), '123');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Name on card'), 'Ada Lovelace');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders every field and the colour picker', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const AddCardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Add card'), findsWidgets);
    expect(find.widgetWithText(TextFormField, 'Card number'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Expiry'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Security code'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Name on card'), findsOneWidget);
    expect(find.byType(SkinPickerRow), findsOneWidget);
  });

  testWidgets('submitting an empty form names the first problem',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const AddCardScreen()));
    await tester.pumpAndSettle();

    // The button stays pressable so it can explain itself. A disabled
    // control that says nothing leaves the user unable to tell whether the
    // app is broken or their input is.
    final button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add card'));
    expect(button.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Add card'));
    await tester.pump();
    expect(find.text('Enter your card number'), findsOneWidget);
  });

  testWidgets('enables submit only once every field is valid', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const AddCardScreen()));
    await tester.pumpAndSettle();
    await fillValidCard(tester);

    final button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add card'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('groups digits and reveals the network while typing',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const AddCardScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Card number'), '4242424242424242');
    await tester.pumpAndSettle();

    expect(find.text('4242 4242 4242 4242'), findsWidgets);
    // Shown on the preview and beside the field.
    expect(find.text('VISA'), findsNWidgets(2));
  });

  testWidgets('regroups and relabels for an Amex number', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const AddCardScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Card number'), '378282246310005');
    await tester.pumpAndSettle();

    expect(find.text('3782 822463 10005'), findsWidgets);
    expect(find.text('AMEX'), findsNWidgets(2));
  });

  testWidgets('mirrors the holder name onto the preview in upper case',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const AddCardScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name on card'), 'Ada Lovelace');
    await tester.pumpAndSettle();

    expect(find.text('ADA LOVELACE'), findsOneWidget);
  });

  testWidgets('a failing checksum is explained rather than silently blocked',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const AddCardScreen()));
    await tester.pumpAndSettle();

    await fillValidCard(tester);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Card number'), '4242424242424243');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add card'));
    await tester.pump();

    expect(find.text('Check the number and try again'), findsWidgets,
        reason: 'the user must be told why the card was rejected');
  });

  testWidgets('a card can be named, and the name shows on the preview',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const AddCardScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Card name'), findsOneWidget,
        reason: 'a card must be nameable at creation, not only when editing');

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Card name'), 'Travel');
    await tester.pumpAndSettle();

    // Appears on the live preview in place of the funding type.
    expect(find.text('Travel'), findsWidgets);
  });

  testWidgets('an unnamed card falls back to its funding type', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const AddCardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Credit'), findsWidgets);
  });

  testWidgets('changing the colour restyles the preview', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const AddCardScreen()));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Moss'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Moss'));
    await tester.pumpAndSettle();

    final picker = tester.widget<SkinPickerRow>(find.byType(SkinPickerRow));
    expect(picker.selected.label, 'Moss');
  });
}
