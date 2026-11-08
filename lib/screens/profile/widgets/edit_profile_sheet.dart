import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../models/user_profile.dart';
import '../../../providers/profile_providers.dart';
import '../../../shared/widgets/strata_sheet.dart';

/// Edit the signed-in person's details.
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _email = TextEditingController(text: widget.profile.email);
  late final _handle = TextEditingController(text: widget.profile.handle);
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _handle]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _requireName(String? v) =>
      (v == null || v.trim().length < 2) ? 'Enter your name' : null;

  static String? _requireEmail(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Enter your email';
    // Deliberately permissive: the only reliable test of an address is
    // sending to it, and over-strict patterns reject valid addresses.
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
      return 'That does not look like an email';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await ref.read(profileProvider.notifier).edit((p) => p.copyWith(
          name: _name.text.trim(),
          email: _email.text.trim(),
          handle: _handle.text.trim(),
        ));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return StrataSheet(
      icon: Icons.person_outline_rounded,
      title: 'Edit profile',
      message: 'This is what appears on your account and statements.',
      scrollable: true,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: _requireName,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: Space.lg),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: _requireEmail,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: Space.lg),
            TextFormField(
              controller: _handle,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(labelText: 'Handle'),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2))
              : const Text('Save changes'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
