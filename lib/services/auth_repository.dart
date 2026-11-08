import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_timing.dart';
import '../models/auth_models.dart';
import 'demo_data.dart';

/// Contract for authentication, so a real identity provider can replace the
/// demo implementation without touching a screen.
abstract interface class AuthRepository {
  Future<AuthStage> stage();
  Future<void> setStage(AuthStage stage);

  /// The prefilled demo account, read from `assets/data/auth.json`.
  Future<DemoAccount> demoAccount();

  Future<List<OnboardingSlide>> onboarding();

  /// Throws [AuthFailure] with a user-facing message on bad credentials.
  Future<void> signIn({required String email, required String password});

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  });

  /// Sign in — or create the account on first use — with Apple or Google.
  /// Throws [AuthFailure] if the provider refuses or the user cancels.
  Future<void> signInWith(SocialProvider provider);

  Future<void> sendResetCode(String email);
  Future<void> resetPassword(String password);
  Future<void> verifyCode(String code);
  Future<void> setPin(String pin);
  Future<void> verifyPin(String pin);
  Future<void> signOut();
}

/// Demo implementation. Validates against the account in the seed file and
/// waits as long as [AppTiming] says each call should take, so loading
/// states are real rather than theoretical.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository({SharedPreferences? prefs, this.latency})
      : _injected = prefs;

  static const String stageKey = 'strata.auth.stage.v1';
  static const String pinKey = 'strata.auth.pin.v1';
  static const String seedFile = 'auth.json';

  final SharedPreferences? _injected;

  /// Overrides every per-call wait in [AppTiming] — tests pass zero.
  final Duration? latency;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= _injected ?? await SharedPreferences.getInstance();

  Future<void> _settle(Duration designed) => latency == null
      ? AppTiming.wait(designed)
      : Future<void>.delayed(latency!);

  @override
  Future<AuthStage> stage() async =>
      AuthStage.parse((await _store).getString(stageKey));

  @override
  Future<void> setStage(AuthStage stage) async =>
      (await _store).setString(stageKey, stage.name);

  @override
  Future<DemoAccount> demoAccount() async {
    final doc = await DemoData.loadJson(seedFile);
    return DemoAccount.fromJson(
        (doc['demoAccount'] as Map?)?.cast<String, dynamic>() ?? const {});
  }

  @override
  Future<List<OnboardingSlide>> onboarding() async {
    final rows = await DemoData.loadList(seedFile, 'onboarding');
    return rows.map(OnboardingSlide.fromJson).toList();
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _settle(AppTiming.signIn);
    final demo = await demoAccount();
    if (email.trim().toLowerCase() != demo.email.toLowerCase()) {
      throw const AuthFailure('We do not recognise that email address.');
    }
    if (password != demo.password) {
      throw const AuthFailure('That password does not match. Try again.');
    }
    await setStage(AuthStage.needsPin);
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await _settle(AppTiming.signUp);
    final demo = await demoAccount();
    if (email.trim().toLowerCase() == demo.email.toLowerCase()) {
      throw const AuthFailure('That email already has an account. Sign in.');
    }
    await setStage(AuthStage.needsPin);
  }

  @override
  Future<void> signInWith(SocialProvider provider) async {
    await _settle(AppTiming.socialSignIn);
    // Demo: the provider always vouches for the user. A real build swaps in
    // `sign_in_with_apple` / `google_sign_in`, sends the returned identity
    // token to its own server, and maps a cancel to an [AuthFailure].
    await setStage(AuthStage.needsPin);
  }

  @override
  Future<void> resetPassword(String password) async {
    await _settle(AppTiming.resetPassword);
  }

  @override
  Future<void> sendResetCode(String email) async {
    await _settle(AppTiming.sendResetCode);
    // Deliberately does not reveal whether the address exists: telling an
    // attacker which emails are registered is an account-enumeration leak.
  }

  @override
  Future<void> verifyCode(String code) async {
    await _settle(AppTiming.verifyCode);
    final demo = await demoAccount();
    if (code != demo.otp) {
      throw const AuthFailure('That code is not right. Check and try again.');
    }
  }

  @override
  Future<void> setPin(String pin) async {
    await _settle(AppTiming.setPin);
    // A demo PIN only. A real app stores a derived verifier in the secure
    // enclave / keystore, never the PIN itself in shared preferences.
    await (await _store).setString(pinKey, pin);
    await setStage(AuthStage.signedIn);
  }

  @override
  Future<void> verifyPin(String pin) async {
    await _settle(AppTiming.verifyPin);
    final stored = (await _store).getString(pinKey);
    final demo = await demoAccount();
    if (pin != (stored ?? demo.pin)) {
      throw const AuthFailure('Wrong PIN.');
    }
  }

  @override
  Future<void> signOut() async {
    await (await _store).remove(pinKey);
    await setStage(AuthStage.signedOut);
  }
}
