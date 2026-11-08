import 'package:flutter/foundation.dart';

/// Where the user is in the first-run journey.
///
/// Persisted, so a relaunch returns to the right place, and reset puts it
/// back to [onboarding] so the first-run experience can be demonstrated
/// again without reinstalling.
enum AuthStage {
  /// Has never completed the intro.
  onboarding,

  /// Has seen the intro but is not signed in.
  signedOut,

  /// Signed in, but has not yet set a PIN.
  needsPin,

  /// Fully in.
  signedIn;

  static AuthStage parse(String? raw) =>
      AuthStage.values.asNameMap()[raw] ?? AuthStage.onboarding;
}

/// A third-party identity provider offered on sign in and sign up.
enum SocialProvider {
  apple('Apple'),
  google('Google');

  const SocialProvider(this.label);
  final String label;
}

/// The prefilled account that lets the template be tried without signing up.
@immutable
class DemoAccount {
  const DemoAccount({
    required this.email,
    required this.password,
    required this.pin,
    required this.otp,
  });

  final String email;
  final String password;

  /// Accepted PIN for the demo.
  final String pin;

  /// Accepted one-time code for the demo.
  final String otp;

  factory DemoAccount.fromJson(Map<String, dynamic> json) => DemoAccount(
        email: json['email'] as String? ?? '',
        password: json['password'] as String? ?? '',
        pin: json['pin'] as String? ?? '0000',
        otp: json['otp'] as String? ?? '000000',
      );
}

/// One intro slide, loaded from `assets/data/auth.json`.
@immutable
class OnboardingSlide {
  const OnboardingSlide({
    required this.id,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.motif,
  });

  final String id;
  final String eyebrow;
  final String title;
  final String body;

  /// Which illustration to draw. Art is generated in code, so a slide is
  /// text plus a motif name rather than an image asset.
  final String motif;

  factory OnboardingSlide.fromJson(Map<String, dynamic> json) =>
      OnboardingSlide(
        id: json['id'] as String? ?? '',
        eyebrow: json['eyebrow'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        motif: json['motif'] as String? ?? 'stack',
      );
}

/// Why an auth attempt failed. Carries a message the UI can show as-is.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
