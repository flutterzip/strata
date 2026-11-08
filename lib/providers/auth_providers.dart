import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_models.dart';
import '../services/auth_repository.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => DemoAuthRepository());

/// The prefilled demo credentials, so the sign-in form can show them.
final demoAccountProvider = FutureProvider<DemoAccount>(
    (ref) => ref.watch(authRepositoryProvider).demoAccount());

final onboardingSlidesProvider = FutureProvider<List<OnboardingSlide>>(
    (ref) => ref.watch(authRepositoryProvider).onboarding());

class AuthNotifier extends AsyncNotifier<AuthStage> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AuthStage> build() => _repo.stage();

  Future<void> _move(AuthStage stage) async {
    await _repo.setStage(stage);
    state = AsyncData(stage);
  }

  Future<void> completeOnboarding() => _move(AuthStage.signedOut);

  /// Puts the user back at the very start. Used by Reset demo data so the
  /// first-run experience can be shown again without reinstalling.
  Future<void> restartOnboarding() async {
    await _repo.signOut();
    await _move(AuthStage.onboarding);
  }

  Future<void> signIn({required String email, required String password}) async {
    await _repo.signIn(email: email, password: password);
    state = const AsyncData(AuthStage.needsPin);
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    await _repo.signUp(name: name, email: email, password: password);
    state = const AsyncData(AuthStage.needsPin);
  }

  Future<void> signInWith(SocialProvider provider) async {
    await _repo.signInWith(provider);
    state = const AsyncData(AuthStage.needsPin);
  }

  Future<void> setPin(String pin) async {
    await _repo.setPin(pin);
    state = const AsyncData(AuthStage.signedIn);
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncData(AuthStage.signedOut);
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthStage>(AuthNotifier.new);
