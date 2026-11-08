import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/payment_card.dart';
import '../../models/rate_table.dart';
import 'money.dart';
import 'spend_limit.dart';

/// What one conversion would do.
@immutable
class ConversionQuote {
  const ConversionQuote({
    required this.fromCurrency,
    required this.toCurrency,
    required this.amountMinor,
    required this.feeMinor,
    required this.convertedMinor,
    required this.rate,
  });

  final String fromCurrency;
  final String toCurrency;

  /// Taken off the source card, fee included.
  final int amountMinor;

  /// Deducted from [amountMinor] before converting, in the source currency.
  final int feeMinor;

  /// Credited to the destination card, in [toCurrency].
  final int convertedMinor;

  /// Units of [toCurrency] per one unit of [fromCurrency].
  final double rate;

  /// What actually gets converted, after the fee.
  int get netMinor => amountMinor - feeMinor;

  bool get sameCurrency => fromCurrency == toCurrency;

  /// "1 USD = 0.9172 EUR", for the breakdown.
  ///
  /// Four decimal places: two is not enough for a rate (0.92 against 0.9172
  /// is a 0.3% error) and more is noise at these amounts.
  String get rateLabel =>
      '1 $fromCurrency = ${rate.toStringAsFixed(4)} $toCurrency';
}

/// Whether a conversion can go ahead, and why not.
@immutable
class ConversionCheck {
  const ConversionCheck({
    required this.ok,
    required this.quote,
    this.reason,
  });

  final bool ok;

  /// Always present, even when refused: seeing the figures is how someone
  /// works out what to change.
  final ConversionQuote quote;

  final String? reason;
}

/// Converting between two of the owner's own cards.
abstract final class Conversion {
  /// Quote [amountMinor] of [from]'s currency into [to]'s.
  ///
  /// The fee comes off the amount before the rate is applied, which is what
  /// makes the breakdown add up on screen: amount, less fee, times rate.
  /// It is waived when both sides hold the same currency — charging to move
  /// dollars to dollars would be indefensible.
  static ConversionQuote quote({
    required String fromCurrency,
    required String toCurrency,
    required int amountMinor,
    required RateTable table,
  }) {
    final rate = table.rate(fromCurrency, toCurrency) ?? 0;
    final amount = math.max(0, amountMinor);
    final feeMinor = fromCurrency == toCurrency
        ? 0
        // Round half up on the fee, so it is never silently free on small
        // amounts through truncation.
        : (amount * table.feeBps / 10000).round();
    final net = amount - feeMinor;

    return ConversionQuote(
      fromCurrency: fromCurrency,
      toCurrency: toCurrency,
      amountMinor: amount,
      feeMinor: feeMinor,
      // Rounded to the destination's minor unit. Both sides are integers, so
      // the credit and the debit can never drift into fractions of a cent.
      convertedMinor: (net * rate).round(),
      rate: rate,
    );
  }

  /// [limit] is the source card's monthly-cap position, or null.
  static ConversionCheck check({
    required PaymentCard? from,
    required PaymentCard? to,
    required int amountMinor,
    required RateTable table,
    LimitStatus? limit,
  }) {
    final q = quote(
      fromCurrency: from?.currency ?? table.base,
      toCurrency: to?.currency ?? table.base,
      amountMinor: amountMinor,
      table: table,
    );

    // One problem at a time, in the order someone meets them.
    if (from == null || to == null) {
      return ConversionCheck(
        ok: false,
        quote: q,
        reason: 'Choose a card on both sides.',
      );
    }
    if (from.id == to.id) {
      return ConversionCheck(
        ok: false,
        quote: q,
        reason: 'Choose two different cards.',
      );
    }
    if (!table.supports(from.currency) || !table.supports(to.currency)) {
      final missing =
          table.supports(from.currency) ? to.currency : from.currency;
      return ConversionCheck(
        ok: false,
        quote: q,
        reason: 'We have no rate for $missing in this demo.',
      );
    }
    if (from.frozen) {
      return ConversionCheck(
        ok: false,
        quote: q,
        reason: 'Your ${from.displayLabel} card is frozen, so nothing can '
            'be converted out of it.',
      );
    }
    if (to.frozen) {
      // The destination matters too: money arriving on a card that cannot
      // be spent from is money the owner did not mean to strand.
      return ConversionCheck(
        ok: false,
        quote: q,
        reason: 'Your ${to.displayLabel} card is frozen, so money cannot be '
            'moved onto it.',
      );
    }
    if (amountMinor <= 0) {
      return ConversionCheck(
        ok: false,
        quote: q,
        reason: 'Enter an amount to convert.',
      );
    }
    if (amountMinor > from.balanceMinor) {
      return ConversionCheck(
        ok: false,
        quote: q,
        reason: 'That is more than the '
            '${Money.format(from.balanceMinor, from.currency)} on your '
            '${from.displayLabel} card.',
      );
    }
    if (q.convertedMinor <= 0) {
      // Small enough that the fee eats it, or a rate that rounds to nothing.
      return ConversionCheck(
        ok: false,
        quote: q,
        reason: 'That is too small to convert. The fee would take all of it.',
      );
    }

    if (limit != null && limit.wouldExceed(amountMinor)) {
      return ConversionCheck(
        ok: false,
        quote: q,
        reason: 'That would take your ${from.displayLabel} card past its '
            '${Money.format(limit.limitMinor, from.currency)} monthly '
            'limit. ${Money.format(limit.remainingMinor, from.currency)} '
            'is left this month.',
      );
    }

    return ConversionCheck(ok: true, quote: q);
  }
}
