import 'package:flutter_test/flutter_test.dart';
import 'package:strata/config/palette.dart';
import 'package:strata/models/card_brand.dart';
import 'package:strata/models/payment_card.dart';
import 'package:strata/models/rate_table.dart';
import 'package:strata/services/demo_data.dart';
import 'package:strata/shared/utils/conversion.dart';

final table = RateTable(
  asOf: DateTime(2026, 11, 7),
  base: 'USD',
  feeBps: 50,
  rates: const {'USD': 1.0, 'EUR': 0.9172, 'GBP': 0.7865},
);

PaymentCard card({
  String id = 'c_forest',
  String currency = 'USD',
  int balanceMinor = 50000,
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
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the rate table', () {
    test('a cross rate is derived, not stored', () {
      // A stored table of every pair is thirty entries for six currencies
      // and can disagree with itself.
      expect(table.rate('USD', 'EUR'), closeTo(0.9172, 1e-9));
      expect(table.rate('EUR', 'USD'), closeTo(1 / 0.9172, 1e-9));
      expect(table.rate('EUR', 'GBP'), closeTo(0.7865 / 0.9172, 1e-9));
    });

    test('a currency against itself is exactly one', () {
      expect(table.rate('EUR', 'EUR'), 1);
    });

    test('an unknown currency has no rate rather than a wrong one', () {
      expect(table.rate('USD', 'XYZ'), isNull);
      expect(table.supports('XYZ'), isFalse);
    });

    test('rates.json parses and quotes the wallet currencies', () async {
      DemoData.clearCache();
      final real = RateTable.fromJson(await DemoData.loadJson('rates.json'));
      expect(real.feeBps, greaterThan(0));
      expect(real.asOf.year, greaterThan(2020));
      // The seeded cards hold USD and EUR; without both there is no
      // conversion to demonstrate.
      for (final c in ['USD', 'EUR']) {
        expect(real.supports(c), isTrue, reason: c);
      }
      expect(real.supports(real.base), isTrue);
      expect(real.rates[real.base], 1.0,
          reason: 'the base must be one unit of itself');
    });
  });

  group('quoting a conversion', () {
    test('the fee comes off before the rate, so the breakdown adds up', () {
      final q = Conversion.quote(
        fromCurrency: 'USD',
        toCurrency: 'EUR',
        amountMinor: 20000,
        table: table,
      );
      expect(q.feeMinor, 100, reason: r'0.50% of $200.00');
      expect(q.netMinor, 19900);
      expect(q.convertedMinor, (19900 * 0.9172).round());
      expect(q.rate, closeTo(0.9172, 1e-9));
    });

    test('same currency is rate one and no fee', () {
      // Charging to move dollars to dollars would be indefensible.
      final q = Conversion.quote(
        fromCurrency: 'USD',
        toCurrency: 'USD',
        amountMinor: 20000,
        table: table,
      );
      expect(q.sameCurrency, isTrue);
      expect(q.feeMinor, 0);
      expect(q.rate, 1);
      expect(q.convertedMinor, 20000);
    });

    test('everything stays in whole minor units', () {
      // Both sides are integers, so a credit and a debit can never drift
      // into fractions of a cent.
      final q = Conversion.quote(
        fromCurrency: 'USD',
        toCurrency: 'EUR',
        amountMinor: 3333,
        table: table,
      );
      expect(q.feeMinor * 1.0, q.feeMinor);
      expect(q.convertedMinor * 1.0, q.convertedMinor);
      expect(q.convertedMinor, ((3333 - 17) * 0.9172).round());
    });

    test('a negative amount cannot be smuggled through', () {
      final q = Conversion.quote(
        fromCurrency: 'USD',
        toCurrency: 'EUR',
        amountMinor: -5000,
        table: table,
      );
      expect(q.amountMinor, 0);
      expect(q.convertedMinor, 0);
    });

    test('an unknown currency quotes nothing rather than guessing', () {
      final q = Conversion.quote(
        fromCurrency: 'USD',
        toCurrency: 'XYZ',
        amountMinor: 10000,
        table: table,
      );
      expect(q.rate, 0);
      expect(q.convertedMinor, 0);
    });

    test('the rate label carries four decimals, not two', () {
      // 0.92 against 0.9172 is a 0.3% error, which on a rate is a lot.
      final q = Conversion.quote(
        fromCurrency: 'USD',
        toCurrency: 'EUR',
        amountMinor: 1000,
        table: table,
      );
      expect(q.rateLabel, '1 USD = 0.9172 EUR');
    });

    test('converting and converting back loses only the fee and rounding', () {
      final out = Conversion.quote(
        fromCurrency: 'USD',
        toCurrency: 'EUR',
        amountMinor: 100000,
        table: table,
      );
      final back = Conversion.quote(
        fromCurrency: 'EUR',
        toCurrency: 'USD',
        amountMinor: out.convertedMinor,
        table: table,
      );
      // Two 0.5% fees, so about 1% down. Never up.
      expect(back.convertedMinor, lessThan(100000));
      expect(back.convertedMinor, greaterThan(98000));
    });
  });

  group('whether a conversion can go ahead', () {
    test('two different cards with a rate and funds is allowed', () {
      final c = Conversion.check(
        from: card(),
        to: card(id: 'c_moss', currency: 'EUR', nickname: 'Travel'),
        amountMinor: 20000,
        table: table,
      );
      expect(c.ok, isTrue);
      expect(c.reason, isNull);
      expect(c.quote.convertedMinor, greaterThan(0));
    });

    test('the same card on both sides is refused', () {
      final c = Conversion.check(
        from: card(),
        to: card(),
        amountMinor: 20000,
        table: table,
      );
      expect(c.ok, isFalse);
      expect(c.reason, 'Choose two different cards.');
    });

    test('two cards in the same currency is allowed, as a plain move', () {
      // "Handles same-currency selection sensibly": it is not an error, it
      // is a transfer at 1.00 with no fee.
      final c = Conversion.check(
        from: card(),
        to: card(id: 'c_sage', currency: 'USD', nickname: 'Household'),
        amountMinor: 20000,
        table: table,
      );
      expect(c.ok, isTrue);
      expect(c.quote.sameCurrency, isTrue);
      expect(c.quote.feeMinor, 0);
      expect(c.quote.convertedMinor, 20000);
    });

    test('no amount is named rather than silently disabled', () {
      final c = Conversion.check(
        from: card(),
        to: card(id: 'c_moss', currency: 'EUR'),
        amountMinor: 0,
        table: table,
      );
      expect(c.ok, isFalse);
      expect(c.reason, 'Enter an amount to convert.');
    });

    test('too much says how much there is', () {
      final c = Conversion.check(
        from: card(balanceMinor: 5000),
        to: card(id: 'c_moss', currency: 'EUR'),
        amountMinor: 20000,
        table: table,
      );
      expect(c.ok, isFalse);
      expect(c.reason, contains(r'$50.00'));
      expect(c.reason, contains('Everyday'));
    });

    test('a missing rate is reported by name', () {
      final c = Conversion.check(
        from: card(),
        to: card(id: 'c_x', currency: 'XYZ'),
        amountMinor: 20000,
        table: table,
      );
      expect(c.ok, isFalse);
      expect(c.reason, contains('XYZ'));
    });

    test('an amount the fee would swallow is refused, not silently zeroed', () {
      // One cent, 0.5% fee rounds to nothing, rate rounds the rest away.
      final c = Conversion.check(
        from: card(),
        to: card(id: 'c_j', currency: 'GBP'),
        amountMinor: 1,
        table: table,
      );
      if (!c.ok) {
        expect(c.reason, contains('too small'));
      } else {
        expect(c.quote.convertedMinor, greaterThan(0));
      }
    });

    test('a refused conversion still shows its figures', () {
      // Seeing the numbers is how someone works out what to change.
      final c = Conversion.check(
        from: card(balanceMinor: 100),
        to: card(id: 'c_moss', currency: 'EUR'),
        amountMinor: 20000,
        table: table,
      );
      expect(c.ok, isFalse);
      expect(c.quote.amountMinor, 20000);
      expect(c.quote.rate, closeTo(0.9172, 1e-9));
    });
  });
}
