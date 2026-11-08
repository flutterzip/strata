import 'package:flutter_test/flutter_test.dart';
import 'package:strata/config/palette.dart';
import 'package:strata/models/card_brand.dart';
import 'package:strata/models/payment_card.dart';
import 'package:strata/models/rate_table.dart';
import 'package:strata/models/recipient.dart';
import 'package:strata/models/transaction.dart';
import 'package:strata/shared/utils/conversion.dart';
import 'package:strata/shared/utils/send_rules.dart';
import 'package:strata/shared/utils/spend_limit.dart';

const akosua = Recipient(
  id: 'r_mensah',
  name: 'Akosua Mensah',
  handle: '@akosua',
  email: 'akosua.mensah@example.com',
  verified: true,
);

PaymentCard card({
  String id = 'c_forest',
  String currency = 'USD',
  int balanceMinor = 50000,
  bool frozen = false,
  int? spendLimitMinor,
  String nickname = 'Everyday',
}) =>
    PaymentCard(
      id: id,
      last4: '8152',
      brand: CardBrand.mastercard,
      funding: CardFunding.debit,
      holder: 'OLYMPICSON',
      expiryMonth: 7,
      expiryYear: 2029,
      skin: CardSkin.forest,
      balanceMinor: balanceMinor,
      currency: currency,
      nickname: nickname,
      frozen: frozen,
      spendLimitMinor: spendLimitMinor,
    );

Transaction out(
  int minor, {
  String cardId = 'c_forest',
  DateTime? at,
  int sign = -1,
}) =>
    Transaction(
      id: 't_${minor}_$cardId${at?.day ?? 0}',
      cardId: cardId,
      kind: TxnKind.payment,
      merchant: 'M',
      category: 'Food',
      amountMinor: sign * minor,
      currency: 'USD',
      occurredAt: at ?? DateTime(2026, 11, 7, 12),
    );

final table = RateTable(
  asOf: DateTime(2026, 11, 7),
  base: 'USD',
  feeBps: 50,
  rates: const {'USD': 1.0, 'EUR': 0.9172},
);

void main() {
  group('frozen as a stored state', () {
    test('a card is not frozen by default', () {
      expect(card().frozen, isFalse);
    });

    test('it round-trips through JSON', () {
      final back = PaymentCard.fromJson(card(frozen: true).toJson());
      expect(back.frozen, isTrue);
      expect(PaymentCard.fromJson(card().toJson()).frozen, isFalse);
    });

    test('older stored data without the field loads as not frozen', () {
      // Stored data outlives the code that wrote it.
      final json = card().toJson()..remove('frozen');
      expect(PaymentCard.fromJson(json).frozen, isFalse);
    });

    test('copyWith can freeze and unfreeze', () {
      // Reversible by design: freezing a card you have mislaid is only
      // useful if you can unfreeze it when it turns up.
      final frozen = card().copyWith(frozen: true);
      expect(frozen.frozen, isTrue);
      expect(frozen.copyWith(frozen: false).frozen, isFalse);
      expect(frozen.copyWith(holder: 'SOMEONE').frozen, isTrue,
          reason: 'an unrelated edit must not thaw it');
    });

    test('two cards differing only in frozen are not equal', () {
      // Otherwise the carousel would not rebuild when one is frozen.
      expect(card() == card(frozen: true), isFalse);
    });

    test('a screen reader is told first', () {
      expect(
          card(frozen: true).describedForAccessibility, startsWith('Frozen, '));
      expect(card().describedForAccessibility, isNot(contains('Frozen')));
    });

    test('the full card number is still never serialised', () {
      final json = card(frozen: true, spendLimitMinor: 100).toJson();
      expect(json.keys, isNot(contains('number')));
      expect(json.keys, isNot(contains('cvc')));
    });
  });

  group('sending from a frozen card', () {
    test('is refused, and the reason says how to fix it', () {
      final c = SendRules.check(
        recipient: akosua,
        card: card(frozen: true),
        amountMinor: 1000,
      );
      expect(c.ok, isFalse);
      expect(c.reason, contains('frozen'));
      expect(c.reason, contains('Everyday'));
      expect(c.reason, contains('another card'));
    });

    test('is reported before the amount, not after', () {
      // "Enter an amount" on a frozen card sends someone off to fix the
      // wrong thing.
      final c = SendRules.check(
        recipient: akosua,
        card: card(frozen: true),
        amountMinor: 0,
      );
      expect(c.reason, contains('frozen'));
    });

    test('an unfrozen card is unaffected', () {
      expect(
        SendRules.check(recipient: akosua, card: card(), amountMinor: 1000).ok,
        isTrue,
      );
    });
  });

  group('converting with a frozen card', () {
    test('a frozen source is refused', () {
      final c = Conversion.check(
        from: card(frozen: true),
        to: card(id: 'c_moss', currency: 'EUR'),
        amountMinor: 1000,
        table: table,
      );
      expect(c.ok, isFalse);
      expect(c.reason, contains('frozen'));
    });

    test('a frozen destination is refused too', () {
      // Money arriving on a card that cannot be spent from is money the
      // owner did not mean to strand.
      final c = Conversion.check(
        from: card(),
        to: card(id: 'c_moss', currency: 'EUR', frozen: true),
        amountMinor: 1000,
        table: table,
      );
      expect(c.ok, isFalse);
      expect(c.reason, contains('frozen'));
      expect(c.reason, contains('onto it'));
    });
  });

  group('monthly spending limits', () {
    final now = DateTime(2026, 11, 15, 12);

    test('spend is derived from transactions, not counted separately', () {
      final spent = SpendLimits.spentThisMonth([
        out(2000, at: DateTime(2026, 11, 2)),
        out(3000, at: DateTime(2026, 11, 14)),
      ], 'c_forest', now: now);
      expect(spent, 5000);
    });

    test('money in does not reduce what was spent', () {
      final spent = SpendLimits.spentThisMonth([
        out(2000, at: DateTime(2026, 11, 2)),
        out(500, at: DateTime(2026, 11, 3), sign: 1),
      ], 'c_forest', now: now);
      expect(spent, 2000);
    });

    test('other cards and other months do not count', () {
      final spent = SpendLimits.spentThisMonth([
        out(2000, at: DateTime(2026, 11, 2)),
        out(9000, at: DateTime(2026, 11, 2), cardId: 'c_moss'),
        out(9000, at: DateTime(2026, 10, 31)),
        out(9000, at: DateTime(2026, 12, 1)),
      ], 'c_forest', now: now);
      expect(spent, 2000);
    });

    test('the month boundary is the 1st, not a rolling thirty days', () {
      // A cap people set is a cap they think of as resetting on the 1st.
      final spent = SpendLimits.spentThisMonth(
        [out(2000, at: DateTime(2026, 11, 1, 0, 0, 1))],
        'c_forest',
        now: DateTime(2026, 11, 30, 23, 59),
      );
      expect(spent, 2000);
    });

    test('no limit set means no status to show', () {
      expect(SpendLimits.statusFor(card(), const [], now: now), isNull);
      expect(
          SpendLimits.statusFor(card(spendLimitMinor: 0), const [], now: now),
          isNull);
    });

    test('the status reports what is left and how far along it is', () {
      final s = SpendLimits.statusFor(
        card(spendLimitMinor: 10000),
        [out(2500, at: DateTime(2026, 11, 3))],
        now: now,
      )!;
      expect(s.spentMinor, 2500);
      expect(s.remainingMinor, 7500);
      expect(s.fraction, closeTo(0.25, 1e-9));
      expect(s.exceeded, isFalse);
    });

    test('over the limit clamps the bar and never reports a negative left', () {
      final s = SpendLimits.statusFor(
        card(spendLimitMinor: 10000),
        [out(15000, at: DateTime(2026, 11, 3))],
        now: now,
      )!;
      expect(s.exceeded, isTrue);
      expect(s.remainingMinor, 0);
      expect(s.fraction, 1.0);
    });

    test('a send that would cross the limit is refused, with both figures', () {
      final limit = SpendLimits.statusFor(
        card(spendLimitMinor: 10000),
        [out(8000, at: DateTime(2026, 11, 3))],
        now: now,
      );
      final c = SendRules.check(
        recipient: akosua,
        card: card(spendLimitMinor: 10000),
        amountMinor: 5000,
        limit: limit,
      );
      expect(c.ok, isFalse);
      expect(c.reason, contains(r'$100.00'), reason: 'the limit');
      expect(c.reason, contains(r'$20.00'), reason: 'what is left');
    });

    test('a send that fits inside the limit is allowed', () {
      final limit = SpendLimits.statusFor(
        card(spendLimitMinor: 10000),
        [out(8000, at: DateTime(2026, 11, 3))],
        now: now,
      );
      final c = SendRules.check(
        recipient: akosua,
        card: card(spendLimitMinor: 10000),
        amountMinor: 2000,
        limit: limit,
      );
      expect(c.ok, isTrue, reason: 'exactly reaching the limit is allowed');
    });

    test('no limit passed means the rule does not apply', () {
      final c = SendRules.check(
        recipient: akosua,
        card: card(),
        amountMinor: 49000,
      );
      expect(c.ok, isTrue);
    });

    test('a limit round-trips through JSON, and can be removed', () {
      final withLimit = card(spendLimitMinor: 25000);
      expect(PaymentCard.fromJson(withLimit.toJson()).spendLimitMinor, 25000);
      expect(withLimit.copyWith(clearSpendLimit: true).spendLimitMinor, isNull);
      expect(withLimit.copyWith(holder: 'X').spendLimitMinor, 25000,
          reason: 'an unrelated edit must not drop the cap');
    });

    test('a conversion is capped too', () {
      final limit = SpendLimits.statusFor(
        card(spendLimitMinor: 10000),
        [out(9000, at: DateTime(2026, 11, 3))],
        now: now,
      );
      final c = Conversion.check(
        from: card(spendLimitMinor: 10000),
        to: card(id: 'c_moss', currency: 'EUR'),
        amountMinor: 5000,
        table: table,
        limit: limit,
      );
      expect(c.ok, isFalse);
      expect(c.reason, contains('monthly'));
    });
  });
}
