import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../models/payment_card.dart';
import '../../../providers/transaction_providers.dart';
import '../../../providers/wallet_providers.dart';
import '../../../shared/widgets/status_view.dart';
import '../../transactions/widgets/transaction_row.dart';

/// The newest few transactions, as a way into the activity list.
///
/// Three rows, not ten: this is a doorway, and a home screen that reprints
/// the whole list gives the reader no reason to open it. Reuses
/// [TransactionRow] so a row looks and speaks the same in both places.
class RecentActivity extends ConsumerWidget {
  const RecentActivity({super.key, required this.onSeeAll, this.onOpen});

  final VoidCallback onSeeAll;

  /// Opening one row. Null leaves rows inert, which is what the home screen
  /// wants when the whole block is a link into the list.
  final void Function(String id)? onOpen;

  static const int visible = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transactionsProvider);
    final text = Theme.of(context).textTheme;
    final cards =
        ref.watch(walletProvider).valueOrNull ?? const <PaymentCard>[];
    final byId = {for (final c in cards) c.id: c};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent activity',
                style: text.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(onPressed: onSeeAll, child: const Text('See all')),
          ],
        ),
        const SizedBox(height: Space.sm),
        async.when(
          // A floor, not a fixed height, so a two-line message is not
          // clipped off the bottom of the block.
          loading: () => ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: const Center(child: CircularProgressIndicator.adaptive()),
          ),
          error: (_, __) => ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: const StatusView(
              title: 'Activity is unavailable',
              message: 'Pull to refresh to try again.',
              compact: true,
            ),
          ),
          data: (all) {
            if (all.isEmpty) {
              return ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: const StatusView(
                  title: 'Nothing here yet',
                  message: 'Your payments and transfers will show up here.',
                  compact: true,
                ),
              );
            }
            return Column(
              children: [
                for (final txn in all.take(visible))
                  TransactionRow(
                    key: ValueKey('recent-${txn.id}'),
                    txn: txn,
                    card: byId[txn.cardId],
                    onTap: onOpen == null ? onSeeAll : () => onOpen!(txn.id),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
