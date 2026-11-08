import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strata/config/app_theme.dart';
import 'package:strata/models/auth_models.dart';
import 'package:strata/providers/auth_providers.dart';
import 'package:strata/screens/auth/sign_in_screen.dart';
import 'package:strata/screens/auth/sign_up_screen.dart';
import 'package:strata/screens/auth/widgets/social_auth_buttons.dart';
import 'package:strata/services/auth_repository.dart';
import 'package:strata/shared/widgets/busy_button.dart';
import 'package:strata/shared/widgets/strata_mark.dart';

import '../support/harness.dart';

/// Auth repository whose social sign-in waits for the test to release it,
/// so the loading state can be inspected while it is up.
class _HeldAuthRepository implements AuthRepository {
  final calls = <SocialProvider>[];
  // Created on first use, inside the test body: a Completer made in
  // `setUp` belongs to the real zone, and its completion never reaches the
  // fake-async clock the test pumps.
  Completer<void>? _gate;
  Completer<void> get gate => _gate ??= Completer<void>();
  AuthFailure? failWith;

  @override
  Future<void> signInWith(SocialProvider provider) async {
    calls.add(provider);
    await gate.future;
    if (failWith != null) throw failWith!;
  }

  @override
  Future<DemoAccount> demoAccount() async => const DemoAccount(
      email: 'hello@flutterzip.com',
      password: 'strata2026',
      pin: '1234',
      otp: '284917');

  @override
  Future<AuthStage> stage() async => AuthStage.signedOut;
  @override
  Future<void> setStage(AuthStage stage) async {}
  @override
  Future<List<OnboardingSlide>> onboarding() async => const [];
  @override
  Future<void> signIn({required String email, required String password}) =>
      gate.future;
  @override
  Future<void> signUp(
          {required String name,
          required String email,
          required String password}) =>
      gate.future;
  @override
  Future<void> sendResetCode(String email) async {}
  @override
  Future<void> resetPassword(String password) async {}
  @override
  Future<void> verifyCode(String code) async {}
  @override
  Future<void> setPin(String pin) async {}
  @override
  Future<void> verifyPin(String pin) async {}
  @override
  Future<void> signOut() async {}
}

void main() {
  late _HeldAuthRepository repo;

  setUp(() => repo = _HeldAuthRepository());

  Future<void> pumpScreen(WidgetTester tester, Widget screen,
      {bool dark = false}) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        home: screen,
      ),
    ));
    // Entrance is one 900ms controller; the backdrop drifts forever, so
    // frames are pumped by hand rather than settled.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
  }

  Finder button(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(BusyButton));

  FilledButton filledIn(WidgetTester tester, Finder busyButton) =>
      tester.widget<FilledButton>(
          find.descendant(of: busyButton, matching: find.byType(FilledButton)));

  testWidgets('sign in offers Apple and Google above the email form',
      (tester) async {
    await pumpScreen(
        tester, SignInScreen(onSignUp: () {}, onForgotPassword: () {}));

    expect(find.text('Sign in with Apple'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('or with email'), findsOneWidget);
    expect(find.byType(GoogleGlyph), findsOneWidget);

    final apple = tester.getRect(find.text('Sign in with Apple'));
    final email = tester.getRect(find.text('Email'));
    expect(apple.bottom, lessThan(email.top));
  });

  testWidgets('field titles sit above their boxes, not inside them',
      (tester) async {
    await pumpScreen(tester, SignUpScreen(onSignIn: () {}));

    for (final label in ['Full name', 'Email', 'Password']) {
      final title = tester.getRect(find.text(label));
      final field = tester.getRect(find
          .ancestor(of: find.text(label), matching: find.byType(Column))
          .first);
      expect(title.top, closeTo(field.top, 1), reason: label);
    }
    expect(find.text('you@example.com'), findsOneWidget);
    expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
  });

  testWidgets('a provider shows its own loader and locks the other actions',
      (tester) async {
    await pumpScreen(
        tester, SignInScreen(onSignUp: () {}, onForgotPassword: () {}));

    await tester.tap(find.text('Sign in with Apple'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.calls, [SocialProvider.apple]);
    // The loader replaces the Apple label, and only there.
    expect(find.text('Sign in with Apple'), findsNothing);
    expect(find.byType(StrataLoader), findsOneWidget);
    expect(filledIn(tester, button('Sign in with Google')).onPressed, isNull);
    expect(filledIn(tester, button('Sign in')).onPressed, isNull);

    // A second tap while busy does nothing.
    await tester.tap(find.text('Sign in with Google'), warnIfMissed: false);
    await tester.pump();
    expect(repo.calls, [SocialProvider.apple]);

    repo.gate.complete();
    await tester.pump();
  });

  testWidgets('a failed provider sign-in says why and frees the buttons',
      (tester) async {
    repo.failWith = const AuthFailure('Google sign-in was cancelled.');
    await pumpScreen(
        tester, SignInScreen(onSignUp: () {}, onForgotPassword: () {}));

    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    repo.gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Google sign-in was cancelled.'), findsOneWidget);
    expect(find.byType(StrataLoader), findsNothing);
    expect(filledIn(tester, button('Sign in with Apple')).onPressed, isNotNull);
  });

  testWidgets('signing up with a provider still needs the terms accepted',
      (tester) async {
    await pumpScreen(tester, SignUpScreen(onSignIn: () {}));

    await tester.tap(find.text('Sign up with Google'));
    await tester.pump();
    expect(repo.calls, isEmpty);
    expect(find.textContaining('accept the terms'), findsOneWidget);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Sign up with Google'));
    await tester.pump();
    await tester.tap(find.text('Sign up with Google'));
    await tester.pump();
    expect(repo.calls, [SocialProvider.google]);

    repo.gate.complete();
    await tester.pump();
  });

  testWidgets('both screens render in dark mode without overflowing',
      (tester) async {
    await pumpScreen(tester, SignUpScreen(onSignIn: () {}), dark: true);
    expect(tester.takeException(), isNull);
    await pumpScreen(
        tester, SignInScreen(onSignUp: () {}, onForgotPassword: () {}),
        dark: true);
    expect(tester.takeException(), isNull);
  });
}
