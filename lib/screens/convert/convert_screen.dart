import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/design_tokens.dart';
import '../../models/payment_card.dart';
import '../../models/rate_table.dart';
import '../../providers/convert_providers.dart';
import '../../providers/rate_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../providers/wallet_providers.dart';
import '../../shared/utils/amount_entry.dart';
import '../../shared/utils/conversion.dart';
import '../../shared/utils/money.dart';
import '../../shared/utils/spend_limit.dart';
import '../../shared/widgets/amount_text.dart';
import '../../shared/widgets/pressable.dart';
import '../../shared/widgets/status_view.dart';
import '../../shared/widgets/strata_sheet.dart';
import '../auth/widgets/pin_keypad.dart';
import 'widgets/swap_panels.dart';

/// Move money between two of your own cards, across currencies.
class ConvertScreen extends ConsumerStatefulWidget {
  const ConvertScreen({super.key});

  static const String route = '/convert';

  static const Key swapKey = Key('convert-swap');
  static const Key fromKey = Key('convert-from');
  static const Key toKey = Key('convert-to');
  static const Key confirmKey = Key('convert-confirm');
  static const Key doneKey = Key('convert-done');
  static const Key againKey = Key('convert-again');

  @override
  ConsumerState<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends ConsumerState<ConvertScreen> {
  String? _fromId;
  String? _toId;
  AmountEntry _amount = AmountEntry.empty;

  /// Incremented on every swap, which is what drives the exchange animation.
  int _swapToken = 0;

  ConvertOutcome? _outcome;
  bool _working = false;
  String? _problem;

  List<PaymentCard> get _cards =>
      ref.watch(walletProvider).valueOrNull ?? const [];

  /// The source card: whatever was chosen, else the first in the wallet.
  PaymentCard? get _from {
    final cards = _cards;
    if (cards.isEmpty) return null;
    return cards.where((c) => c.id == _fromId).firstOrNull ?? cards.first;
  }

  /// The destination: whatever was chosen, else the first card that is not
  /// the source.
  ///
  /// Compared against `_from!.id` and not `_fromId`, which is null until
  /// something is picked — filtering on the null would exclude nothing and
  /// open the screen with the same card on both sides, a state it would
  /// then immediately refuse.
  PaymentCard? get _to {
    final cards = _cards;
    if (cards.isEmpty) return null;
    final chosen = cards.where((c) => c.id == _toId).firstOrNull;
    if (chosen != null) return chosen;
    final sourceId = _from?.id;
    return cards.where((c) => c.id != sourceId).firstOrNull ?? cards.first;
  }

  void _swap() {
    final from = _from, to = _to;
    if (from == null || to == null) return;
    setState(() {
      _fromId = to.id;
      _toId = from.id;
      _swapToken++;
      _problem = null;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _pick({required bool isFrom}) async {
    final chosen = await showStrataSheet<String>(
      context,
      builder: (sheetContext) => _CardPickerSheet(
        title: isFrom ? 'Convert from' : 'Convert to',
        cards: _cards,
        selectedId: isFrom ? _from?.id : _to?.id,
        // Picking the card already on the other side is a swap, not an
        // error: it is what the person evidently meant.
        otherId: isFrom ? _to?.id : _from?.id,
      ),
    );
    if (chosen == null || !mounted) return;

    final other = isFrom ? _to?.id : _from?.id;
    if (chosen == other) {
      _swap();
      return;
    }
    setState(() {
      if (isFrom) {
        _fromId = chosen;
      } else {
        _toId = chosen;
      }
      _problem = null;
    });
  }

  /// The source card's monthly-cap position, or null when it has no cap.
  LimitStatus? _limitFor(PaymentCard? card) => card == null
      ? null
      : SpendLimits.statusFor(
          card,
          ref.read(transactionsProvider).valueOrNull ?? const [],
          now: DateTime.now(),
        );

  Future<void> _confirm(RateTable table) async {
    final from = _from, to = _to;
    if (from == null || to == null || _working) return;

    final check = Conversion.check(
      from: from,
      to: to,
      amountMinor: _amount.minor,
      table: table,
      limit: _limitFor(from),
    );
    if (!check.ok) {
      setState(() => _problem = check.reason);
      return;
    }

    setState(() {
      _working = true;
      _problem = null;
    });

    try {
      final outcome = await ref.read(convertServiceProvider).convert(
            ConvertRequest(from: from, to: to, amountMinor: _amount.minor),
            table,
          );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _working = false;
        _outcome = outcome;
      });
    } on ConvertRefused catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _problem = e.reason;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _problem = 'Could not convert that. Nothing has moved.';
      });
    }
  }

  void _pushDigit(String d) => setState(() {
        _amount = _amount.push(d);
        _problem = null;
      });

  void _popDigit() => setState(() {
        _amount = _amount.backspace();
        _problem = null;
      });

  void _again() => setState(() {
        _outcome = null;
        _amount = AmountEntry.empty;
        _problem = null;
      });

  @override
  Widget build(BuildContext context) {
    final rates = ref.watch(rateTableProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Convert')),
      body: SafeArea(
        child: rates.when(
          loading: () => const Center(
            child: SizedBox(
              height: 44,
              width: 44,
              child: CircularProgressIndicator.adaptive(),
            ),
          ),
          error: (_, __) => StatusView(
            icon: Icons.currency_exchange_rounded,
            title: 'Rates are unavailable',
            message: 'We could not read the demo rate table.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(rateTableProvider),
          ),
          data: (table) {
            if (_cards.length < 2) {
              return const StatusView(
                icon: Icons.credit_card_outlined,
                title: 'You need two cards',
                message: 'Converting moves money between two of your own '
                    'cards, so there has to be somewhere to move it to.',
              );
            }
            final outcome = _outcome;
            final from = _from!, to = _to!;
            return outcome == null
                ? _Form(
                    table: table,
                    from: from,
                    to: to,
                    amount: _amount,
                    swapToken: _swapToken,
                    working: _working,
                    problem: _problem,
                    onSwap: _swap,
                    onPickFrom: () => _pick(isFrom: true),
                    onPickTo: () => _pick(isFrom: false),
                    onDigit: _pushDigit,
                    onBackspace: _popDigit,
                    onConfirm: () => _confirm(table),
                    limit: _limitFor(from),
                  )
                : _Done(
                    from: from,
                    to: to,
                    outcome: outcome,
                    onDone: () => Navigator.of(context).maybePop(),
                    onAgain: _again,
                  );
          },
        ),
      ),
    );
  }
}

/// The entry form.
class _Form extends StatelessWidget {
  const _Form({
    required this.table,
    required this.from,
    required this.to,
    required this.amount,
    required this.swapToken,
    required this.working,
    required this.problem,
    required this.onSwap,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onDigit,
    required this.onBackspace,
    required this.onConfirm,
    required this.limit,
  });

  final RateTable table;
  final PaymentCard from;
  final PaymentCard to;
  final AmountEntry amount;
  final int swapToken;
  final bool working;
  final String? problem;
  final VoidCallback onSwap;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onConfirm;
  final LimitStatus? limit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final check = Conversion.check(
      from: from,
      to: to,
      amountMinor: amount.minor,
      table: table,
      limit: limit,
    );
    final q = check.quote;
    // Only complain once something has been typed; an untouched field is
    // not a mistake.
    final failing = !check.ok && !amount.isEmpty;

    // The keypad and the primary action are pinned; only the panels and the
    // breakdown scroll. Leaving the Convert button below a 300dp keypad put
    // it off the bottom of a 390x844 phone, which is a button the thumb
    // cannot find.
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                Space.xl, Space.lg, Space.xl, Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwapPanels(
                  swapToken: swapToken,
                  first: _Panel(
                    panelKey: ConvertScreen.fromKey,
                    label: 'From',
                    card: from,
                    figure: amount.formatted(from.currency),
                    emphasised: true,
                    failing: failing,
                    onTap: onPickFrom,
                  ),
                  second: _Panel(
                    panelKey: ConvertScreen.toKey,
                    label: 'To',
                    card: to,
                    figure: Money.format(q.convertedMinor, to.currency),
                    emphasised: false,
                    failing: false,
                    onTap: onPickTo,
                  ),
                  middle: Pressable(
                    key: ConvertScreen.swapKey,
                    onTap: onSwap,
                    pressedScale: 0.9,
                    semanticLabel: 'Swap the two cards',
                    semanticHint: 'Converts from ${to.displayLabel} to '
                        '${from.displayLabel} instead',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.surfaceContainerHighest,
                        border: Border.all(
                            color: scheme.outlineVariant, width: 1.4),
                      ),
                      child: Icon(Icons.swap_vert_rounded,
                          size: 22, color: scheme.onSurface),
                    ),
                  ),
                ),
                const SizedBox(height: Space.xl),
                _Breakdown(quote: q, table: table),
                if (failing) ...[
                  const SizedBox(height: Space.lg),
                  _Problem(message: check.reason!),
                ] else if (problem != null) ...[
                  const SizedBox(height: Space.lg),
                  _Problem(message: problem!),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PinKeypad(onDigit: onDigit, onBackspace: onBackspace),
              FilledButton(
                key: ConvertScreen.confirmKey,
                // Always pressable: when it cannot proceed it names the
                // reason above rather than going dead.
                onPressed: working ? null : onConfirm,
                child: Text(working ? 'Converting…' : 'Convert'),
              ),
              const SizedBox(height: Space.sm),
              Text(
                // Never present a static table as a live rate.
                'Demo rates are indicative, as of '
                '${DateFormat('d MMMM y').format(table.asOf)}.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One side of the conversion.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.panelKey,
    required this.label,
    required this.card,
    required this.figure,
    required this.emphasised,
    required this.failing,
    required this.onTap,
  });

  final Key panelKey;
  final String label;
  final PaymentCard card;
  final String figure;
  final bool emphasised;
  final bool failing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Pressable(
      key: panelKey,
      onTap: onTap,
      pressedScale: 0.99,
      enforceMinTarget: false,
      semanticLabel: '$label ${card.describedForAccessibility}, '
          '$figure, balance '
          '${Money.format(card.balanceMinor, card.currency)}',
      semanticHint: 'Choose a different card',
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          borderRadius: Radii.brXl,
          color: emphasised
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainer,
          border: Border.all(
            color: failing ? scheme.error : scheme.outlineVariant,
            width: failing ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(label,
                    style: text.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    '${card.displayLabel} · ${card.shortMask}',
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: Space.xs),
                Icon(Icons.unfold_more_rounded,
                    size: 16, color: scheme.onSurfaceVariant),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      figure,
                      style: (emphasised
                              ? text.headlineMedium
                              : text.headlineSmall)
                          ?.copyWith(
                        color: failing ? scheme.error : scheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Text(Money.format(card.balanceMinor, card.currency),
                    style: text.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The rate and the fee, as a breakdown rather than a footnote.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.quote, required this.table});

  final ConversionQuote quote;
  final RateTable table;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        borderRadius: Radii.brXl,
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          _Row(
            label: 'Amount',
            value: Money.format(quote.amountMinor, quote.fromCurrency),
          ),
          if (quote.sameCurrency)
            const _Row(
              label: 'Fee',
              value: 'No fee, same currency',
            )
          else ...[
            _Row(
              label: 'Fee (${(table.feeBps / 100).toStringAsFixed(2)}%)',
              value: Money.format(quote.feeMinor, quote.fromCurrency),
            ),
            _Row(label: 'Rate', value: quote.rateLabel),
          ],
          _Row(
            label: 'You get',
            value: Money.format(quote.convertedMinor, quote.toCurrency),
            emphasised: true,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
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
          children: [
            Text(label,
                style:
                    text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: emphasised ? text.titleSmall : text.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 18, color: scheme.error),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(message,
              style: text.bodySmall?.copyWith(color: scheme.error)),
        ),
      ],
    );
  }
}

/// After the conversion: both new balances, which is what people check.
class _Done extends StatelessWidget {
  const _Done({
    required this.from,
    required this.to,
    required this.outcome,
    required this.onDone,
    required this.onAgain,
  });

  final PaymentCard from;
  final PaymentCard to;
  final ConvertOutcome outcome;
  final VoidCallback onDone;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final q = outcome.quote;

    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(Space.xl, Space.xxl, Space.xl, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
              ),
              child: Icon(Icons.check_rounded,
                  size: 34, color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: Space.xl),
          Center(
            child: AmountText(
              minor: q.convertedMinor,
              currency: q.toCurrency,
              semanticsPrefix: 'Converted to',
            ),
          ),
          const SizedBox(height: Space.xs),
          Center(
            child: Text(
              q.sameCurrency
                  ? 'moved to your ${to.displayLabel} card'
                  : 'now on your ${to.displayLabel} card',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
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
                _Row(
                  label: '${from.displayLabel} now',
                  value: Money.format(outcome.fromBalanceMinor, q.fromCurrency),
                ),
                _Row(
                  label: '${to.displayLabel} now',
                  value: Money.format(outcome.toBalanceMinor, q.toCurrency),
                  emphasised: true,
                ),
                if (!q.sameCurrency) _Row(label: 'Rate', value: q.rateLabel),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          FilledButton(
            key: ConvertScreen.doneKey,
            onPressed: onDone,
            child: const Text('Done'),
          ),
          const SizedBox(height: Space.md),
          OutlinedButton(
            key: ConvertScreen.againKey,
            onPressed: onAgain,
            child: const Text('Convert again'),
          ),
        ],
      ),
    );
  }
}

/// Choose the card for one side.
class _CardPickerSheet extends StatelessWidget {
  const _CardPickerSheet({
    required this.title,
    required this.cards,
    required this.selectedId,
    required this.otherId,
  });

  final String title;
  final List<PaymentCard> cards;
  final String? selectedId;

  /// The card on the other side. Still offered — picking it swaps the two,
  /// which is what the person evidently meant — but labelled.
  final String? otherId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return StrataSheet(
      icon: Icons.credit_card_rounded,
      title: title,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in cards)
            Pressable(
              onTap: () => Navigator.of(context).pop(c.id),
              pressedScale: 0.99,
              enforceMinTarget: false,
              semanticLabel: c.describedForAccessibility,
              semanticHint: c.id == otherId
                  ? 'Swaps the two sides'
                  : 'Balance '
                      '${Money.format(c.balanceMinor, c.currency)}',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.md),
                child: Row(
                  children: [
                    Icon(
                      c.id == selectedId
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      size: 20,
                      color:
                          c.id == selectedId ? scheme.primary : scheme.outline,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${c.displayLabel} · ${c.shortMask}',
                              style: text.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(
                            c.frozen
                                ? 'Frozen. Unfreeze it first'
                                : c.id == otherId
                                    ? 'On the other side. Picking it '
                                        'swaps them'
                                    : '${Money.format(c.balanceMinor, c.currency)}'
                                        ' · ${c.currency}',
                            style: text.bodySmall?.copyWith(
                              color: c.frozen ? scheme.error : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
