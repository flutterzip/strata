import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../models/transaction.dart';
import '../../../providers/transaction_providers.dart';
import '../../../providers/wallet_providers.dart';
import '../../../shared/utils/txn_grouping.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../../shared/widgets/strata_sheet.dart';
import '../transactions_screen.dart';
import 'transaction_row.dart';

/// What the sheet asked for when it closed.
enum TxnDetailResult { edit, delete }

/// One transaction, in full.
///
/// Reads the record back out of the provider by id rather than taking a
/// snapshot, so an edit made from here is reflected the moment it lands and
/// the sheet cannot sit there showing a stale amount.
class TransactionDetailSheet extends ConsumerWidget {
  const TransactionDetailSheet({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(transactionsProvider).valueOrNull ?? const [];
    final txn = all.where((t) => t.id == id).firstOrNull;

    // Deleted from under us — close rather than render half a record.
    if (txn == null) {
      return const StrataSheet(
        title: 'Transaction removed',
        message: 'This transaction is no longer in your history.',
      );
    }

    final cards = ref.watch(walletProvider).valueOrNull ?? const [];
    final card = cards.where((c) => c.id == txn.cardId).firstOrNull;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return StrataSheet(
      icon: iconForTxnKind(txn.kind),
      title: txn.merchant,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AmountText(
            minor: txn.amountMinor,
            currency: txn.currency,
            style: text.headlineLarge?.copyWith(
              color: txn.isMoneyOut ? scheme.onSurface : scheme.primary,
            ),
            semanticsPrefix: txn.isMoneyOut ? 'Paid' : 'Received',
          ),
          const SizedBox(height: Space.xl),
          _DetailRow(
            label: 'When',
            value: '${TxnGrouping.dayLabel(txn.occurredAt)} · '
                '${TimeOfDay.fromDateTime(txn.occurredAt).format(context)}',
          ),
          _DetailRow(label: 'Kind', value: txn.kind.label),
          _DetailRow(
            label: 'Card',
            value: card == null
                ? 'No longer in your wallet'
                : '${card.displayLabel} · ${card.shortMask}',
          ),
          _DetailRow(label: 'Category', value: txn.categoryLabel),
          _DetailRow(
            label: 'Note',
            value: txn.note ?? 'No note',
            muted: txn.note == null,
          ),
          if (txn.receipt != null) ...[
            const SizedBox(height: Space.md),
            _Receipt(txn: txn),
          ],
        ],
      ),
      actions: [
        FilledButton.icon(
          key: TransactionsScreen.editKey,
          onPressed: () => Navigator.of(context).pop(TxnDetailResult.edit),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
        ),
        OutlinedButton.icon(
          key: TransactionsScreen.deleteKey,
          onPressed: () => Navigator.of(context).pop(TxnDetailResult.delete),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Delete'),
          style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(label,
                  style:
                      text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(
                value,
                style: text.bodyMedium?.copyWith(
                  color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
                  fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The receipt, when one is attached.
///
/// A missing file is normal — a record outlives its media through a restored
/// backup or cleared storage — so this falls back to a drawn placeholder
/// rather than a broken image box.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.txn});

  final Transaction txn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<ImageProvider?>(
      future: txn.receipt!.imageProvider(),
      builder: (context, snapshot) {
        final provider = snapshot.data;
        return Semantics(
          label: provider == null
              ? 'Receipt image is missing'
              : 'Receipt for ${txn.merchant}',
          image: true,
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: Radii.brLg,
              child: Container(
                height: 160,
                color: scheme.surfaceContainerHigh,
                alignment: Alignment.center,
                child: provider == null
                    ? Icon(Icons.receipt_long_outlined,
                        color: scheme.onSurfaceVariant)
                    : Image(
                        image: provider,
                        fit: BoxFit.cover,
                        width: double.infinity),
              ),
            ),
          ),
        );
      },
    );
  }
}
