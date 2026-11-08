import '../../config/app_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/design_tokens.dart';
import '../../models/auth_models.dart';
import '../../providers/auth_providers.dart';
import '../../shared/utils/auth_validation.dart';
import '../../shared/widgets/busy_button.dart';
import 'widgets/auth_banner.dart';
import 'widgets/auth_field.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_field.dart';
import 'widgets/social_auth_buttons.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _busy = false;
  SocialProvider? _social;
  bool _accepted = false;

  bool get _working => _busy || _social != null;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    for (final f in [_emailFocus, _passwordFocus, _confirmFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_working) return;
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (!_accepted) {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'Please accept the terms to continue.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).signUp(
            name: _name.text,
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
    }
  }

  /// Apple and Google skip the form — the provider supplies the name and
  /// address — but not the terms: agreeing is still required first.
  Future<void> _signUpWith(SocialProvider provider) async {
    setState(() => _error = null);
    if (!_accepted) {
      HapticFeedback.heavyImpact();
      setState(() => _error =
          'Please accept the terms before continuing with ${provider.label}.');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _social = provider);
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      eyebrow: 'Get started',
      title: 'Create your\n${AppBrand.name} account',
      subtitle: 'It takes about a minute. No card needed to look around.',
      onBack: _working ? () {} : widget.onSignIn,
      fields: [
        SocialAuthButtons(
          verb: 'Sign up',
          pending: _social,
          enabled: !_busy,
          onPressed: _signUpWith,
        ),
        Form(
          key: _formKey,
          child: Column(
            children: [
              if (_error != null) ...[
                AuthBanner.error(message: _error!),
                const SizedBox(height: Space.lg),
              ],
              AuthField(
                controller: _name,
                label: 'Full name',
                hint: 'Ada Lovelace',
                icon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                validator: (v) => AuthValidation.name(v ?? ''),
                onSubmitted: (_) => _emailFocus.requestFocus(),
              ),
              const SizedBox(height: Space.lg),
              AuthField(
                controller: _email,
                focusNode: _emailFocus,
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
                showStrength: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => AuthValidation.password(v ?? ''),
                onSubmitted: (_) => _confirmFocus.requestFocus(),
              ),
              const SizedBox(height: Space.lg),
              PasswordField(
                controller: _confirm,
                focusNode: _confirmFocus,
                label: 'Confirm password',
                hint: 'Type it once more',
                validator: (v) =>
                    AuthValidation.confirmPassword(_password.text, v ?? ''),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: Space.xl),
              // A real checkbox, not a buried "by continuing you agree".
              // Consent that is never shown is not consent.
              InkWell(
                onTap: () => setState(() => _accepted = !_accepted),
                borderRadius: Radii.brMd,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        checked: _accepted,
                        label: 'Accept the terms and privacy policy',
                        child: ExcludeSemantics(
                          child: Checkbox(
                            value: _accepted,
                            onChanged: (v) =>
                                setState(() => _accepted = v ?? false),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 11),
                          child: Text(
                            'I agree to the Terms of Service and the '
                            'Privacy Policy.',
                            style: text.bodySmall
                                ?.copyWith(color: scheme.onSurface),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      footer: Column(
        children: [
          BusyButton(
            label: 'Create account',
            busy: _busy,
            busyLabel: 'Creating your account',
            onPressed: _social != null ? null : _submit,
          ),
          const SizedBox(height: Space.sm),
          // Wraps rather than overflowing at large text sizes on a
          // narrow phone.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Already have an account?', style: text.bodySmall),
              TextButton(
                onPressed: _working ? null : widget.onSignIn,
                child: const Text('Sign in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
