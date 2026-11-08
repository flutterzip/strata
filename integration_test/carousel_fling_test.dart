import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:strata/app.dart';
import 'package:strata/models/auth_models.dart';
import 'package:strata/services/auth_repository.dart';
import 'package:strata/screens/cards/widgets/card_carousel.dart';
import 'package:strata/shared/widgets/strata_nav_bar.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Run frames against the real vsync.
  //
  // This matters more than anything else in the file. By default the
  // binding pumps frames as fast as it can, so a spring that takes 300ms on
  // a phone is drawn in a handful of frames as quickly as the machine can
  // produce them. A screen recording of that measures the test harness, not
  // the motion — which is how the carousel appeared to decay three times
  // faster than it does.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUp(() {
    // Start past the auth gate. On a fresh install the app opens on the
    // intro, so without this the run never reaches a carousel to fling —
    // and the failure is an unhelpful "Bad state: No element" from the tab
    // finder rather than anything about motion.
    SharedPreferences.setMockInitialValues({
      DemoAuthRepository.stageKey: AuthStage.signedIn.name,
    });
  });

  testWidgets('fling the carousel for motion capture', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StrataApp()));
    await tester.pumpAndSettle();

    // Past the auth gate and onto the shell. If this fails the seeded
    // stage did not take, and nothing below is about motion.
    expect(find.byType(StrataNavBar), findsOneWidget,
        reason: 'the app should open on the shell, not the intro');

    // Into the Cards tab, by icon. The nav bar labels only the *active*
    // destination, so `find.text('Cards')` matches nothing until you are
    // already there.
    await tester.tap(find.byIcon(Icons.credit_card_outlined));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));

    final carousel = find.byType(CardCarousel);
    expect(carousel, findsOneWidget);

    // Three successive flings, matching the three swipes measured in the
    // reference clip, with a pause between so each settle is isolated.
    for (var i = 0; i < 3; i++) {
      await tester.fling(carousel, const Offset(-320, 0), 1400);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));
    }

    // Settle back the other way.
    await tester.fling(carousel, const Offset(320, 0), 1400);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 800));
  });
}
