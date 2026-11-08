import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/app_brand.dart';
import '../../../config/design_tokens.dart';
import '../../../models/payment_card.dart';
import '../../../shared/widgets/settings_row.dart';
import '../../../shared/widgets/strata_sheet.dart';

/// Getting help.
///
/// Information, which is the whole of what support can honestly be in a
/// template with no backend: the routes, what to have ready, and the one
/// number worth having before anything has gone wrong. Nothing here pretends
/// to open a ticket.
class SupportSheet extends StatelessWidget {
  const SupportSheet({super.key, required this.card});

  final PaymentCard card;

  static const Key copyRef = Key('support-copy-ref');

  /// What a support agent asks for first. Never the full number — it is not
  /// stored, and it is not needed.
  String get reference => '${card.brand.label} ${card.shortMask}';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return StrataSheet(
      icon: Icons.support_agent_rounded,
      title: 'Support',
      message: 'Lost card, a payment you do not recognise, or anything that '
          'looks wrong.',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              borderRadius: Radii.brXl,
              color: scheme.surfaceContainer,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Have this ready',
                    style: text.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: Space.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(reference, style: text.titleSmall),
                    ),
                    IconButton(
                      key: SupportSheet.copyRef,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy the card reference',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: reference));
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reference copied')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(
                  'We never ask for your full card number, your PIN or a '
                  'code we sent you. Nobody from ${AppBrand.name} ever will.',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          const SettingsGroup(
            title: 'If it is urgent',
            children: [
              SettingsRow(
                icon: Icons.ac_unit_rounded,
                title: 'Freeze the card first',
                subtitle: 'Then call. Freezing is instant and reversible.',
              ),
              SettingsRow(
                icon: Icons.phone_outlined,
                title: '+1 555 0100',
                subtitle: 'Lost or stolen cards, any hour',
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          const SettingsGroup(
            title: 'Everything else',
            children: [
              SettingsRow(
                icon: Icons.mail_outline_rounded,
                title: 'help@strata.example',
                subtitle: 'We reply within one working day',
              ),
              SettingsRow(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Chat, weekdays 9–6',
                subtitle: 'Shortest wait just after 9',
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Text(
            'This is a demo template: the number and address above are '
            'examples, and nothing here sends a message.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
