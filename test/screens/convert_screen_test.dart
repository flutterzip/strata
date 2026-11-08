import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/config/palette.dart';
import 'package:strata/models/card_brand.dart';
import 'package:strata/models/payment_card.dart';
import 'package:strata/models/transaction.dart';
import 'package:strata/providers/notification_providers.dart';
import 'package:strata/providers/transaction_providers.dart';
import 'package:strata/providers/wallet_providers.dart';
import 'package:strata/screens/convert/convert_screen.dart';
import 'package:strata/screens/convert/widgets/swap_panels.dart';
import 'package:strata/shared/widgets/status_view.dart';

import '../support/harness.dart';

const usd = PaymentCard(
  id: 'c_forest',
  last4: '8152',
  brand: CardBrand.mastercard,
  funding: CardFunding.debit,
  holder: 'OLYMPICSON',
  expiryMonth: 7,
  expiryYear: 2029,
  skin: CardSkin.forest,
  balanceMinor: 100000,
  currency: 'USD',
  nickname: 'Everyday',
);

const eur = PaymentCard(
  id: 'c_moss',
  last4: '4410',
  brand: CardBrand.visa,
  funding: CardFunding.virtualDebit,
  holder: 'OLYMPICSON',
  expiryMonth: 11,
  expiryYear: 2028,
  skin: CardSkin.moss,
  balanceMinor: 20000,
  currency: 'EUR',
  nickname: 'Travel',
);

const usd2 = PaymentCard(
  id: 'c_sage',
  last4: '7731',
  brand: CardBrand.visa,
  funding: CardFunding.credit,
  holder: 'OLYMPICSON',
  expiryMonth: 3,
  expiryYear: 2030,
  skin: CardSkin.sage,
  balanceMinor: 5000,
  currency: 'USD',
  nickname: 'Household',
);

void seedPrefs() => SharedPreferences.setMockInitialValues({
      'strata.notifications.v1': jsonEncode(const <Map<String, Object>>[]),
    });

Future<void> type(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    final key = find.text(d);
    expect(key, findsOneWidget, reason: 'keypad key "$d"');
    await tester.tap(key);
    await tester.pump();
  }
}

Future<ProviderContainer> scopeOf(WidgetTester tester) async {
  final container =
      ProviderScope.containerOf(tester.element(find.byType(ConvertScreen)));
  await container.read(walletProvider.future);
  await container.read(transactionsProvider.future);
  await container.read(notificationsProvider.future);
  return container;
}

PaymentCard cardIn(ProviderContainer c, String id) =>
    c.read(walletProvider).value!.firstWhere((x) => x.id == id);

void main() {
  setUp(seedPrefs);

  Widget convertHarness({List<PaymentCard> cards = const [usd, eur, usd2]}) =>
      harness(const ConvertScreen(), cards: cards, transactions: const []);

  testWidgets('opens with two different cards and the breakdown visible',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(convertHarness());
    await tester.pumpAndSettle();

    expect(find.byType(SwapPanels), findsOneWidget);
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    // Never the same card on both sides on arrival.
    expect(find.textContaining('Everyday'), findsWidgets);
    expect(find.textContaining('Travel'), findsWidgets);

    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Rate'), findsOneWidget);
    expect(find.text('You get'), findsOneWidget);
    expect(find.textContaining('1 USD = 0.9172 EUR'), findsOneWidget);
  });

  testWidgets('says the rates are indicative, with the date', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(convertHarness());
    await tester.pumpAndSettle();

    // Presenting a static table as a live rate would be a lie about
    // something people make decisions with.
    expect(find.textContaining('indicative'), findsOneWidget);
    expect(find.textContaining('7 November 2026'), findsOneWidget);
  });

  testWidgets('typing an amount updates the converted figure live',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(convertHarness());
    await tester.pumpAndSettle();

    await type(tester, '20000');
    await tester.pumpAndSettle();

    // $200 less 0.5% = $199, times 0.9172 = €182.52.
    expect(find.text(r'$200.00'), findsWidgets);
    expect(find.text('€182.52'), findsWidgets);
    expect(find.text(r'$1.00'), findsOneWidget, reason: 'the fee');
  });

  testWidgets('swapping exchanges the two sides', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(convertHarness());
    await tester.pumpAndSettle();

    expect(find.textContaining('1 USD = 0.9172 EUR'), findsOneWidget);

    await tester.tap(find.byKey(ConvertScreen.swapKey));
    await tester.pumpAndSettle();

    // The rate is now quoted the other way round.
    expect(find.textContaining('1 EUR = '), findsOneWidget);
    expect(find.textContaining('1 USD = '), findsNothing);
  });

  testWidgets('the swap animation settles rather than running forever',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(convertHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ConvertScreen.swapKey));
    // pumpAndSettle would hang on an ambient loop; reaching the assertion
    // is the check.
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('same-currency cards are handled, with no fee', (tester) async {
    usePhoneSurface(tester);
    // Only two cards, both USD, so the screen opens on that pair.
    await tester.pumpWidget(convertHarness(cards: const [usd, usd2]));
    await tester.pumpAndSettle();

    await type(tester, '20000');
    await tester.pumpAndSettle();

    expect(find.text('No fee, same currency'), findsOneWidget);
    expect(find.text('Rate'), findsNothing);
    // One in, one out, same figure.
    expect(find.text(r'$200.00'), findsWidgets);
  });

  testWidgets('too much explains why and does not convert', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(convertHarness());
    await tester.pumpAndSettle();
    final container = await scopeOf(tester);

    await type(tester, '500000');
    await tester.pumpAndSettle();

    expect(find.textContaining('more than the'), findsOneWidget);
    expect(find.textContaining(r'$1,000.00'), findsWidgets);

    await tester.tap(find.byKey(ConvertScreen.confirmKey));
    await tester.pumpAndSettle();

    expect(container.read(transactionsProvider).value, isEmpty);
    expect(cardIn(container, 'c_forest').balanceMinor, 100000);
  });

  testWidgets('converting debits one card, credits the other and records both',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(convertHarness());
    await tester.pumpAndSettle();
    final container = await scopeOf(tester);

    await type(tester, '20000');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ConvertScreen.confirmKey));
    await tester.pumpAndSettle();

    expect(find.byKey(ConvertScreen.doneKey), findsOneWidget);

    expect(cardIn(container, 'c_forest').balanceMinor, 80000);
    expect(cardIn(container, 'c_moss').balanceMinor, 20000 + 18252);

    final txns = container.read(transactionsProvider).value!;
    expect(txns, hasLength(2));
    expect(txns.every((t) => t.kind == TxnKind.conversion), isTrue);
    expect(txns.firstWhere((t) => t.cardId == 'c_forest').amountMinor, -20000);
    expect(txns.firstWhere((t) => t.cardId == 'c_moss').amountMinor, 18252);

    expect(container.read(unreadCountProvider), 1);
  });

  testWidgets('the result shows both new balances', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(convertHarness());
    await tester.pumpAndSettle();

    await type(tester, '20000');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ConvertScreen.confirmKey));
    await tester.pumpAndSettle();

    expect(find.text('Everyday now'), findsOneWidget);
    expect(find.text('Travel now'), findsOneWidget);
    expect(find.text(r'$800.00'), findsOneWidget);
    expect(find.text('€382.52'), findsOneWidget);
  });

  testWidgets('convert again resets the amount rather than repeating it',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(convertHarness());
    await tester.pumpAndSettle();
    final container = await scopeOf(tester);

    await type(tester, '1000');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ConvertScreen.confirmKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ConvertScreen.againKey));
    await tester.pumpAndSettle();

    expect(find.byType(SwapPanels), findsOneWidget);
    expect(find.text(r'$0.00'), findsWidgets);
    expect(container.read(transactionsProvider).value, hasLength(2));
  });

  testWidgets('one card is not enough to convert, and says so', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(convertHarness(cards: const [usd]));
    await tester.pumpAndSettle();

    expect(find.byType(StatusView), findsOneWidget);
    expect(find.text('You need two cards'), findsOneWidget);
    expect(find.byType(SwapPanels), findsNothing);
  });

  testWidgets('renders in dark mode without overflowing', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const ConvertScreen(),
      cards: const [usd, eur, usd2],
      transactions: const [],
      dark: true,
    ));
    await tester.pumpAndSettle();
    await type(tester, '12345');
    await tester.pumpAndSettle();

    expect(find.byType(SwapPanels), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
