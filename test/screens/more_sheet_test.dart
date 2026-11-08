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
import 'package:strata/providers/wallet_providers.dart';
import 'package:strata/screens/cards/cards_screen.dart';
import 'package:strata/screens/more/more_sheet.dart';
import 'package:strata/screens/more/widgets/spend_limit_sheet.dart';
import 'package:strata/screens/more/widgets/statements_sheet.dart';
import 'package:strata/screens/more/widgets/support_sheet.dart';
import 'package:strata/screens/send/send_screen.dart';
import 'package:strata/shared/widgets/card_face.dart';

import '../support/harness.dart';

const akosua = Recipient(
  id: 'r_mensah',
  name: 'Akosua Mensah',
  handle: '@akosua',
  email: 'akosua.mensah@example.com',
  verified: true,
);

PaymentCard card({
  String id = 'c_forest',
  String nickname = 'Everyday',
  bool frozen = false,
  int? spendLimitMinor,
  int balanceMinor = 50000,
  String currency = 'USD',
}) =>
    PaymentCard(
      id: id,
      last4: '8152',
      brand: CardBrand.mastercard,
      funding: CardFunding.debit,
      holder: 'OLYMPICSON',
      expiryMonth: 7,
      expiryYear: 2029,
      skin: CardSkin.forest,
      balanceMinor: balanceMinor,
      currency: currency,
      nickname: nickname,
      frozen: frozen,
      spendLimitMinor: spendLimitMinor,
    );

final now = DateTime.now();

Transaction spend(int minor, {String cardId = 'c_forest', int daysAgo = 0}) =>
    Transaction(
      id: 't_${minor}_$cardId$daysAgo',
      cardId: cardId,
      kind: TxnKind.payment,
      merchant: 'Greenmarket',
      category: 'Groceries',
      amountMinor: -minor,
      currency: 'USD',
      // Mid-month and mid-day, so the row cannot fall outside the calendar
      // month the test is asserting about.
      occurredAt: DateTime(now.year, now.month, 15, 12)
          .subtract(Duration(days: daysAgo)),
    );

void seedPrefs() => SharedPreferences.setMockInitialValues({
      'strata.notifications.v1': jsonEncode(const <Map<String, Object>>[]),
    });

Future<void> type(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.text(d));
    await tester.pump();
  }
}

void main() {
  setUp(seedPrefs);

  /// The More sheet, opened over a bare page.
  Widget moreHarness({
    List<PaymentCard> cards = const [],
    List<Transaction> transactions = const [],
  }) =>
      harness(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const MoreSheet(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        cards: cards.isEmpty ? [card()] : cards,
        transactions: transactions,
      );

  Future<void> openMore(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('every row does something — none of them is a dead tile',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(moreHarness());
    await openMore(tester);

    for (final key in [
      MoreKeys.freeze,
      MoreKeys.limits,
      MoreKeys.statements,
      MoreKeys.support,
    ]) {
      expect(find.byKey(key), findsOneWidget, reason: '$key');
    }
    expect(find.text('Freeze card'), findsOneWidget);
  });

  testWidgets('freezing persists and the row flips to unfreeze',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(moreHarness());
    await openMore(tester);

    await tester.tap(find.byKey(MoreKeys.freeze));
    await tester.pumpAndSettle();

    expect(find.text('Unfreeze card'), findsOneWidget);
    expect(find.textContaining('This card is frozen'), findsOneWidget);

    final container =
        ProviderScope.containerOf(tester.element(find.byType(MoreSheet)));
    expect(container.read(walletProvider).value!.single.frozen, isTrue);
  });

  testWidgets('unfreezing asks first, and a refusal leaves it frozen',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(moreHarness(cards: [card(frozen: true)]));
    await openMore(tester);

    await tester.tap(find.byKey(MoreKeys.freeze));
    await tester.pumpAndSettle();
    expect(find.text('Unfreeze this card?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(MoreSheet)));
    expect(container.read(walletProvider).value!.single.frozen, isTrue);
  });

  testWidgets('a frozen card is drawn muted, with the word on it',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const CardsScreen(),
      cards: [card(frozen: true)],
      transactions: const [],
    ));
    await tester.pumpAndSettle();

    // Colour alone is not a state: the word has to be there too.
    expect(find.text('Frozen'), findsWidgets);
    expect(find.text('Active'), findsNothing);
  });

  testWidgets('an active card carries no badge', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const CardsScreen(),
      cards: [card()],
      transactions: const [],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CardFace), findsWidgets);
    expect(find.text('Frozen'), findsNothing);
    // The stack opens shut, so the detail block has to be opened to read it.
    await tapCardSliver(tester, 0);
    expect(find.text('Active'), findsOneWidget, reason: 'in Card info');
  });

  testWidgets('a frozen card blocks Send, with an explanation', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const SendScreen(),
      cards: [card(frozen: true)],
      recipients: const [akosua],
      transactions: const [],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Akosua Mensah'));
    await tester.pumpAndSettle();
    await type(tester, '1000');
    await tester.pumpAndSettle();

    expect(find.textContaining('is frozen'), findsOneWidget);
    expect(find.textContaining('another card'), findsOneWidget);

    await tester.tap(find.byKey(SendScreen.continueKey));
    await tester.pumpAndSettle();

    // Did not get to the review step.
    expect(find.text('How much'), findsOneWidget);
  });

  testWidgets('a spending limit can be set, and shows the month so far',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(moreHarness(
      cards: [card()],
      transactions: [spend(12000)],
    ));
    await openMore(tester);

    await tester.tap(find.byKey(MoreKeys.limits));
    await tester.pumpAndSettle();

    expect(find.textContaining(r'$120.00 spent this month'), findsOneWidget);

    // Through the picker, which is the ordinary path: one control for the
    // value, with the presets inside it.
    await tester.tap(find.byKey(SpendLimitSheet.limitRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'$500.00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SpendLimitSheet.save));
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(MoreSheet)));
    expect(container.read(walletProvider).value!.single.spendLimitMinor, 50000);
    expect(
        find.textContaining(r'$120.00 of $500.00 this month'), findsOneWidget);
  });

  testWidgets('an empty limit says what is missing rather than going dead',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(moreHarness());
    await openMore(tester);

    await tester.tap(find.byKey(MoreKeys.limits));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SpendLimitSheet.save));
    await tester.pumpAndSettle();

    expect(find.textContaining('Enter a monthly limit'), findsOneWidget);
  });

  testWidgets('an existing limit can be removed', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(moreHarness(cards: [card(spendLimitMinor: 50000)]));
    await openMore(tester);

    await tester.tap(find.byKey(MoreKeys.limits));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SpendLimitSheet.remove));
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(MoreSheet)));
    expect(
        container.read(walletProvider).value!.single.spendLimitMinor, isNull);
  });

  testWidgets('a limit blocks a send that would cross it', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const SendScreen(),
      cards: [card(spendLimitMinor: 15000)],
      recipients: const [akosua],
      transactions: [spend(12000)],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Akosua Mensah'));
    await tester.pumpAndSettle();
    await type(tester, '10000');
    await tester.pumpAndSettle();

    expect(find.textContaining('monthly'), findsOneWidget);
    expect(find.textContaining(r'$30.00'), findsWidgets,
        reason: 'what is left');
  });

  testWidgets('statements are built from the activity, newest month first',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(moreHarness(
      cards: [card()],
      transactions: [spend(2000), spend(3000, daysAgo: 40)],
    ));
    await openMore(tester);

    await tester.tap(find.byKey(MoreKeys.statements));
    await tester.pumpAndSettle();

    expect(find.byKey(StatementsSheet.list), findsOneWidget);
    // Two different months, so two rows.
    expect(find.textContaining('entry'), findsWidgets);
  });

  testWidgets('with no activity statements say so rather than showing nothing',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(moreHarness());
    await openMore(tester);

    await tester.tap(find.byKey(MoreKeys.statements));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to report yet'), findsOneWidget);
  });

  testWidgets('support gives a reference and never asks for a full number',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(moreHarness());
    await openMore(tester);

    await tester.tap(find.byKey(MoreKeys.support));
    await tester.pumpAndSettle();

    expect(find.byType(SupportSheet), findsOneWidget);
    expect(find.text('Mastercard •••• 8152'), findsOneWidget);
    expect(find.textContaining('never ask for your full card number'),
        findsOneWidget);
    // And it is honest about being a demo.
    expect(find.textContaining('demo template'), findsOneWidget);
  });

  testWidgets('with no cards at all More says so instead of breaking',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const MoreSheet(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      cards: const [],
      transactions: const [],
    ));
    await openMore(tester);

    expect(find.textContaining('Add a card first'), findsOneWidget);
  });
}
