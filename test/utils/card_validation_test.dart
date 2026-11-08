import 'package:flutter_test/flutter_test.dart';
import 'package:strata/models/card_brand.dart';
import 'package:strata/shared/utils/card_validation.dart';

void main() {
  group('Luhn', () {
    test('accepts known-good numbers', () {
      for (final n in [
        '4242424242424242',
        '5555555555554444',
        '378282246310005'
      ]) {
        expect(CardValidation.luhn(n), isTrue, reason: n);
      }
    });

    test('rejects a number with a transposed digit', () {
      expect(CardValidation.luhn('4242424242424243'), isFalse);
    });

    test('rejects anything too short to be a card', () {
      expect(CardValidation.luhn('4242'), isFalse);
    });
  });

  group('brand detection', () {
    test('resolves networks from their IIN ranges', () {
      expect(CardBrand.detect('4242424242424242'), CardBrand.visa);
      expect(CardBrand.detect('5555555555554444'), CardBrand.mastercard);
      expect(CardBrand.detect('2221000000000009'), CardBrand.mastercard);
      expect(CardBrand.detect('378282246310005'), CardBrand.amex);
      expect(CardBrand.detect('6011111111111117'), CardBrand.discover);
      expect(CardBrand.detect('3530111333300000'), CardBrand.jcb);
    });

    test('resolves as soon as the prefix is unambiguous', () {
      expect(CardBrand.detect('4'), CardBrand.visa);
      expect(CardBrand.detect('37'), CardBrand.amex);
    });

    test('returns unknown for an unallocated prefix', () {
      expect(CardBrand.detect('9999'), CardBrand.unknown);
      expect(CardBrand.detect(''), CardBrand.unknown);
    });

    test('amex carries its own length and grouping', () {
      expect(CardBrand.amex.numberLength, 15);
      expect(CardBrand.amex.cvcLength, 4);
      expect(CardBrand.amex.grouping, [4, 6, 5]);
    });
  });

  group('formatting', () {
    test('groups in fours by default', () {
      expect(CardValidation.format('4242424242424242', CardBrand.visa),
          '4242 4242 4242 4242');
    });

    test('groups amex as 4-6-5', () {
      expect(CardValidation.format('378282246310005', CardBrand.amex),
          '3782 822463 10005');
    });

    test('handles a partial number', () {
      expect(CardValidation.format('424242', CardBrand.visa), '4242 42');
    });
  });

  group('field validation', () {
    test('number reports why it failed', () {
      expect(CardValidation.number(''), 'Enter your card number');
      expect(CardValidation.number('4242 4242'), 'That number looks too short');
      expect(CardValidation.number('4242 4242 4242 4243'),
          'Check the number and try again');
      expect(CardValidation.number('4242 4242 4242 4242'), isNull);
    });

    test('expiry rejects an impossible month', () {
      expect(CardValidation.expiry('1325'), 'That month does not exist');
    });

    test('expiry rejects a past date but accepts the current month', () {
      final now = DateTime(2026, 6, 15);
      expect(CardValidation.expiry('05/26', now: now), 'That card has expired');
      expect(CardValidation.expiry('06/26', now: now), isNull);
      expect(CardValidation.expiry('07/26', now: now), isNull);
    });

    test('cvc length follows the network', () {
      expect(CardValidation.cvc('123', CardBrand.visa), isNull);
      expect(CardValidation.cvc('123', CardBrand.amex), 'The code is 4 digits');
      expect(CardValidation.cvc('1234', CardBrand.amex), isNull);
    });

    test('holder requires a real name', () {
      expect(CardValidation.holder('  '), 'Enter the name on the card');
      expect(CardValidation.holder('A'), 'That name looks too short');
      expect(CardValidation.holder('Ada L'), isNull);
    });
  });
}
