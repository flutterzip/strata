import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../models/payment_card.dart';
import '../../../models/transaction.dart';
import '../../../providers/transaction_providers.dart';
import '../../../providers/wallet_providers.dart';
import '../../../shared/utils/ids.dart';
import '../../../shared/utils/money.dart';
import '../../../shared/widgets/segmented_toggle.dart';
import '../../../shared/widgets/select_row.dart';
import '../../../shared/widgets/settings_row.dart';
import '../../../shared/widgets/strata_sheet.dart';
import '../transactions_screen.dart';

/// Record a transaction, or change one.
///
/// One sheet for both: the fields are the same, and two near-identical forms
/// is how they drift apart. [existing] null means create.
class TransactionEditSheet extends ConsumerStatefulWidget {
  const TransactionEditSheet({super.key, this.existing});

  final Transaction? existing;

  static const Key cardRow = Key('txn-card-row');
  static const Key kindRow = Key('txn-kind-row');
  static const Key categoryRow = Key('txn-category-row');

  @override
  ConsumerState<TransactionEditSheet> createState() =>
      _TransactionEditSheetState();
}

class _TransactionEditSheetState extends ConsumerState<TransactionEditSheet> {
  late final _merchant =
      TextEditingController(text: widget.existing?.merchant ?? '');
  late final _category =
      TextEditingController(text: widget.existing?.category ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : (widget.existing!.amountMinor.abs() / 100).toStringAsFixed(2),
  );

  late String? _cardId = widget.existing?.cardId;
  late TxnKind _kind = widget.existing?.kind ?? TxnKind.payment;
  late bool _moneyOut = widget.existing?.isMoneyOut ?? true;
  late DateTime _when = widget.existing?.occurredAt ?? DateTime.now();

  /// The first failing field, shown under the form. The save button stays
  /// pressable — a dead control that explains nothing is the one thing this
  /// app's interaction rules forbid.
  String? _problem;
  bool _saving = false;

  /// Whether the free-text category field is showing. True from the start
  /// when editing a transaction whose category is not one of the existing
  /// ones, so it stays correctable.
  bool _typingCategory = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_merchant, _category, _note, _amount]) {
      c.dispose();
    }
    super.dispose();
  }

  List<PaymentCard> get _cards =>
      ref.read(walletProvider).valueOrNull ?? const [];

  PaymentCard? get _card {
    final cards = _cards;
    if (cards.isEmpty) return null;
    return cards.firstWhere((c) => c.id == _cardId, orElse: () => cards.first);
  }

  /// Minor units from what was typed, or null when it is not a number.
  int? _parsedMinor() {
    final cleaned = _amount.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    return (value * 100).round();
  }

  Future<void> _chooseCard(List<PaymentCard> cards) async {
    final result = await showSelectSheet<String>(
      context,
      title: 'Card',
      icon: Icons.credit_card_rounded,
      selected: _card?.id,
      options: [
        for (final c in cards)
          SelectOption(
            value: c.id,
            label: c.displayLabel,
            detail: '${c.shortMask} · '
                '${Money.format(c.balanceMinor, c.currency)}',
            semanticLabel: c.describedForAccessibility,
          ),
      ],
    );
    if (!mounted) return;
    if (result case SelectValue(value: final id)) {
      setState(() => _cardId = id);
    }
  }

  Future<void> _chooseKind() async {
    final result = await showSelectSheet<TxnKind>(
      context,
      title: 'Kind',
      icon: Icons.category_outlined,
      selected: _kind,
      options: [
        for (final k in TxnKind.values) SelectOption(value: k, label: k.label),
      ],
    );
    if (!mounted) return;
    if (result case SelectValue(value: final k)) {
      setState(() => _kind = k);
    }
  }

  Future<void> _chooseCategory(List<String> suggestions) async {
    final current = _category.text.trim();
    final result = await showSelectSheet<String>(
      context,
      title: 'Category',
      icon: Icons.sell_outlined,
      selected: current.isEmpty ? null : current,
      options: [
        const SelectOption(value: '', label: 'Uncategorised'),
        for (final s in suggestions)
          SelectOption(
            value: s,
            label: s,
            startsGroup: s == suggestions.first,
            semanticLabel: 'Use the $s category',
          ),
      ],
      customLabel: 'New category…',
    );
    if (result == null || !mounted) return;

    setState(() {
      switch (result) {
        case SelectValue(value: final c):
          _category.text = c;
          _typingCategory = false;
        case SelectCustom():
          _category.clear();
          _typingCategory = true;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(_when.year - 5),
      // No future-dating: a transaction is something that happened.
      lastDate: DateTime.now(),
      helpText: 'When did this happen?',
    );
    if (picked != null && mounted) {
      setState(() => _when = DateTime(
          picked.year, picked.month, picked.day, _when.hour, _when.minute));
    }
  }

  Future<void> _save() async {
    final merchant = _merchant.text.trim();
    final minor = _parsedMinor();
    final card = _card;

    if (merchant.isEmpty) {
      setState(() => _problem = 'Enter who was paid');
      return;
    }
    if (minor == null || minor == 0) {
      setState(() => _problem = 'Enter an amount');
      return;
    }
    if (card == null) {
      setState(() => _problem = 'Add a card before recording a transaction');
      return;
    }

    setState(() {
      _problem = null;
      _saving = true;
    });

    final signed = _moneyOut ? -minor : minor;
    final category =
        _category.text.trim().isEmpty ? 'Uncategorised' : _category.text.trim();
    final note = _note.text.trim();

    try {
      final notifier = ref.read(transactionsProvider.notifier);
      if (_isEdit) {
        await notifier.edit(
          widget.existing!.id,
          (t) => t.copyWith(
            cardId: card.id,
            kind: _kind,
            merchant: merchant,
            category: category,
            amountMinor: signed,
            currency: card.currency,
            occurredAt: _when,
            note: note.isEmpty ? null : note,
            clearNote: note.isEmpty,
          ),
        );
      } else {
        await notifier.create(Transaction(
          id: Ids.next('t'),
          cardId: card.id,
          kind: _kind,
          merchant: merchant,
          category: category,
          amountMinor: signed,
          currency: card.currency,
          occurredAt: _when,
          note: note.isEmpty ? null : note,
        ));
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      // The optimistic update has already been rolled back by the notifier;
      // the sheet stays open so the entry is not lost.
      setState(() {
        _saving = false;
        _problem = 'Could not save. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cards = _cards;
    final suggestions = ref.watch(txnCategoriesProvider);
    final currency = _card?.currency ?? 'USD';

    return StrataSheet(
      icon: _isEdit ? Icons.edit_outlined : Icons.add_rounded,
      title: _isEdit ? 'Edit transaction' : 'Record a transaction',
      message: _isEdit
          ? null
          : 'For the demo this only writes history. It does not move money.',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label('Money'),
          // Two symmetrical choices, which is what SegmentedToggle is for.
          SegmentedToggle(
            segments: const [
              (icon: Icons.north_east_rounded, label: 'Out'),
              (icon: Icons.south_west_rounded, label: 'In'),
            ],
            index: _moneyOut ? 0 : 1,
            onChanged: (i) => setState(() => _moneyOut = i == 0),
          ),
          const SizedBox(height: Space.lg),
          const _Label('Who'),
          TextField(
            key: TransactionsScreen.merchantKey,
            controller: _merchant,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Blue Bottle Coffee'),
          ),
          const SizedBox(height: Space.lg),
          const _Label('Amount'),
          TextField(
            key: TransactionsScreen.amountKey,
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              hintText: '0.00',
              prefixText: '${Money.symbol(currency)} ',
            ),
          ),
          const SizedBox(height: Space.lg),
          // Three wraps of pills became three rows. The category was a text
          // field *and* a wrap of suggestions — two controls for one value,
          // with nothing saying which was in force.
          SettingsGroup(
            children: [
              if (cards.length > 1)
                SelectRow(
                  key: TransactionEditSheet.cardRow,
                  label: 'Card',
                  value: _card == null
                      ? 'Pick a card'
                      : '${_card!.displayLabel} ${_card!.shortMask}',
                  placeholder: _card == null,
                  onTap: () => _chooseCard(cards),
                ),
              SelectRow(
                key: TransactionEditSheet.kindRow,
                label: 'Kind',
                value: _kind.label,
                onTap: _chooseKind,
              ),
              SelectRow(
                key: TransactionEditSheet.categoryRow,
                label: 'Category',
                value: _category.text.trim().isEmpty
                    ? 'Uncategorised'
                    : _category.text.trim(),
                placeholder: _category.text.trim().isEmpty,
                onTap: () => _chooseCategory(suggestions),
              ),
            ],
          ),
          if (_typingCategory) ...[
            const SizedBox(height: Space.lg),
            TextField(
              key: TransactionsScreen.categoryKey,
              controller: _category,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'New category',
                hintText: 'Groceries',
              ),
            ),
          ],
          const SizedBox(height: Space.lg),
          const _Label('When'),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined, size: 18),
            label:
                Text(MaterialLocalizations.of(context).formatFullDate(_when)),
          ),
          const SizedBox(height: Space.lg),
          const _Label('Note'),
          TextField(
            key: TransactionsScreen.noteKey,
            controller: _note,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                hintText: 'Anything you want to remember'),
          ),
          if (_problem != null) ...[
            const SizedBox(height: Space.lg),
            // Ochre with an icon and words — never colour alone.
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
          key: TransactionsScreen.saveKey,
          onPressed: _saving ? null : _save,
          child: Text(_saving
              ? 'Saving…'
              : _isEdit
                  ? 'Save changes'
                  : 'Record it'),
        ),
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.sm),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
}
