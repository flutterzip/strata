import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';
import '../../../models/payment_card.dart';
import '../../../models/transaction.dart';
import '../../../shared/widgets/pressable.dart';

/// Icon for a kind of movement.
///
/// Drawn from the neutral icon set and never from a payment network's mark —
/// networks are named in text in this app, never reproduced as logos.
IconData iconForTxnKind(TxnKind kind) => switch (kind) {
      TxnKind.payment => Icons.receipt_long_rounded,
      TxnKind.transfer => Icons.north_east_rounded,
      TxnKind.refund => Icons.south_west_rounded,
      TxnKind.topUp => Icons.add_rounded,
      TxnKind.conversion => Icons.swap_horiz_rounded,
    };

/// One transaction in the list.
///
/// The whole row is one semantics node: a screen reader should say
/// "Blue Bottle, paid $4.75, Food" once, not read a merchant, a category and
/// a signed number as three unrelated fragments.
class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.txn,
    this.card,
    this.onTap,
  });

  final Transaction txn;

  /// The card this moved on, when it is still in the wallet. A transaction
  /// outlives the card being removed, so this is allowed to be null.
  final PaymentCard? card;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final subtitle = card == null
        ? '${txn.categoryLabel} · ${txn.kind.label}'
        : '${txn.categoryLabel} · ${card!.shortMask}';

    return Semantics(
      button: onTap != null,
      label: txn.describedForAccessibility,
      hint: onTap == null ? null : 'Opens the full transaction',
      child: ExcludeSemantics(
        child: Pressable(
          onTap: onTap,
          pressedScale: 0.985,
          enforceMinTarget: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: Radii.brMd,
                    color: scheme.surfaceContainerHigh,
                  ),
                  child: Icon(iconForTxnKind(txn.kind),
                      size: 19, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        txn.merchant,
                        style: text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Space.xxs),
                      Text(
                        subtitle,
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                Text(
                  txn.amountLabel,
                  style: text.titleSmall?.copyWith(
                    // Money in gets the accent; money out is ink. Weight and
                    // sign do the rest of the work, so no second hue.
                    color: txn.isMoneyOut ? scheme.onSurface : scheme.primary,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
