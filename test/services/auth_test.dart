import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/config/app_timing.dart';
import 'package:strata/models/auth_models.dart';
import 'package:strata/services/auth_repository.dart';
import 'package:strata/services/demo_data.dart';
import 'package:strata/shared/utils/auth_validation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DemoData.clearCache();
  });

  DemoAuthRepository repo() => DemoAuthRepository(latency: Duration.zero);

  group('AuthValidation', () {
    test('accepts ordinary addresses and rejects obvious nonsense', () {
      expect(AuthValidation.email('hello@flutterzip.com'), isNull);
      expect(AuthValidation.email('a+tag@sub.domain.co.uk'), isNull);
      expect(AuthValidation.email(''), 'Enter your email address');
      expect(AuthValidation.email('not-an-email'), isNotNull);
      expect(AuthValidation.email('two@@at.com'), isNotNull);
    });

    test('password requires length', () {
      expect(AuthValidation.password(''), 'Enter your password');
      expect(AuthValidation.password('short'), 'Use at least 8 characters');
      expect(AuthValidation.password('longenough'), isNull);
    });

    test('confirmation must match', () {
      expect(AuthValidation.confirmPassword('abc12345', ''), isNotNull);
      expect(AuthValidation.confirmPassword('abc12345', 'abc12346'),
          'Those passwords do not match');
      expect(AuthValidation.confirmPassword('abc12345', 'abc12345'), isNull);
    });

    test('strength rewards length over character jumble', () {
      // A long passphrase should beat a short jumble.
      final passphrase =
          AuthValidation.passwordStrength('correct horse battery staple');
      final jumble = AuthValidation.passwordStrength('aB3\$x');
      expect(passphrase, greaterThan(jumble));
    });

    test('a repeated character scores zero however long', () {
      expect(AuthValidation.passwordStrength('aaaaaaaaaaaaaaaaaaaa'), 0);
    });

    test('strength is bounded and labelled', () {
      for (final p in [
        '',
        'a',
        'abcdefgh',
        'Abcdefgh1!',
        'Abcdefghijklmnop1!'
      ]) {
        final s = AuthValidation.passwordStrength(p);
        expect(s, inInclusiveRange(0, 4));
        expect(AuthValidation.strengthLabel(s), isNotEmpty);
      }
    });

    test('otp requires the full length', () {
      expect(AuthValidation.otp(''), isNotNull);
      expect(AuthValidation.otp('123'), 'The code is 6 digits');
      expect(AuthValidation.otp('123456'), isNull);
    });
  });

  group('AuthStage', () {
    test('parses known names and defaults to onboarding', () {
      expect(AuthStage.parse('signedIn'), AuthStage.signedIn);
      expect(AuthStage.parse('needsPin'), AuthStage.needsPin);
      expect(AuthStage.parse(null), AuthStage.onboarding);
      expect(AuthStage.parse('nonsense'), AuthStage.onboarding);
    });
  });

  group('DemoAuthRepository', () {
    test('Apple and Google sign-in move on to choosing a PIN', () async {
      for (final provider in SocialProvider.values) {
        SharedPreferences.setMockInitialValues({});
        final r = repo();
        await r.signInWith(provider);
        expect(await r.stage(), AuthStage.needsPin);
      }
    });

    test('a fresh install starts at onboarding', () async {
      expect(await repo().stage(), AuthStage.onboarding);
    });

    test('seed exposes the demo account and the slides', () async {
      final r = repo();
      final demo = await r.demoAccount();
      expect(demo.email, isNotEmpty);
      expect(demo.password, isNotEmpty);
      expect(demo.pin, hasLength(4));
      expect(demo.otp, hasLength(6));

      final slides = await r.onboarding();
      expect(slides, hasLength(3));
      expect(slides.every((s) => s.title.isNotEmpty), isTrue);
      expect(slides.map((s) => s.id).toSet(), hasLength(3));
    });

    test('correct credentials move the user to PIN setup', () async {
      final r = repo();
      final demo = await r.demoAccount();
      await r.signIn(email: demo.email, password: demo.password);
      expect(await r.stage(), AuthStage.needsPin);
    });

    test('email is matched case-insensitively', () async {
      final r = repo();
      final demo = await r.demoAccount();
      await r.signIn(email: demo.email.toUpperCase(), password: demo.password);
      expect(await r.stage(), AuthStage.needsPin);
    });

    test('a wrong password is rejected with a usable message', () async {
      final r = repo();
      final demo = await r.demoAccount();
      await expectLater(
        r.signIn(email: demo.email, password: 'wrong'),
        throwsA(isA<AuthFailure>()),
      );
      expect(await r.stage(), AuthStage.onboarding,
          reason: 'a failed sign-in must not advance the stage');
    });

    test('signing up with the demo address is refused', () async {
      final r = repo();
      final demo = await r.demoAccount();
      await expectLater(
        r.signUp(name: 'Ada', email: demo.email, password: 'longenough'),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('reset code never reveals whether the address exists', () async {
      // Both an unknown and the known address must behave identically.
      await expectLater(repo().sendResetCode('nobody@nowhere.test'), completes);
      final r = repo();
      await expectLater(
          r.sendResetCode((await r.demoAccount()).email), completes);
    });

    test('otp verification accepts only the demo code', () async {
      final r = repo();
      final demo = await r.demoAccount();
      await expectLater(r.verifyCode('000000'), throwsA(isA<AuthFailure>()));
      await expectLater(r.verifyCode(demo.otp), completes);
    });

    test('setting a PIN completes sign-in and the PIN then verifies', () async {
      final r = repo();
      await r.setPin('4821');
      expect(await r.stage(), AuthStage.signedIn);
      await expectLater(r.verifyPin('4821'), completes);
      await expectLater(r.verifyPin('0000'), throwsA(isA<AuthFailure>()));
    });

    test('signing out clears the PIN and returns to signed out', () async {
      final r = repo();
      await r.setPin('4821');
      await r.signOut();
      expect(await r.stage(), AuthStage.signedOut);
    });

    test('the stage survives a new repository instance', () async {
      await repo().setStage(AuthStage.signedIn);
      expect(await repo().stage(), AuthStage.signedIn);
    });
  });

  group('AppTiming', () {
    test(
        'every deliberate wait is long enough to see and short enough '
        'not to annoy', () {
      for (final d in [
        AppTiming.signIn,
        AppTiming.signUp,
        AppTiming.socialSignIn,
        AppTiming.sendResetCode,
        AppTiming.verifyCode,
        AppTiming.resetPassword,
        AppTiming.setPin,
        AppTiming.verifyPin,
        AppTiming.refresh,
      ]) {
        expect(d.inMilliseconds, inInclusiveRange(300, 2500));
      }
      expect(AppTiming.splashTotal.inMilliseconds, lessThan(4000));
    });

    test('atLeast returns the work\'s value', () async {
      expect(await AppTiming.atLeast(Duration.zero, Future.value(7)), 7);
    });

    test('refreshing swallows a failed reload', () async {
      await AppTiming.refreshing(Future<void>.error(Exception('offline')))
          .timeout(const Duration(seconds: 3));
    });
  });
}
