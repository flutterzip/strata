import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../config/motion.dart';
import '../../../providers/transaction_providers.dart';
import '../../../providers/wallet_providers.dart';
import '../../../shared/utils/money.dart';
import '../../../shared/utils/spend_limit.dart';
import '../../../shared/widgets/select_row.dart';
import '../../../shared/widgets/settings_row.dart';
import '../../../shared/widgets/strata_sheet.dart';

/// Set or remove a card's monthly spending cap.
///
/// The figure spent is read from transactions, never stored alongside the
/// limit: a second tally is a second thing to drift out of step with the
/// list people can see.
class SpendLimitSheet extends ConsumerStatefulWidget {
  const SpendLimitSheet({super.key, required this.cardId});

  final String cardId;

  static const Key field = Key('limit-field');
  static const Key save = Key('limit-save');
  static const Key remove = Key('limit-remove');
  static const Key limitRow = Key('limit-row');

  @override
  ConsumerState<SpendLimitSheet> createState() => _SpendLimitSheetState();
}

class _SpendLimitSheetState extends ConsumerState<SpendLimitSheet> {
  final _amount = TextEditingController();
  String? _problem;
  bool _working = false;
  bool _seeded = false;

  /// Whether the free-text field is showing. True from the start for a limit
  /// that is not one of the presets.
  bool _custom = false;

  /// The presets, ascending. Order is fixed; the picker never reorders
  /// around the current choice.
  static const List<int> _presets = [25000, 50000, 100000, 250000];

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? _parsed() {
    final cleaned = _amount.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    return (value * 100).round();
  }

  Future<void> _chooseLimit(String currency) async {
    final result = await showSelectSheet<int>(
      context,
      title: 'Monthly limit',
      message: 'Spending on this card is blocked once the month\'s payments '
          'reach the limit.',
      icon: Icons.speed_rounded,
      selected: _parsed(),
      options: [
        for (final preset in _presets)
          SelectOption(
            value: preset,
            label: Money.format(preset, currency),
            semanticLabel: 'Set the limit to ${Money.format(preset, currency)}',
          ),
      ],
      customLabel: 'Custom amount…',
    );
    if (result == null || !mounted) return;

    setState(() {
      _problem = null;
      switch (result) {
        case SelectValue(value: final minor):
          _amount.text = (minor / 100).toStringAsFixed(2);
          _custom = false;
        case SelectCustom():
          _custom = true;
      }
    });
  }

  Future<void> _apply({required bool removing}) async {
    final minor = removing ? null : _parsed();
    if (!removing && (minor == null || minor <= 0)) {
      setState(() => _problem = 'Enter a monthly limit, for example 500.');
      return;
    }

    setState(() {
      _problem = null;
      _working = true;
    });
    try {
      await ref.read(walletProvider.notifier).edit(
            widget.cardId,
            (c) => removing
                ? c.copyWith(clearSpendLimit: true)
                : c.copyWith(spendLimitMinor: minor),
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _problem = 'Could not save that. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cards = ref.watch(walletProvider).valueOrNull ?? const [];
    final card = cards.where((c) => c.id == widget.cardId).firstOrNull;

    if (card == null) {
      return const StrataSheet(
        title: 'Card removed',
        message: 'That card is no longer in your wallet.',
      );
    }

    // Prefill once, not on every rebuild, or typing would be overwritten.
    if (!_seeded) {
      _seeded = true;
      if (card.hasSpendLimit) {
        _amount.text = (card.spendLimitMinor! / 100).toStringAsFixed(2);
        // A stored limit the presets do not cover has to stay editable, or
        // the only way to adjust it is to retype it from scratch.
        _custom = !_presets.contains(card.spendLimitMinor);
      }
    }

    final txns = ref.watch(transactionsProvider).valueOrNull ?? const [];
    final spent =
        SpendLimits.spentThisMonth(txns, card.id, now: DateTime.now());
    final status = SpendLimits.statusFor(card, txns, now: DateTime.now());

    return StrataSheet(
      icon: Icons.speed_rounded,
      title: 'Spending limit',
      message: 'A cap on what can leave this card each calendar month. '
          'Sends and conversions check it before they go through.',
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
                Text(
                  status == null
                      ? '${Money.format(spent, card.currency)} spent this '
                          'month'
                      : '${Money.format(status.spentMinor, card.currency)} '
                          'of ${Money.format(status.limitMinor, card.currency)}'
                          ' this month',
                  style: text.titleSmall,
                ),
                if (status != null) ...[
                  const SizedBox(height: Space.md),
                  Semantics(
                    label: '${(status.fraction * 100).round()} percent of the '
                        'monthly limit used',
                    child: ExcludeSemantics(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: status.fraction),
                        duration: context.motion(Motion.slow),
                        curve: Motion.standard,
                        builder: (context, t, _) => ClipRRect(
                          borderRadius: Radii.brPill,
                          child: SizedBox(
                            height: 8,
                            child: Row(
                              // Without stretch a childless ColoredBox in a
                              // Row collapses to zero height.
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: (t * 1000).round().clamp(0, 1000),
                                  child: ColoredBox(
                                    // Ochre once it is spent, the accent
                                    // until then. One hue either way.
                                    color: status.exceeded
                                        ? scheme.error
                                        : scheme.primary,
                                  ),
                                ),
                                Expanded(
                                  flex: (1000 - (t * 1000).round())
                                      .clamp(0, 1000),
                                  child: ColoredBox(
                                      color: scheme.surfaceContainerHighest),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    status.exceeded
                        ? 'The limit is used up for this month.'
                        : '${Money.format(status.remainingMinor, card.currency)}'
                            ' left this month',
                    style: text.bodySmall?.copyWith(
                      color: status.exceeded
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          // One control for one value. This was a text field with a ragged
          // wrap of preset pills under it — two ways to set the same number,
          // neither of them saying which one was in force.
          SettingsGroup(
            children: [
              SelectRow(
                key: SpendLimitSheet.limitRow,
                label: 'Monthly limit',
                value: _parsed() == null
                    ? 'No limit'
                    : Money.format(_parsed()!, card.currency),
                placeholder: _parsed() == null,
                onTap: () => _chooseLimit(card.currency),
              ),
            ],
          ),
          // Revealed by "Custom amount…", and kept visible for a limit that
          // is not one of the presets, so the figure can be corrected
          // without going back through the picker.
          if (_custom) ...[
            const SizedBox(height: Space.lg),
            TextField(
              key: SpendLimitSheet.field,
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Monthly limit',
                hintText: '500.00',
                prefixText: '${Money.symbol(card.currency)} ',
              ),
            ),
          ],
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
          key: SpendLimitSheet.save,
          onPressed: _working ? null : () => _apply(removing: false),
          child: Text(_working ? 'Saving…' : 'Set limit'),
        ),
        if (card.hasSpendLimit)
          OutlinedButton(
            key: SpendLimitSheet.remove,
            onPressed: _working ? null : () => _apply(removing: true),
            child: const Text('Remove limit'),
          ),
        TextButton(
          onPressed: _working ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
