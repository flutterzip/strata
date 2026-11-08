import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/app.dart';
import 'package:strata/config/app_timing.dart';
import 'package:strata/screens/auth/sign_in_screen.dart';
import 'package:strata/screens/splash/splash_gate.dart';
import 'package:strata/services/demo_data.dart';
import 'package:strata/shared/widgets/demo_panel.dart';

import '../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(
        fullAppPrefs(authStage: 'signedOut'));
    DemoData.clearCache();
  });

  Future<void> frames(WidgetTester tester, Duration total) async {
    const frame = Duration(milliseconds: 50);
    for (var t = Duration.zero; t < total; t += frame) {
      await tester.pump(frame);
    }
  }

  testWidgets('covers the first screen, then hands over to it and leaves',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(const ProviderScope(child: StrataApp()));
    await tester.pump();

    // Up, and the first screen is not built yet — so its own entrance
    // plays when the splash dissolves rather than finishing unseen.
    expect(find.byKey(SplashGate.viewKey), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
    expect(SplashGate.showing.value, isTrue);

    // Halfway through the intro it is still up.
    await frames(tester, AppTiming.splashIntro * 0.5);
    expect(find.byKey(SplashGate.viewKey), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);

    await pumpPastSplash(tester);
    expect(find.byKey(SplashGate.viewKey), findsNothing);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(SplashGate.showing.value, isFalse);
  });

  testWidgets('the first screen is built once, not again when the splash goes',
      (tester) async {
    // Regression: the gate used to return its child bare once the splash
    // had gone, which moved it in the tree and rebuilt the first screen
    // from scratch — its entrance played twice, a flash after the splash.
    usePhoneSurface(tester);
    await tester.pumpWidget(const ProviderScope(child: StrataApp()));

    // Pump until the first screen is mounted under the dissolving splash.
    const frame = Duration(milliseconds: 50);
    var waited = Duration.zero;
    while (find.byType(SignInScreen).evaluate().isEmpty &&
        waited < AppTiming.splashTotal) {
      await tester.pump(frame);
      waited += frame;
    }
    expect(find.byKey(SplashGate.viewKey), findsOneWidget,
        reason: 'the splash is still dissolving over it');
    final during = tester.state(find.byType(SignInScreen));

    await pumpPastSplash(tester);
    expect(find.byKey(SplashGate.viewKey), findsNothing);
    expect(identical(tester.state(find.byType(SignInScreen)), during), isTrue,
        reason: 'same State object: the screen was kept, not rebuilt');
  });

  testWidgets('the demo control stays hidden until the splash has gone',
      (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(const ProviderScope(child: StrataApp()));
    await tester.pump(const Duration(milliseconds: 300));

    double opacityOfControl() => tester
        .widget<AnimatedOpacity>(find.byKey(DemoPanelButton.fadeKey))
        .opacity;

    expect(opacityOfControl(), 0);
    await pumpPastSplash(tester);
    expect(opacityOfControl(), 1);
  });

  testWidgets('reduce-motion gets a still logo and is over sooner',
      (tester) async {
    usePhoneSurface(tester);
    disableAnimationsForTest(tester);
    await tester.pumpWidget(const ProviderScope(child: StrataApp()));
    await tester.pump();
    expect(find.byKey(SplashGate.viewKey), findsOneWidget);

    await frames(
      tester,
      AppTiming.splashStill +
          AppTiming.splashHold +
          const Duration(milliseconds: 900),
    );
    expect(find.byKey(SplashGate.viewKey), findsNothing);
    expect(find.byType(SignInScreen), findsOneWidget);
  });
}
