import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../models/txn_filter.dart';
import '../../../providers/transaction_providers.dart';
import '../../../providers/wallet_providers.dart';
import '../../../shared/utils/money.dart';
import '../../../shared/utils/statements.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/status_view.dart';
import '../../../shared/widgets/strata_sheet.dart';
import '../../transactions/transactions_screen.dart';

/// Monthly statements for one card.
///
/// Derived from transactions on the spot. A stored statement is a second
/// record of the same month, and it would be wrong the moment anyone edits
/// a transaction inside it.
///
/// Tapping a month opens the activity list filtered to it, which is a more
/// useful thing than a PDF nobody reads.
class StatementsSheet extends ConsumerWidget {
  const StatementsSheet({super.key, required this.cardId});

  final String cardId;

  static const Key list = Key('statements-list');

  void _openMonth(
    BuildContext context,
    WidgetRef ref,
    DateTime month,
  ) {
    final lastDay =
        DateTime(month.year, month.month + 1).subtract(const Duration(days: 1));
    ref.read(txnFilterProvider.notifier).state = TxnFilter(
      cardId: cardId,
      from: month,
      to: lastDay,
    );
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(TransactionsScreen.route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final cards = ref.watch(walletProvider).valueOrNull ?? const [];
    final card = cards.where((c) => c.id == cardId).firstOrNull;
    final txns = ref.watch(transactionsProvider).valueOrNull ?? const [];
    final statements = Statements.forCard(txns, cardId);

    return StrataSheet(
      icon: Icons.description_outlined,
      title: 'Statements',
      message: card == null ? null : '${card.displayLabel} · ${card.shortMask}',
      scrollable: true,
      body: statements.isEmpty
          ? ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120),
              child: const StatusView(
                title: 'Nothing to report yet',
                message: 'A month appears here once something happens on '
                    'this card.',
                compact: true,
              ),
            )
          : Column(
              key: StatementsSheet.list,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in statements)
                  Pressable(
                    onTap: () => _openMonth(context, ref, s.month),
                    pressedScale: 0.99,
                    enforceMinTarget: false,
                    semanticLabel: '${s.label}, '
                        '${Money.format(s.outMinor, s.currency)} out, '
                        '${Money.format(s.inMinor, s.currency)} in, '
                        '${s.count} ${s.count == 1 ? 'entry' : 'entries'}',
                    semanticHint: 'Opens that month in your activity',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Space.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.label, style: text.titleSmall),
                                const SizedBox(height: Space.xxs),
                                Text(
                                  '${s.count} '
                                  '${s.count == 1 ? 'entry' : 'entries'}',
                                  style: text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Out and in kept apart rather than netted: a
                              // month where money arrived and left is not
                              // the same as a quiet one.
                              Text(
                                '−${Money.format(s.outMinor, s.currency)}',
                                style: text.bodyMedium,
                              ),
                              const SizedBox(height: Space.xxs),
                              Text(
                                '+${Money.format(s.inMinor, s.currency)}',
                                style: text.bodySmall
                                    ?.copyWith(color: scheme.primary),
                              ),
                            ],
                          ),
                          const SizedBox(width: Space.sm),
                          Icon(Icons.chevron_right_rounded,
                              size: 18, color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
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
