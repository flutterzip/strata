import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../models/recipient.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/recipient_providers.dart';
import '../../../shared/utils/ids.dart';
import '../../../shared/widgets/strata_sheet.dart';

/// Keys for the recipient forms, in one place.
abstract final class RecipientKeys {
  static const Key name = Key('recipient-name');
  static const Key handle = Key('recipient-handle');
  static const Key email = Key('recipient-email');
  static const Key save = Key('recipient-save');
  static const Key add = Key('recipient-add');
  static const Key delete = Key('recipient-delete');
}

/// Add or change a recipient.
///
/// One sheet for both, because the fields are identical and two
/// near-identical forms is how they drift apart.
class RecipientEditSheet extends ConsumerStatefulWidget {
  const RecipientEditSheet({super.key, this.existing});

  final Recipient? existing;

  @override
  ConsumerState<RecipientEditSheet> createState() => _RecipientEditSheetState();
}

class _RecipientEditSheetState extends ConsumerState<RecipientEditSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _handle =
      TextEditingController(text: widget.existing?.handle ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');

  String? _problem;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_name, _handle, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  /// First failing field, shown under the form. The save button stays
  /// pressable: a dead control that explains nothing is forbidden here.
  String? _validate(
      List<Recipient> directory, String ownerHandle, String ownerEmail) {
    final name = _name.text.trim();
    final handle = _handle.text.trim().replaceFirst(RegExp(r'^@'), '');
    final email = _email.text.trim().toLowerCase();

    if (name.isEmpty) return 'Enter their name.';
    if (handle.isEmpty) return 'Enter their handle, for example @akosua.';
    if (RegExp(r'[^A-Za-z0-9_.]').hasMatch(handle)) {
      return 'A handle can only hold letters, numbers, dots and underscores.';
    }
    if (email.isEmpty) return 'Enter their email.';
    // Deliberately loose: the only thing worth refusing is text that cannot
    // be an address at all. Anything stricter rejects real addresses.
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'That does not look like an email address.';
    }

    if (handle.toLowerCase() ==
            ownerHandle.replaceFirst(RegExp(r'^@'), '').toLowerCase() ||
        email == ownerEmail.toLowerCase()) {
      return 'That is your own account. You cannot send to yourself.';
    }

    for (final r in directory) {
      if (r.id == widget.existing?.id) continue;
      if (r.bareHandle.toLowerCase() == handle.toLowerCase()) {
        return '${r.name} already uses that handle.';
      }
      if (r.email.toLowerCase() == email) {
        return '${r.name} already uses that email.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final directory = ref.read(recipientsProvider).valueOrNull ?? const [];
    final profile = ref.read(profileProvider).valueOrNull;
    final problem =
        _validate(directory, profile?.handle ?? '', profile?.email ?? '');
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }

    setState(() {
      _problem = null;
      _saving = true;
    });

    try {
      final notifier = ref.read(recipientsProvider.notifier);
      if (_isEdit) {
        await notifier.edit(
          widget.existing!.id,
          (r) => r.copyWith(
            name: _name.text.trim(),
            handle: _handle.text.trim(),
            email: _email.text.trim(),
          ),
        );
      } else {
        await notifier.create(Recipient(
          id: Ids.next('r'),
          name: _name.text.trim(),
          handle: _handle.text.trim(),
          email: _email.text.trim(),
          // Not ours to assert. A recipient somebody typed in has not been
          // confirmed by anyone, and the send flow says so before the money
          // moves rather than after.
          verified: false,
        ));
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _problem = 'Could not save that. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return StrataSheet(
      icon: _isEdit ? Icons.edit_outlined : Icons.person_add_alt_1_outlined,
      title: _isEdit ? 'Edit recipient' : 'Add a recipient',
      message: _isEdit
          ? null
          : 'A recipient you add yourself is not confirmed, so the send '
              'screen will flag it before any money moves.',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: RecipientKeys.name,
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Akosua Mensah',
            ),
          ),
          const SizedBox(height: Space.lg),
          TextField(
            key: RecipientKeys.handle,
            controller: _handle,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Handle',
              hintText: '@akosua',
            ),
          ),
          const SizedBox(height: Space.lg),
          TextField(
            key: RecipientKeys.email,
            controller: _email,
            autocorrect: false,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'akosua.mensah@example.com',
            ),
          ),
          if (_problem != null) ...[
            const SizedBox(height: Space.lg),
            Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 18, color: scheme.error),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(_problem!,
                      style: text.bodySmall?.copyWith(color: scheme.error)),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          key: RecipientKeys.save,
          onPressed: _saving ? null : _save,
          child: Text(_saving
              ? 'Saving…'
              : _isEdit
                  ? 'Save changes'
                  : 'Add recipient'),
        ),
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
