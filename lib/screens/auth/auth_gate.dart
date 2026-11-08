import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/motion.dart';
import '../../models/auth_models.dart';
import '../../providers/auth_providers.dart';
import '../../shared/widgets/strata_mark.dart';
import '../shell/app_shell.dart';
import 'forgot_password_screen.dart';
import 'onboarding_screen.dart';
import 'otp_screen.dart';
import 'pin_screen.dart';
import 'reset_password_screen.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

/// Routes the first-run journey by [AuthStage].
///
/// Stage transitions cross-fade rather than push, because they are not
/// navigation: the user is not going deeper, the app is changing what it is
/// showing them. Within the signed-out stage the individual screens *do*
/// slide, because there you genuinely are moving back and forth.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(authProvider);

    return AnimatedSwitcher(
      duration: context.motion(Motion.slow),
      switchInCurve: Motion.standard,
      switchOutCurve: Motion.exit,
      child: stage.when(
        loading: () => const _Booting(),
        error: (_, __) => const _AuthFlow(),
        data: (s) => switch (s) {
          AuthStage.onboarding =>
            const OnboardingScreen(key: ValueKey('onboarding')),
          AuthStage.signedOut => const _AuthFlow(key: ValueKey('auth')),
          AuthStage.needsPin => const PinScreen(key: ValueKey('pin')),
          AuthStage.signedIn => const AppShell(key: ValueKey('shell')),
        },
      ),
    );
  }
}

class _Booting extends StatelessWidget {
  const _Booting();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: StrataLoader(size: 34)),
      );
}

/// Which screen of the signed-out flow is showing.
enum _AuthStep { signIn, signUp, forgot, otp, resetPassword }

class _AuthFlow extends StatefulWidget {
  const _AuthFlow({super.key});

  @override
  State<_AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<_AuthFlow> {
  /// Screenshot hook: `--dart-define=startAuthStep=signUp` opens there.
  static const String _startStep = String.fromEnvironment('startAuthStep');

  _AuthStep _step =
      _AuthStep.values.asNameMap()[_startStep] ?? _AuthStep.signIn;
  /// Filled in by Forgot password. Opened straight onto the code step by
  /// the screenshot hook, it falls back to the demo address.
  String _email = _startStep == 'otp' ? 'hello@flutterzip.com' : '';

  /// Steps later in the flow enter from the right and leave to the right,
  /// so going back feels like going back.
  static const _order = _AuthStep.values;

  void _go(_AuthStep next) => setState(() => _step = next);

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;

    final screen = switch (_step) {
      _AuthStep.signIn => SignInScreen(
          key: const ValueKey('signIn'),
          onSignUp: () => _go(_AuthStep.signUp),
          onForgotPassword: () => _go(_AuthStep.forgot),
        ),
      _AuthStep.signUp => SignUpScreen(
          key: const ValueKey('signUp'),
          onSignIn: () => _go(_AuthStep.signIn),
        ),
      _AuthStep.forgot => ForgotPasswordScreen(
          key: const ValueKey('forgot'),
          onBack: () => _go(_AuthStep.signIn),
          onCodeSent: (email) {
            _email = email;
            _go(_AuthStep.otp);
          },
        ),
      _AuthStep.otp => OtpScreen(
          key: const ValueKey('otp'),
          email: _email,
          onBack: () => _go(_AuthStep.forgot),
          onVerified: () => _go(_AuthStep.resetPassword),
        ),
      _AuthStep.resetPassword => ResetPasswordScreen(
          key: const ValueKey('resetPassword'),
          onBack: () => _go(_AuthStep.otp),
          onDone: () => _go(_AuthStep.signIn),
        ),
    };

    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : Motion.gentle,
      switchInCurve: Motion.standard,
      switchOutCurve: Motion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(_step.name);
        final dx = _order.indexOf(_step) == 0 ? -1.0 : 1.0;
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(incoming ? dx * 0.12 : dx * -0.12, 0),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: screen,
    );
  }
}
