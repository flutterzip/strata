import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../config/palette.dart';
import '../../../models/payment_card.dart';
import '../../../providers/wallet_providers.dart';
import '../../../shared/utils/card_formatters.dart';
import '../../../shared/utils/card_validation.dart';
import '../../../shared/widgets/card_face.dart';
import '../../../shared/widgets/strata_sheet.dart';
import '../../add_card/widgets/skin_picker.dart';

/// Edit an existing card: the Update half of CRUD.
///
/// Only the fields that can legitimately change are editable. The number and
/// security code are not stored, so they cannot be edited here — a different
/// number is a different card.
class EditCardSheet extends ConsumerStatefulWidget {
  const EditCardSheet({super.key, required this.card});

  final PaymentCard card;

  @override
  ConsumerState<EditCardSheet> createState() => _EditCardSheetState();
}

class _EditCardSheetState extends ConsumerState<EditCardSheet> {
  late final _holder = TextEditingController(text: widget.card.holder);
  late final _nickname =
      TextEditingController(text: widget.card.nickname ?? '');
  late final _expiry = TextEditingController(text: widget.card.expiryLabel);
  late CardSkin _skin = widget.card.skin;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_holder, _nickname, _expiry]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_holder, _nickname, _expiry]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final e = CardValidation.digitsOnly(_expiry.text);
    try {
      await ref.read(walletProvider.notifier).edit(
            widget.card.id,
            (c) => c.copyWith(
              holder: _holder.text.trim(),
              nickname: _nickname.text,
              skin: _skin,
              expiryMonth: int.parse(e.substring(0, 2)),
              expiryYear: 2000 + int.parse(e.substring(2, 4)),
            ),
          );
    } catch (_) {
      if (!mounted) return;
      // The optimistic change has already been rolled back; keep the sheet
      // open so the entry is not lost.
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that. Try again.')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return StrataSheet(
      icon: Icons.tune_rounded,
      title: 'Edit card',
      message: 'The number and security code are never stored, so they '
          'cannot be changed here. A different number is a different card.',
      scrollable: true,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Live preview, so the effect of a change is visible before
            // committing to it.
            CardFace(
              skin: _skin,
              brand: widget.card.brand,
              funding: widget.card.funding,
              label: _nickname.text.trim().isEmpty
                  ? widget.card.funding.label
                  : _nickname.text.trim(),
              numberText: widget.card.maskedNumber,
              holder: _holder.text,
              expiry: _expiry.text,
              sheen: 0.6,
            ),
            const SizedBox(height: Space.xl),
            SkinPickerRow(
              selected: _skin,
              onChanged: (s) => setState(() => _skin = s),
            ),
            const SizedBox(height: Space.xl),
            TextFormField(
              controller: _nickname,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Card name',
                hintText: 'Travel, Household, Everyday\u2026',
                helperText: 'Optional. Shown on the card and in your wallet.',
              ),
            ),
            const SizedBox(height: Space.lg),
            TextFormField(
              controller: _holder,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (_) => CardValidation.holder(_holder.text),
              decoration: const InputDecoration(labelText: 'Name on card'),
            ),
            const SizedBox(height: Space.lg),
            TextFormField(
              controller: _expiry,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [ExpiryFormatter()],
              validator: (_) => CardValidation.expiry(_expiry.text),
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Expiry',
                hintText: 'MM/YY',
                helperText: 'Update this when the card is reissued.',
              ),
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
