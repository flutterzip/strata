import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/design_tokens.dart';
import '../../../config/motion.dart';
import '../../../models/payment_card.dart';
import '../../../shared/utils/money.dart';

/// The "Card info" panel beneath the carousel.
///
/// Rendered once per card and cross-faded by [OffsetBound], so it tracks the
/// drag rather than swapping at the end of it.
class CardDetailBlock extends StatelessWidget {
  const CardDetailBlock({super.key, required this.card});

  final PaymentCard card;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Scrollable because the block sits in a fixed-height slot (it is
    // cross-faded against its neighbours, which needs a bounded height). At
    // the normal text scale nothing scrolls; at the top of the clamped range
    // it degrades to a short scroll instead of an overflow.
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Card info', style: text.titleMedium),
          const SizedBox(height: Space.md),
          _InfoRow(
            label: 'Card number',
            value: card.maskedNumber,
            copyValue: card.last4,
            copyLabel: 'Last four digits',
          ),
          const Divider(height: Space.xxl),
          Row(
            children: [
              Expanded(
                child: _InfoRow(label: 'Expires', value: card.expiryLabel),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: _InfoRow(label: 'Network', value: card.brand.label),
              ),
            ],
          ),
          const Divider(height: Space.xxl),
          _InfoRow(label: 'Cardholder', value: card.holder),
          const Divider(height: Space.xxl),
          // Paired on one line so the block's height does not change with
          // whether a limit is set — it is cross-faded inside a fixed slot.
          Row(
            children: [
              Expanded(
                child: _InfoRow(
                  label: 'Status',
                  value: card.frozen ? 'Frozen' : 'Active',
                ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: _InfoRow(
                  label: 'Monthly limit',
                  value: card.hasSpendLimit
                      ? Money.format(card.spendLimitMinor!, card.currency)
                      : 'None',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.copyValue,
    this.copyLabel,
  });

  final String label, value;
  final String? copyValue, copyLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: text.bodySmall),
                const SizedBox(height: 2),
                Text(value,
                    style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600, letterSpacing: 0.3)),
              ],
            ),
          ),
        ),
        if (copyValue != null)
          IconButton(
            tooltip: 'Copy ${copyLabel ?? label}',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: copyValue!));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                  content: Text('${copyLabel ?? label} copied'),
                  duration: Motion.slow * 4,
                ));
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
      ],
    );
  }
}
