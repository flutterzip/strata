import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strata/config/palette.dart';
import 'package:strata/models/card_brand.dart';
import 'package:strata/shared/widgets/card_face.dart';

import '../support/harness.dart';

void main() {
  testWidgets('renders the stored card details', (tester) async {
    await tester.pumpWidget(harness(Center(child: CardFace.of(sampleCard))));
    await tester.pumpAndSettle();

    expect(find.text('•••• •••• •••• 4242'), findsOneWidget);
    expect(find.text('ADA LOVELACE'), findsOneWidget);
    expect(find.text('12/34'), findsOneWidget);
    expect(find.text('VISA'), findsOneWidget);
    expect(find.text('Credit'), findsOneWidget);
  });

  testWidgets('shows placeholders before anything is typed', (tester) async {
    await tester.pumpWidget(
      harness(const Center(child: CardFace(skin: CardSkin.forest))),
    );
    await tester.pumpAndSettle();

    expect(find.text('•••• •••• •••• ••••'), findsOneWidget);
    expect(find.text('YOUR NAME'), findsOneWidget);
    expect(find.text('MM/YY'), findsOneWidget);
  });

  testWidgets('hides the network until one is detected', (tester) async {
    await tester.pumpWidget(
      harness(const Center(
          child: CardFace(skin: CardSkin.sage, brand: CardBrand.unknown))),
    );
    await tester.pumpAndSettle();
    expect(find.text('CARD'), findsNothing);
  });

  testWidgets('keeps a physical card aspect ratio', (tester) async {
    await tester.pumpWidget(harness(Center(child: CardFace.of(sampleCard))));
    await tester.pumpAndSettle();

    final box = tester.getSize(find.byType(CardFace));
    expect(box.width / box.height, closeTo(1.586, 0.01));
  });
}
