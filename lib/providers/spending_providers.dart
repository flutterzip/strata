import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/spend_category.dart';
import '../shared/utils/spend_rollup.dart';
import 'transaction_providers.dart';
import 'wallet_providers.dart';

/// The home "Spent this week" summary.
///
/// Derived, not stored. It used to read its own `spending.json`, which meant
/// the chart and the transaction list were two sources of truth for the same
/// question and an edit to one left the other stating something untrue.
/// There is now one record of what happened — transactions — and this is a
/// view over it.
///
/// Deliberately a [Provider] of [AsyncValue] rather than a [FutureProvider]:
/// there is nothing to await here, but loading and error still have to
/// propagate from the transactions underneath, so the surface the UI sees is
/// unchanged.
final spendingProvider = Provider<AsyncValue<SpendSummary>>((ref) {
  final txns = ref.watch(transactionsProvider);
  // The currency the headline balance is in, so the two figures on the home
  // screen can never be quoted in different currencies.
  final currency = ref.watch(totalBalanceProvider).currency;
  return txns.whenData(
    (list) => SpendRollup.fromTransactions(
      list,
      now: DateTime.now(),
      preferredCurrency: currency,
    ),
  );
});
