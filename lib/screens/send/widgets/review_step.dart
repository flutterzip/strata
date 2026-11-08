import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';
import '../../../models/payment_card.dart';
import '../../../models/recipient.dart';
import '../../../shared/utils/money.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../../shared/widgets/avatar_circle.dart';

/// Step three: everything that is about to happen, before it happens.
///
/// The fee and the resulting balance are stated here rather than implied.
/// A transfer with no fee still says so — "no fee" is information, and its
/// absence reads as something withheld.
class ReviewStep extends StatelessWidget {
  const ReviewStep({
    super.key,
    required this.recipient,
    required this.card,
    required this.amountMinor,
    required this.resultingBalanceMinor,
    required this.noteController,
    required this.noteKey,
  });

  final Recipient recipient;
  final PaymentCard card;
  final int amountMinor;
  final int resultingBalanceMinor;
  final TextEditingController noteController;
  final Key noteKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AvatarCircle(
              initials: recipient.initials,
              avatar: recipient.avatar,
              size: AvatarSize.header,
            ),
          ),
          const SizedBox(height: Space.md),
          Center(
            child: AmountText(
              minor: amountMinor,
              currency: card.currency,
              semanticsPrefix: 'Sending',
            ),
          ),
          const SizedBox(height: Space.xs),
          Center(
            child: Text('to ${recipient.name}',
                style: text.bodyMedium, textAlign: TextAlign.center),
          ),
          const SizedBox(height: Space.xxl),
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              borderRadius: Radii.brXl,
              color: scheme.surfaceContainer,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                _Line(label: 'To', value: recipient.handle),
                _Line(label: 'Their email', value: recipient.email),
                _Line(
                  label: 'From',
                  value: '${card.displayLabel} · ${card.shortMask}',
                ),
                _Line(
                  label: 'Amount',
                  value: Money.format(amountMinor, card.currency),
                ),
                const _Line(label: 'Fee', value: 'No fee'),
                _Line(
                  label: 'Balance after',
                  value: Money.format(resultingBalanceMinor, card.currency),
                  emphasised: true,
                ),
              ],
            ),
          ),
          if (!recipient.verified) ...[
            const SizedBox(height: Space.lg),
            // Said before the money moves, not after. Ochre with an icon and
            // words — never colour on its own.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: scheme.error),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    'This account has not been confirmed. Check the handle '
                    'and email above before you send.',
                    style: text.bodySmall?.copyWith(color: scheme.error),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Space.xl),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Note (optional)',
                style:
                    text.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(height: Space.sm),
          TextField(
            key: noteKey,
            controller: noteController,
            maxLines: 2,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What is this for?',
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: emphasised
                    ? text.titleSmall
                    : text.bodyMedium?.copyWith(color: scheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
