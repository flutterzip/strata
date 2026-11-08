import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/config/palette.dart';
import 'package:strata/models/card_brand.dart';
import 'package:strata/models/payment_card.dart';
import 'package:strata/models/recipient.dart';
import 'package:strata/models/transaction.dart';
import 'package:strata/providers/notification_providers.dart';
import 'package:strata/providers/recipient_providers.dart';
import 'package:strata/providers/transaction_providers.dart';
import 'package:strata/providers/wallet_providers.dart';
import 'package:strata/screens/send/send_screen.dart';
import 'package:strata/screens/send/widgets/amount_step.dart';
import 'package:strata/screens/send/widgets/recipient_edit_sheet.dart';
import 'package:strata/screens/send/widgets/result_step.dart';
import 'package:strata/screens/send/widgets/review_step.dart';
import 'package:strata/services/recipient_repository.dart';

import '../support/harness.dart';

const akosua = Recipient(
  id: 'r_mensah',
  name: 'Akosua Mensah',
  handle: '@akosua',
  email: 'akosua.mensah@example.com',
  verified: true,
);
const petr = Recipient(
  id: 'r_novak',
  name: 'Petr Novak',
  handle: '@petr',
  email: 'p.novak@example.net',
);

const everyday = PaymentCard(
  id: 'c_forest',
  last4: '8152',
  brand: CardBrand.mastercard,
  funding: CardFunding.debit,
  holder: 'OLYMPICSON',
  expiryMonth: 7,
  expiryYear: 2029,
  skin: CardSkin.forest,
  balanceMinor: 50000,
  currency: 'USD',
  nickname: 'Everyday',
);

void seedPrefs() {
  SharedPreferences.setMockInitialValues({
    'strata.notifications.v1': jsonEncode(const <Map<String, Object>>[]),
    'strata.profile.v1': jsonEncode({
      'name': 'Olympicson',
      'email': 'hello@flutterzip.com',
      'handle': '@olympicson',
      'avatar': null,
      'themeMode': 'light',
    }),
  });
}

/// Taps the keypad digits in order. The pad has no decimal point: 4-2-5-0
/// means 42.50.
///
/// Taps the key's own `Text`, not a `Semantics` ancestor: tapping the
/// ancestor hits the middle of the page, no warning is printed, and the
/// handler never fires.
Future<void> type(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    final key = find.text(d);
    expect(key, findsOneWidget, reason: 'keypad key "$d"');
    await tester.tap(key);
    await tester.pump();
  }
}

/// The scope behind the screen, with the providers a test inspects already
/// initialised.
///
/// Both halves matter. `ProviderScope.containerOf` finds the scope, and
/// awaiting each `.future` once forces the async providers to build — a
/// plain read of an uninitialised one is `AsyncLoading`, whose value is
/// null. After this, read `.value`: `.future` has already completed with
/// the *initial* list and does not re-resolve when a notifier assigns new
/// state, so reading it later hands back the pre-interaction value.
Future<ProviderContainer> scopeOf(WidgetTester tester) async {
  final container =
      ProviderScope.containerOf(tester.element(find.byType(SendScreen)));
  await container.read(walletProvider.future);
  await container.read(transactionsProvider.future);
  await container.read(recipientsProvider.future);
  await container.read(notificationsProvider.future);
  return container;
}

void main() {
  setUp(seedPrefs);

  Widget sendHarness({
    List<Recipient> recipients = const [akosua, petr],
    List<PaymentCard> cards = const [everyday],
    RecipientRepository? recipientRepository,
  }) =>
      harness(
        const SendScreen(),
        cards: cards,
        recipients: recipients,
        recipientRepository: recipientRepository,
        transactions: const [],
      );

  testWidgets('every card is reachable from the From row, not just the first',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness(cards: [
      everyday,
      cardNamed('c_travel', nickname: 'Travel', last4: '1881'),
      cardNamed('c_house', nickname: 'Household', last4: '9004'),
      cardNamed('c_savings', nickname: 'Savings', last4: '7310'),
      cardNamed('c_spare', nickname: 'Spare', last4: '4455'),
      cardNamed('c_eur', nickname: 'Euro', last4: '6621', currency: 'EUR'),
    ]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akosua Mensah'));
    await tester.pumpAndSettle();

    // The row names the card in force rather than making you find it among
    // pills, half of which used to be off the right edge of the screen.
    expect(find.byKey(AmountStep.fromRow), findsOneWidget);
    expect(find.text('From'), findsOneWidget);

    await tester.tap(find.byKey(AmountStep.fromRow));
    await tester.pumpAndSettle();

    // A sixth card is as reachable as the first, which is the thing the
    // horizontally scrolling strip could not do.
    await tester.scrollUntilVisible(find.text('Euro'), 80,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Euro'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Euro'), findsWidgets);
  });

  testWidgets('a frozen card is named as frozen before it is chosen',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness(cards: [
      everyday,
      cardNamed('c_ice', nickname: 'Iced', last4: '3030', frozen: true),
    ]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akosua Mensah'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AmountStep.fromRow));
    await tester.pumpAndSettle();

    // Named before it is picked, not only after the send is refused.
    expect(find.textContaining('Frozen, cannot send'), findsOneWidget);
  });

  testWidgets('opens on the recipient step, listing who you can send to',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    expect(find.text('Send to'), findsOneWidget);
    expect(find.text('Akosua Mensah'), findsOneWidget);
    expect(find.text('Petr Novak'), findsOneWidget);
  });

  testWidgets('a handle that exists resolves and is confirmed', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(SendScreen.searchKey), '@akosua');
    await tester.pumpAndSettle();

    expect(find.textContaining('Akosua Mensah · @akosua'), findsOneWidget);
  });

  testWidgets('an email that exists resolves too', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(SendScreen.searchKey), 'akosua.mensah@example.com');
    await tester.pumpAndSettle();

    expect(find.textContaining('Akosua Mensah · @akosua'), findsOneWidget);
  });

  testWidgets('a handle that exists but is unconfirmed says so',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(SendScreen.searchKey), '@petr');
    await tester.pumpAndSettle();

    expect(find.textContaining('has not been confirmed'), findsOneWidget);
  });

  testWidgets('a handle that matches nobody is reported, not invented',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(SendScreen.searchKey), '@nobody');
    await tester.pumpAndSettle();

    expect(find.textContaining('No one matches that handle or email'),
        findsOneWidget);

    // And continuing does not invent a payee from the text.
    await tester.tap(find.byKey(SendScreen.continueKey));
    await tester.pumpAndSettle();
    expect(find.text('Send to'), findsOneWidget);
  });

  testWidgets('your own handle is recognised as you', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(SendScreen.searchKey), '@olympicson');
    await tester.pumpAndSettle();
    expect(find.textContaining('your own account'), findsOneWidget);

    await tester.enterText(
        find.byKey(SendScreen.searchKey), 'hello@flutterzip.com');
    await tester.pumpAndSettle();
    expect(find.textContaining('your own account'), findsOneWidget);
  });

  testWidgets('choosing someone moves to the amount step', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Akosua Mensah'));
    await tester.pumpAndSettle();

    expect(find.text('How much'), findsOneWidget);
    expect(find.text('To Akosua Mensah'), findsOneWidget);
    expect(find.textContaining(r'$500.00 available'), findsOneWidget);
  });

  testWidgets('the keypad enters minor units and shows the balance after',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akosua Mensah'));
    await tester.pumpAndSettle();

    await type(tester, '4250');
    await tester.pumpAndSettle();

    expect(find.text(r'$42.50'), findsOneWidget);
    expect(find.textContaining(r'$457.50 left after'), findsOneWidget);
  });

  testWidgets('too much explains why, with both numbers, and does not proceed',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akosua Mensah'));
    await tester.pumpAndSettle();

    await type(tester, '600000');
    await tester.pumpAndSettle();

    expect(find.textContaining('more than the'), findsWidgets);
    expect(find.textContaining(r'$500.00'), findsWidgets);
    expect(find.textContaining('Everyday'), findsWidgets);

    await tester.tap(find.byKey(SendScreen.continueKey));
    await tester.pumpAndSettle();
    // Still on the amount step: the button explained itself rather than
    // going dead or going through.
    expect(find.text('How much'), findsOneWidget);
  });

  testWidgets('a full send moves money, records it and notifies',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    final container = await scopeOf(tester);

    await tester.tap(find.text('Akosua Mensah'));
    await tester.pumpAndSettle();
    await type(tester, '12500');
    await tester.tap(find.byKey(SendScreen.continueKey));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewStep), findsOneWidget);
    expect(find.text('No fee'), findsOneWidget);
    expect(find.text(r'$375.00'), findsOneWidget, reason: 'balance after');

    await tester.enterText(find.byKey(SendScreen.noteKey), 'half the deposit');
    await tester.tap(find.byKey(SendScreen.confirmKey));
    await tester.pumpAndSettle();

    expect(find.byType(ResultStep), findsOneWidget);
    expect(find.textContaining('sent to Akosua Mensah'), findsOneWidget);
    expect(find.text(r'$375.00'), findsOneWidget, reason: 'new balance');

    expect(container.read(walletProvider).value!.single.balanceMinor, 37500);

    final txn = container.read(transactionsProvider).value!.single;
    expect(txn.kind, TxnKind.transfer);
    expect(txn.amountMinor, -12500);
    expect(txn.merchant, 'To Akosua Mensah');
    expect(txn.note, 'half the deposit');

    expect(container.read(unreadCountProvider), 1);
    expect(
      container
          .read(recipientsProvider)
          .value!
          .firstWhere((r) => r.id == 'r_mensah')
          .lastUsedAt,
      isNotNull,
    );
  });

  testWidgets('the review step flags an unconfirmed recipient before sending',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Petr Novak'));
    await tester.pumpAndSettle();
    await type(tester, '500');
    await tester.tap(find.byKey(SendScreen.continueKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('has not been confirmed'), findsOneWidget);
    // Still sendable — flagged, not blocked.
    expect(find.byKey(SendScreen.confirmKey), findsOneWidget);
  });

  testWidgets('backing out at each step writes nothing', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Akosua Mensah'));
    await tester.pumpAndSettle();
    await type(tester, '1000');
    await tester.tap(find.byKey(SendScreen.continueKey));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewStep), findsOneWidget);

    // Review -> amount -> recipient, all the way back out.
    await tester.tap(find.byKey(SendScreen.backKey));
    await tester.pumpAndSettle();
    expect(find.text('How much'), findsOneWidget);

    await tester.tap(find.byKey(SendScreen.backKey));
    await tester.pumpAndSettle();
    expect(find.text('Send to'), findsOneWidget);

    final container = await scopeOf(tester);
    expect(container.read(transactionsProvider).value, isEmpty);
    expect(container.read(walletProvider).value!.single.balanceMinor, 50000);
    expect(container.read(notificationsProvider).value, isEmpty);
  });

  testWidgets('send another resets the flow rather than repeating the send',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    final container = await scopeOf(tester);

    await tester.tap(find.text('Akosua Mensah'));
    await tester.pumpAndSettle();
    await type(tester, '1000');
    await tester.tap(find.byKey(SendScreen.continueKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SendScreen.confirmKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(SendScreen.againKey));
    await tester.pumpAndSettle();

    expect(find.text('Send to'), findsOneWidget);
    expect(container.read(transactionsProvider).value, hasLength(1));
  });

  testWidgets('a recipient can be added, and is flagged as unconfirmed',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(RecipientKeys.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(RecipientKeys.name), 'Dayo Adeyemi');
    await tester.enterText(find.byKey(RecipientKeys.handle), '@dayo');
    await tester.enterText(find.byKey(RecipientKeys.email), 'dayo@example.com');
    await tester.tap(find.byKey(RecipientKeys.save));
    await tester.pumpAndSettle();

    expect(find.text('Dayo Adeyemi'), findsOneWidget);

    await tester.enterText(find.byKey(SendScreen.searchKey), '@dayo');
    await tester.pumpAndSettle();
    expect(find.textContaining('has not been confirmed'), findsOneWidget);
  });

  testWidgets('a duplicate handle is refused with the name that holds it',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(RecipientKeys.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(RecipientKeys.name), 'Someone Else');
    await tester.enterText(find.byKey(RecipientKeys.handle), '@akosua');
    await tester.enterText(find.byKey(RecipientKeys.email), 'else@example.com');
    await tester.tap(find.byKey(RecipientKeys.save));
    await tester.pumpAndSettle();

    expect(
        find.text('Akosua Mensah already uses that handle.'), findsOneWidget);
  });

  testWidgets('your own email cannot be added as a recipient', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(RecipientKeys.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(RecipientKeys.name), 'Me');
    await tester.enterText(find.byKey(RecipientKeys.handle), '@me');
    await tester.enterText(
        find.byKey(RecipientKeys.email), 'hello@flutterzip.com');
    await tester.tap(find.byKey(RecipientKeys.save));
    await tester.pumpAndSettle();

    expect(find.textContaining('your own account'), findsOneWidget);
  });

  testWidgets('an empty form names the first missing field', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(RecipientKeys.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(RecipientKeys.save));
    await tester.pumpAndSettle();

    expect(find.text('Enter their name.'), findsOneWidget);
  });

  testWidgets('with no recipients at all the step offers to add one',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(sendHarness(recipients: const []));
    await tester.pumpAndSettle();

    expect(find.text('No recipients yet'), findsOneWidget);
    expect(find.text('Add a recipient'), findsWidgets);
  });

  testWidgets('the flow renders in dark mode without overflowing',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const SendScreen(),
      cards: const [everyday],
      recipients: const [akosua, petr],
      transactions: const [],
      dark: true,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Akosua Mensah'));
    await tester.pumpAndSettle();
    await type(tester, '2500');
    await tester.tap(find.byKey(SendScreen.continueKey));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewStep), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
