import 'package:flutter/foundation.dart';

import '../../models/payment_card.dart';
import '../../models/recipient.dart';
import 'money.dart';
import 'spend_limit.dart';

/// Whether a send can go ahead, and why not.
@immutable
class SendCheck {
  const SendCheck({
    required this.ok,
    required this.resultingBalanceMinor,
    this.reason,
  });

  final bool ok;

  /// What the source card would hold afterwards. Shown before confirming,
  /// and deliberately still computed when the send is refused — seeing it go
  /// negative is the clearest possible statement of the problem.
  final int resultingBalanceMinor;

  /// One sentence, or null when [ok].
  final String? reason;
}

/// The rules for sending money.
///
/// Separate from the screen so each rule can be stated once and tested
/// without a widget, and so the Send button never has to be disabled in
/// silence: there is always a sentence to show.
abstract final class SendRules {
  /// [limit] is the source card's monthly-cap position, or null when it has
  /// no cap. Passed in rather than computed here so this stays a pure
  /// function of its arguments and the screen owns the clock.
  static SendCheck check({
    required Recipient? recipient,
    required PaymentCard? card,
    required int amountMinor,
    LimitStatus? limit,
  }) {
    final resulting = card == null
        ? 0
        : card.balanceMinor - (amountMinor > 0 ? amountMinor : 0);

    // One problem at a time, in the order the person meets them. A list of
    // four faults helps nobody.
    if (recipient == null) {
      return SendCheck(
        ok: false,
        resultingBalanceMinor: resulting,
        reason: 'Choose who you are sending to.',
      );
    }
    if (card == null) {
      return const SendCheck(
        ok: false,
        resultingBalanceMinor: 0,
        reason: 'Choose a card to send from.',
      );
    }
    if (card.frozen) {
      // Before the amount checks: "enter an amount" on a frozen card sends
      // someone off to fix the wrong thing.
      return SendCheck(
        ok: false,
        resultingBalanceMinor: card.balanceMinor,
        reason: 'Your ${card.displayLabel} card is frozen, so nothing can '
            'be sent from it. Unfreeze it from More on the card, or choose '
            'another card.',
      );
    }
    if (amountMinor <= 0) {
      return SendCheck(
        ok: false,
        resultingBalanceMinor: card.balanceMinor,
        reason: 'Enter an amount to send.',
      );
    }
    if (amountMinor > card.balanceMinor) {
      return SendCheck(
        ok: false,
        resultingBalanceMinor: card.balanceMinor - amountMinor,
        // Both numbers, so the sentence is enough to act on without going
        // back to look anything up.
        reason: 'That is more than the '
            '${Money.format(card.balanceMinor, card.currency)} on your '
            '${card.displayLabel} card. The most you can send is '
            '${Money.format(card.balanceMinor, card.currency)}.',
      );
    }

    if (limit != null && limit.wouldExceed(amountMinor)) {
      return SendCheck(
        ok: false,
        resultingBalanceMinor: resulting,
        reason: 'That would take your ${card.displayLabel} card past its '
            '${Money.format(limit.limitMinor, card.currency)} monthly '
            'limit. ${Money.format(limit.remainingMinor, card.currency)} '
            'is left this month.',
      );
    }

    return SendCheck(ok: true, resultingBalanceMinor: resulting);
  }
}
