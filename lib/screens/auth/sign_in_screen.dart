import '../../config/app_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/design_tokens.dart';
import '../../models/auth_models.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import '../../shared/utils/auth_validation.dart';
import '../../shared/widgets/busy_button.dart';
import 'widgets/auth_banner.dart';
import 'widgets/auth_field.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_field.dart';
import 'widgets/social_auth_buttons.dart';

/// Sign in, prefilled with the demo account.
///
/// The credentials come from `assets/data/auth.json` and are filled in as
/// soon as they load, so the template can be tried in one tap. A banner says
/// plainly that this is demo data rather than leaving someone to wonder
/// whose account they are looking at.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({
    super.key,
    required this.onSignUp,
    required this.onForgotPassword,
  });

  final VoidCallback onSignUp;
  final VoidCallback onForgotPassword;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _busy = false;
  SocialProvider? _social;
  String? _error;

  bool get _working => _busy || _social != null;
  bool _prefilled = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// Fill once, and never clobber something the user has typed.
  void _prefill(DemoAccount demo) {
    if (_prefilled) return;
    _prefilled = true;
    if (_email.text.isEmpty) _email.text = demo.email;
    if (_password.text.isEmpty) _password.text = demo.password;
  }

  Future<void> _signInWith(SocialProvider provider) async {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      _social = provider;
    });
    try {
      await ref.read(authProvider.notifier).signInWith(provider);
      if (mounted) HapticFeedback.mediumImpact();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _social = null;
        _error = e.message;
      });
    }
  }

  Future<void> _submit() async {
    if (_working) return;
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).signIn(
            email: _email.text,
            password: _password.text,
          );
      if (mounted) HapticFeedback.mediumImpact();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final demo = ref.watch(demoAccountProvider);
    demo.whenData(_prefill);

    return AuthScaffold(
      showBack: false,
      eyebrow: 'Welcome back',
      title: 'Sign in to ${AppBrand.name}',
      subtitle: 'Your wallet, exactly where you left it.',
      fields: [
        SocialAuthButtons(
          verb: 'Sign in',
          pending: _social,
          enabled: !_busy,
          onPressed: _signInWith,
        ),
        Form(
          key: _formKey,
          child: Column(
            children: [
              if (_error != null) ...[
                AuthBanner.error(message: _error!),
                const SizedBox(height: Space.lg),
              ],
              if (ref.watch(showDemoHintsProvider))
                demo.maybeWhen(
                  data: (d) => Padding(
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    child: AuthBanner.info(
                      message: 'Demo account ${d.email} is filled in. '
                          'Just press Sign in.',
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              AuthField(
                controller: _email,
                label: 'Email',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.email],
                validator: (v) => AuthValidation.email(v ?? ''),
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: Space.lg),
              PasswordField(
                controller: _password,
                focusNode: _passwordFocus,
                autofillHints: const [AutofillHints.password],
                validator: (v) => AuthValidation.password(v ?? ''),
                onSubmitted: (_) => _submit(),
                trailing: TextButton(
                  onPressed: _working ? null : widget.onForgotPassword,
                  style: TextButton.styleFrom(
                    textStyle: text.labelMedium,
                    padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),
            ],
          ),
        ),
      ],
      footer: Column(
        children: [
          BusyButton(
            label: 'Sign in',
            busy: _busy,
            busyLabel: 'Signing in',
            onPressed: _social != null ? null : _submit,
          ),
          const SizedBox(height: Space.sm),
          // Wraps rather than overflowing at large text sizes on a
          // narrow phone.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('New here?', style: text.bodySmall),
              TextButton(
                onPressed: _working ? null : widget.onSignUp,
                child: const Text('Create an account'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
