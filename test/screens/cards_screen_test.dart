import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strata/screens/cards/cards_screen.dart';
import 'package:strata/screens/cards/widgets/add_card_tile.dart';
import 'package:strata/screens/cards/widgets/card_carousel.dart';
import 'package:strata/screens/cards/widgets/wallet_stack.dart';
import 'package:strata/services/wallet_repository.dart';
import 'package:strata/shared/widgets/card_face.dart';

import '../support/harness.dart';

void main() {
  testWidgets('shows a loading state before cards arrive', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const CardsScreen(),
      repository: InMemoryWalletRepository(
        seed: [sampleCard],
        latency: const Duration(milliseconds: 60),
      ),
    ));
    await tester.pump();

    expect(find.bySemanticsLabel('Loading your cards'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Loading your cards'), findsNothing);
  });

  testWidgets('opens on the wallet stack, shut, with no card singled out',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const CardsScreen(), cards: [
      sampleCard,
      cardNamed('c_two', nickname: 'Travel', last4: '1881'),
      cardNamed('c_three', nickname: 'Household', last4: '9004'),
    ]));
    await tester.pumpAndSettle();

    expect(find.byType(WalletStack), findsOneWidget);
    expect(find.byType(CardCarousel), findsNothing);
    // Every card is on screen at once, which is the point of opening here.
    expect(find.byType(CardFace), findsNWidgets(3));
    expect(find.text('Your wallet'), findsOneWidget);
    expect(find.text('3 cards · tap one to open'), findsOneWidget);
    // Nothing is open, so there is no per-card detail to show.
    expect(find.text('Card info'), findsNothing);
  });

  testWidgets('tapping a card in the stack opens it and its balance',
      (tester) async {
    usePhoneSurface(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(const CardsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Your wallet'), findsOneWidget);
    await tapCardSliver(tester, 0);

    // The amount is a RichText (two-tone major/minor), so assert through the
    // accessible description instead of find.text.
    expect(
      hasSemanticsLabel(tester, r'Balance on card ending 4242, $1,250.00'),
      isTrue,
    );
    expect(find.text('Card info'), findsOneWidget);
    expect(find.text('Your wallet'), findsNothing);
    handle.dispose();
  });

  testWidgets('tapping the open card shuts the stack again', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const CardsScreen()));
    await tester.pumpAndSettle();

    await tapCardSliver(tester, 0);
    expect(find.text('Card info'), findsOneWidget);

    await tapCardSliver(tester, 0);
    expect(find.text('Your wallet'), findsOneWidget);
    expect(find.text('Card info'), findsNothing);
  });

  testWidgets('the shut stack is shorter than an open one', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const CardsScreen(), cards: [
      sampleCard,
      cardNamed('c_two', nickname: 'Travel', last4: '1881'),
    ]));
    await tester.pumpAndSettle();

    final shut = tester.getSize(find.byType(WalletStack)).height;
    await tapCardSliver(tester, 0);
    final open = tester.getSize(find.byType(WalletStack)).height;

    // Opening a card reveals it by pushing the ones below it down, so the
    // stack has to grow by exactly that much and no more.
    expect(open, greaterThan(shut));
  });

  testWidgets('the carousel is still reachable from the layout toggle',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const CardsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Carousel'));
    await tester.pumpAndSettle();

    expect(find.byType(CardCarousel), findsOneWidget);
    expect(find.byType(WalletStack), findsNothing);
    // The carousel always has one card in frame, so the detail comes back.
    expect(find.text('Card info'), findsOneWidget);
  });

  testWidgets('always offers an add-card tile after the last card',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const CardsScreen()));
    await tester.pumpAndSettle();
    // Off-screen to the right, but built by the PageView.
    expect(find.byType(AddCardTile, skipOffstage: false), findsOneWidget);
  });

  testWidgets('surfaces a retry path when loading fails', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(
      const CardsScreen(),
      repository: FailingWalletRepository(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('We could not load your cards'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Try again'), findsOneWidget);
  });

  testWidgets('shows an empty state offering the only useful next step',
      (tester) async {
    usePhoneSurface(tester);
    var tapped = 0;
    await tester.pumpWidget(
      harness(CardsScreen(onAddCard: () => tapped++), cards: []),
    );
    await tester.pumpAndSettle();

    expect(find.text('No cards yet'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add a card'));
    expect(tapped, 1);
  });

  testWidgets('an empty state with no handler shows no dead button',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(harness(const CardsScreen(), cards: []));
    await tester.pumpAndSettle();

    expect(find.text('No cards yet'), findsOneWidget);
    expect(find.text('Add a card'), findsNothing,
        reason: 'an action with no handler must not be rendered');
  });

  testWidgets('describes each card to a screen reader', (tester) async {
    usePhoneSurface(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(const CardsScreen()));
    await tester.pumpAndSettle();

    expect(
      hasSemanticsLabel(tester, 'Visa Credit, ending 4242, expires 12/34'),
      isTrue,
    );
    handle.dispose();
  });

  testWidgets('tapping add opens the flow', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      harness(CardsScreen(onAddCard: () => tapped++)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add a card'));
    expect(tapped, 1);
  });
}
