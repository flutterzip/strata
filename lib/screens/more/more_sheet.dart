import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/design_tokens.dart';
import '../../models/payment_card.dart';
import '../../providers/transaction_providers.dart';
import '../../providers/wallet_providers.dart';
import '../../shared/utils/money.dart';
import '../../shared/utils/spend_limit.dart';
import '../../shared/widgets/select_row.dart';
import '../../shared/widgets/settings_row.dart';
import '../../shared/widgets/strata_sheet.dart';
import 'widgets/spend_limit_sheet.dart';
import 'widgets/statements_sheet.dart';
import 'widgets/support_sheet.dart';

/// Keys for the secondary actions, in one place.
abstract final class MoreKeys {
  static const Key freeze = Key('more-freeze');
  static const Key statements = Key('more-statements');
  static const Key limits = Key('more-limits');
  static const Key support = Key('more-support');
  static const Key cardRow = Key('more-card');
}

/// The secondary actions for one card.
///
/// Was a dead tile. Everything on it now does something real: freezing is a
/// stored state on the card that the money flows check, statements and the
/// limit meter are derived from transactions, and support is information,
/// which is the whole of what support can be in a template.
class MoreSheet extends ConsumerStatefulWidget {
  const MoreSheet({super.key, this.cardId});

  /// Which card to act on. Defaults to the one the carousel is showing.
  final String? cardId;

  @override
  ConsumerState<MoreSheet> createState() => _MoreSheetState();
}

class _MoreSheetState extends ConsumerState<MoreSheet> {
  String? _cardId;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _cardId = widget.cardId;
  }

  PaymentCard? get _card {
    final cards = ref.watch(walletProvider).valueOrNull ?? const [];
    if (cards.isEmpty) return null;
    if (_cardId != null) {
      final found = cards.where((c) => c.id == _cardId).firstOrNull;
      if (found != null) return found;
    }
    final focused = ref.read(focusedCardIndexProvider);
    return cards[focused.clamp(0, cards.length - 1)];
  }

  /// Which card everything on this sheet acts on.
  Future<void> _chooseCard(List<PaymentCard> cards, PaymentCard current) async {
    final result = await showSelectSheet<String>(
      context,
      title: 'Card',
      message: 'Freezing, limits and statements all act on the card you '
          'pick here.',
      icon: Icons.credit_card_rounded,
      selected: current.id,
      options: [
        for (final c in cards)
          SelectOption(
            value: c.id,
            label: c.displayLabel,
            // Balance and frozen state before the choice, not after it.
            detail: c.frozen
                ? '${c.shortMask} · Frozen'
                : '${c.shortMask} · ${Money.format(c.balanceMinor, c.currency)}',
            icon: c.frozen ? Icons.ac_unit_rounded : null,
            semanticLabel: c.describedForAccessibility,
          ),
      ],
    );
    if (result == null || !mounted) return;
    if (result case SelectValue(value: final id)) {
      setState(() => _cardId = id);
    }
  }

  Future<void> _toggleFreeze(PaymentCard card) async {
    // Freezing is immediate; unfreezing is the one that is worth a
    // confirmation, because it is the step that makes the card spendable
    // again.
    if (card.frozen) {
      final ok = await confirmAction(
        context,
        icon: Icons.lock_open_rounded,
        title: 'Unfreeze this card?',
        message: '${card.displayLabel} will be able to make payments and '
            'transfers again straight away.',
        confirmLabel: 'Unfreeze it',
      );
      if (!ok || !mounted) return;
    }

    setState(() => _working = true);
    try {
      await ref
          .read(walletProvider.notifier)
          .edit(card.id, (c) => c.copyWith(frozen: !c.frozen));
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(card.frozen
            ? '${card.displayLabel} unfrozen'
            : '${card.displayLabel} frozen'),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not change that. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(walletProvider).valueOrNull ?? const [];
    final card = _card;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (card == null) {
      return const StrataSheet(
        icon: Icons.more_horiz_rounded,
        title: 'More',
        message: 'Add a card first. Everything here works on a card.',
      );
    }

    final txns = ref.watch(transactionsProvider).valueOrNull ?? const [];
    final limit = SpendLimits.statusFor(card, txns, now: DateTime.now());

    return StrataSheet(
      icon: Icons.more_horiz_rounded,
      title: 'More',
      message: '${card.displayLabel} · ${card.shortMask}',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cards.length > 1) ...[
            SettingsGroup(
              children: [
                SelectRow(
                  key: MoreKeys.cardRow,
                  label: 'Card',
                  value: '${card.displayLabel} ${card.shortMask}',
                  detail: Money.format(card.balanceMinor, card.currency),
                  icon: card.frozen ? Icons.ac_unit_rounded : null,
                  onTap: () => _chooseCard(cards, card),
                ),
              ],
            ),
            const SizedBox(height: Space.xl),
          ],
          if (card.frozen) ...[
            Container(
              padding: const EdgeInsets.all(Space.md),
              decoration: BoxDecoration(
                borderRadius: Radii.brMd,
                color: scheme.surfaceContainerHigh,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.ac_unit_rounded,
                      size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      'This card is frozen. Payments, transfers and '
                      'conversions are all blocked until you unfreeze it.',
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.lg),
          ],
          SettingsGroup(
            title: 'This card',
            children: [
              SettingsRow(
                key: MoreKeys.freeze,
                icon: card.frozen
                    ? Icons.lock_open_rounded
                    : Icons.ac_unit_rounded,
                title: card.frozen ? 'Unfreeze card' : 'Freeze card',
                subtitle: card.frozen
                    ? 'Let this card be used again'
                    : 'Block payments without cancelling the card',
                onTap: _working ? null : () => _toggleFreeze(card),
              ),
              SettingsRow(
                key: MoreKeys.limits,
                icon: Icons.speed_rounded,
                title: 'Spending limit',
                subtitle: limit == null
                    ? 'No monthly limit set'
                    : '${Money.format(limit.spentMinor, card.currency)} of '
                        '${Money.format(limit.limitMinor, card.currency)} '
                        'this month',
                onTap: () => showStrataSheet<void>(
                  context,
                  builder: (_) => SpendLimitSheet(cardId: card.id),
                ),
              ),
              SettingsRow(
                key: MoreKeys.statements,
                icon: Icons.description_outlined,
                title: 'Statements',
                subtitle: 'Month by month, from your activity',
                onTap: () => showStrataSheet<void>(
                  context,
                  builder: (_) => StatementsSheet(cardId: card.id),
                ),
              ),
              SettingsRow(
                key: MoreKeys.support,
                icon: Icons.support_agent_rounded,
                title: 'Support',
                subtitle: 'Lost card, a payment you do not recognise',
                onTap: () => showStrataSheet<void>(
                  context,
                  builder: (_) => SupportSheet(card: card),
                ),
              ),
            ],
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
