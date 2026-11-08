import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/design_tokens.dart';
import '../../providers/auth_providers.dart';
import '../../shared/utils/auth_validation.dart';
import '../../shared/widgets/busy_button.dart';
import 'widgets/auth_banner.dart';
import 'widgets/auth_field.dart';
import 'widgets/auth_scaffold.dart';

/// Step one of a password reset: ask where to send the code.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.onBack,
    required this.onCodeSent,
  });

  final VoidCallback onBack;
  final ValueChanged<String> onCodeSent;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Prefill from the demo account so the flow can be walked without
    // inventing an address.
    ref.read(demoAccountProvider.future).then((d) {
      if (mounted && _email.text.isEmpty) _email.text = d.email;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _busy = true);
    await ref.read(authRepositoryProvider).sendResetCode(_email.text.trim());
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = false);
    widget.onCodeSent(_email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      eyebrow: 'Reset',
      title: 'Forgot your\npassword?',
      subtitle: 'Tell us the address on the account and we will send a '
          'six-digit code.',
      onBack: widget.onBack,
      fields: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthField(
                controller: _email,
                label: 'Email',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.email],
                validator: (v) => AuthValidation.email(v ?? ''),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: Space.lg),
              AuthBanner.info(
                message: 'If an account exists for that address, a code is '
                    'on its way.',
              ),
            ],
          ),
        ),
      ],
      footer: BusyButton(
        label: 'Send code',
        busy: _busy,
        busyLabel: 'Sending code',
        onPressed: _submit,
      ),
    );
  }
}
