import 'package:flutter/foundation.dart';

import '../../models/payment_card.dart';
import '../../models/transaction.dart';

/// Where a card stands against its monthly cap.
@immutable
class LimitStatus {
  const LimitStatus({
    required this.limitMinor,
    required this.spentMinor,
    required this.currency,
  });

  final int limitMinor;

  /// Spent on this card this calendar month, as a positive figure.
  final int spentMinor;

  final String currency;

  int get remainingMinor {
    final left = limitMinor - spentMinor;
    return left > 0 ? left : 0;
  }

  bool get exceeded => spentMinor >= limitMinor;

  /// 0..1, clamped, for a progress bar.
  double get fraction =>
      limitMinor <= 0 ? 0 : (spentMinor / limitMinor).clamp(0.0, 1.0);

  /// Whether one more payment of [amountMinor] would go over.
  bool wouldExceed(int amountMinor) => spentMinor + amountMinor > limitMinor;
}

/// Monthly spending caps.
///
/// What has been spent is **derived from transactions**, never counted up
/// into a field of its own: a second tally is a second thing to drift out of
/// step with the list people can see.
abstract final class SpendLimits {
  /// Money out on [cardId] in the calendar month containing [now].
  ///
  /// Calendar month, not a rolling 30 days: a cap people set is a cap they
  /// think of as resetting on the 1st.
  static int spentThisMonth(
    List<Transaction> txns,
    String cardId, {
    required DateTime now,
  }) {
    var total = 0;
    for (final t in txns) {
      if (t.cardId != cardId) continue;
      if (!t.isMoneyOut) continue;
      if (t.occurredAt.year != now.year || t.occurredAt.month != now.month) {
        continue;
      }
      total += t.amountMinor.abs();
    }
    return total;
  }

  /// Null when the card has no cap set.
  static LimitStatus? statusFor(
    PaymentCard card,
    List<Transaction> txns, {
    required DateTime now,
  }) {
    if (!card.hasSpendLimit) return null;
    return LimitStatus(
      limitMinor: card.spendLimitMinor!,
      spentMinor: spentThisMonth(txns, card.id, now: now),
      currency: card.currency,
    );
  }
}
