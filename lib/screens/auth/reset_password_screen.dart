import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/design_tokens.dart';
import '../../shared/utils/auth_validation.dart';
import '../../providers/auth_providers.dart';
import '../../shared/widgets/busy_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_field.dart';

/// Final step of a reset: choose a new password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.onBack,
    required this.onDone,
  });

  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _confirmFocus = FocusNode();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _busy = true);
    await ref.read(authRepositoryProvider).resetPassword(_password.text);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      eyebrow: 'Almost there',
      title: 'Choose a new\npassword',
      subtitle: 'Make it long. Length does more for you than symbols do.',
      onBack: widget.onBack,
      fields: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              PasswordField(
                controller: _password,
                label: 'New password',
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
                label: 'Confirm new password',
                hint: 'Type it once more',
                validator: (v) =>
                    AuthValidation.confirmPassword(_password.text, v ?? ''),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ],
      footer: BusyButton(
        label: 'Save password',
        busy: _busy,
        busyLabel: 'Saving password',
        onPressed: _submit,
      ),
    );
  }
}
