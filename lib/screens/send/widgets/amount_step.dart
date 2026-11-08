import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';
import '../../../models/payment_card.dart';
import '../../../models/recipient.dart';
import '../../../shared/utils/amount_entry.dart';
import '../../../shared/utils/money.dart';
import '../../../shared/utils/send_rules.dart';
import '../../../shared/widgets/avatar_circle.dart';
import '../../../shared/widgets/select_row.dart';
import '../../../shared/widgets/settings_row.dart';
import '../../auth/widgets/pin_keypad.dart';

/// Step two: how much, and from which card.
///
/// Digits come from [PinKeypad] rather than the system keyboard — the same
/// pad the PIN screen uses — so the flow never hands a money field to
/// autocorrect, and there is no decimal point to mistype. Typing 4, 2, 5, 0
/// means 42.50, as on every card terminal.
class AmountStep extends StatelessWidget {
  const AmountStep({
    super.key,
    required this.amount,
    required this.card,
    required this.cards,
    required this.recipient,
    required this.check,
    required this.onDigit,
    required this.onBackspace,
    required this.onCard,
  });

  final AmountEntry amount;
  final PaymentCard? card;
  final List<PaymentCard> cards;
  final Recipient recipient;
  final SendCheck check;

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final ValueChanged<String> onCard;

  static const Key fromRow = Key('send-from');

  /// Which card the money leaves. Frozen cards stay pickable and explain
  /// themselves — a control that is simply gone cannot say why.
  Future<void> _chooseCard(BuildContext context) async {
    final result = await showSelectSheet<String>(
      context,
      title: 'Send from',
      icon: Icons.credit_card_rounded,
      selected: card?.id,
      options: [
        for (final c in cards)
          SelectOption(
            value: c.id,
            label: c.displayLabel,
            detail: c.frozen
                ? '${c.shortMask} · Frozen, cannot send'
                : '${c.shortMask} · ${Money.format(c.balanceMinor, c.currency)}'
                    ' available',
            icon: c.frozen ? Icons.ac_unit_rounded : null,
            semanticLabel: '${c.describedForAccessibility}, '
                '${Money.format(c.balanceMinor, c.currency)} available',
          ),
      ],
    );
    if (result case SelectValue(value: final id)) onCard(id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final currency = card?.currency ?? 'USD';
    // Only warn once something has actually been typed; an untouched field
    // is not a mistake.
    final failing = !check.ok && !amount.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Row(
              children: [
                AvatarCircle(
                  initials: recipient.initials,
                  avatar: recipient.avatar,
                  size: AvatarSize.row,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('To ${recipient.name}',
                          style: text.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(recipient.handle, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          Semantics(
            label: 'Sending ${amount.formatted(currency)}',
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  amount.formatted(currency),
                  style: text.displayMedium?.copyWith(
                    // Ink until it is wrong, then ochre — the one error hue,
                    // and never on its own.
                    color: failing ? scheme.error : scheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          _BalanceLine(card: card, check: check, failing: failing),
          const SizedBox(height: Space.xl),
          if (cards.length > 1) ...[
            // A row, not a horizontally scrolling strip of pills: in the
            // strip every card past the right edge was invisible, so a
            // wallet of six looked like a wallet of two.
            SettingsGroup(
              children: [
                SelectRow(
                  key: AmountStep.fromRow,
                  label: 'From',
                  value: card == null
                      ? 'Pick a card'
                      : '${card!.displayLabel} ${card!.shortMask}',
                  detail: card == null
                      ? null
                      : card!.frozen
                          ? 'Frozen'
                          : '${Money.format(card!.balanceMinor, card!.currency)}'
                              ' available',
                  // Named before it is chosen, not only after it is refused.
                  icon: card?.frozen == true ? Icons.ac_unit_rounded : null,
                  placeholder: card == null,
                  onTap: () => _chooseCard(context),
                ),
              ],
            ),
            const SizedBox(height: Space.xl),
          ],
          PinKeypad(onDigit: onDigit, onBackspace: onBackspace),
        ],
      ),
    );
  }
}

/// What this leaves behind, or why it cannot happen.
///
/// Shown while typing rather than only on the review step: the resulting
/// balance is the number that decides whether the amount is right, and
/// finding out one screen later is a wasted trip.
class _BalanceLine extends StatelessWidget {
  const _BalanceLine({
    required this.card,
    required this.check,
    required this.failing,
  });

  final PaymentCard? card;
  final SendCheck check;
  final bool failing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final c = card;
    if (c == null) return const SizedBox.shrink();

    if (failing) {
      return MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 16, color: scheme.error),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(check.reason ?? '',
                  style: text.bodySmall?.copyWith(color: scheme.error)),
            ),
          ],
        ),
      );
    }

    return Text(
      '${Money.format(c.balanceMinor, c.currency)} available · '
      '${Money.format(check.resultingBalanceMinor, c.currency)} left after',
      textAlign: TextAlign.center,
      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    );
  }
}
