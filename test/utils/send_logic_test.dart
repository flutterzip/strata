import 'package:flutter_test/flutter_test.dart';
import 'package:strata/config/palette.dart';
import 'package:strata/models/card_brand.dart';
import 'package:strata/models/payment_card.dart';
import 'package:strata/models/recipient.dart';
import 'package:strata/shared/utils/amount_entry.dart';
import 'package:strata/shared/utils/recipient_lookup.dart';
import 'package:strata/shared/utils/send_rules.dart';

const akosua = Recipient(
  id: 'r_mensah',
  name: 'Akosua Mensah',
  handle: '@akosua',
  email: 'akosua.mensah@example.com',
  verified: true,
);
const petr = Recipient(
  id: 'r_novak',
  name: 'Petr Novak',
  handle: '@petr',
  email: 'p.novak@example.net',
);
const directory = [akosua, petr];

const card = PaymentCard(
  id: 'c_forest',
  last4: '8152',
  brand: CardBrand.mastercard,
  funding: CardFunding.debit,
  holder: 'OLYMPICSON',
  expiryMonth: 7,
  expiryYear: 2029,
  skin: CardSkin.forest,
  balanceMinor: 50000,
  currency: 'USD',
  nickname: 'Everyday',
);

RecipientMatch look(String input) => RecipientLookup.resolve(
      input,
      directory: directory,
      ownerHandle: '@olympicson',
      ownerEmail: 'hello@flutterzip.com',
    );

void main() {
  group('resolving a recipient', () {
    test('nothing typed is not an error, just nothing yet', () {
      expect(look('').state, RecipientMatchState.empty);
      expect(look('   ').state, RecipientMatchState.empty);
      expect(look('').recipient, isNull);
    });

    test('a handle resolves, with or without the @', () {
      expect(look('@akosua').recipient, akosua);
      expect(look('akosua').recipient, akosua);
      expect(look('@akosua').state, RecipientMatchState.found);
    });

    test('an email resolves', () {
      expect(look('akosua.mensah@example.com').recipient, akosua);
      expect(
          look('akosua.mensah@example.com').state, RecipientMatchState.found);
    });

    test('case and stray spaces do not stop a match', () {
      expect(look('  @AKOSUA ').recipient, akosua);
      expect(look(' Akosua.Mensah@Example.COM ').recipient, akosua);
    });

    test('a name resolves too, because that is what people type', () {
      expect(look('Akosua Mensah').recipient, akosua);
      expect(look('akosua mensah').recipient, akosua);
    });

    test('an unverified recipient resolves but is flagged', () {
      // Still sendable. Said out loud before the money moves, rather than
      // discovered afterwards.
      final m = look('@petr');
      expect(m.state, RecipientMatchState.unverified);
      expect(m.recipient, petr);
    });

    test('something that matches nobody is reported, not invented', () {
      // Accepting free text here is how money goes to a mistyped string.
      final m = look('@nobody');
      expect(m.state, RecipientMatchState.notFound);
      expect(m.recipient, isNull);
    });

    test('a plausible but unknown email is still not found', () {
      expect(look('someone@example.com').state, RecipientMatchState.notFound);
    });

    test('your own handle or email is you, and says so', () {
      expect(look('@olympicson').state, RecipientMatchState.self);
      expect(look('hello@flutterzip.com').state, RecipientMatchState.self);
      expect(look('HELLO@FLUTTERZIP.COM').state, RecipientMatchState.self);
    });

    test('every state carries a sentence a person can act on', () {
      for (final input in ['', '@akosua', '@petr', '@nobody', '@olympicson']) {
        final m = look(input);
        if (m.state == RecipientMatchState.empty) {
          expect(m.message, isNull);
        } else {
          expect(m.message, isNotNull, reason: input);
          expect(m.message, isNotEmpty, reason: input);
        }
      }
    });

    test('suggestions narrow as you type, across name, handle and email', () {
      expect(RecipientLookup.suggest('akos', directory), [akosua]);
      // A substring anywhere counts: "ak" is in "Novak" as well as
      // "Akosua", and both are things someone could be looking for.
      expect(RecipientLookup.suggest('ak', directory),
          containsAll([akosua, petr]));
      expect(RecipientLookup.suggest('p.novak', directory), [petr]);
      expect(RecipientLookup.suggest('', directory), directory);
      expect(RecipientLookup.suggest('zzz', directory), isEmpty);
    });

    test('the list puts whoever was paid most recently first', () {
      final recent = akosua.copyWith(lastUsedAt: DateTime(2026, 11, 5));
      final older = petr.copyWith(lastUsedAt: DateTime(2026, 10, 1));
      const never = Recipient(
        id: 'r_x',
        name: 'Aaron Unused',
        handle: '@aaron',
        email: 'a@example.com',
        verified: true,
      );

      // Never-used last, however early in the alphabet they sit: recency is
      // what a send list is for.
      expect(RecipientLookup.ordered([never, older, recent]),
          [recent, older, never]);
    });
  });

  group('typing an amount on a keypad', () {
    test('digits accumulate as minor units', () {
      // A money keypad has no decimal point: "4250" is $42.50, which is how
      // every card terminal in the world behaves.
      var e = AmountEntry.empty;
      for (final d in ['4', '2', '5', '0']) {
        e = e.push(d);
      }
      expect(e.minor, 4250);
      expect(e.formatted('USD'), r'$42.50');
    });

    test('nothing typed is zero, and formats as zero', () {
      expect(AmountEntry.empty.minor, 0);
      expect(AmountEntry.empty.isEmpty, isTrue);
      expect(AmountEntry.empty.formatted('USD'), r'$0.00');
    });

    test('leading zeros do not pile up', () {
      var e = AmountEntry.empty.push('0').push('0').push('5');
      expect(e.minor, 5);
      expect(e.formatted('USD'), r'$0.05');
    });

    test('backspace removes the last digit, and stops at empty', () {
      var e = AmountEntry.empty.push('1').push('2').backspace();
      expect(e.minor, 1);
      e = e.backspace().backspace().backspace();
      expect(e.isEmpty, isTrue);
      expect(e.minor, 0);
    });

    test('it refuses to grow past something a person could mean', () {
      var e = AmountEntry.empty;
      for (var i = 0; i < 40; i++) {
        e = e.push('9');
      }
      expect(e.digits.length, AmountEntry.maxDigits);
      // And it is still a number, not an overflowed one.
      expect(e.minor, greaterThan(0));
    });

    test('a non-digit is ignored rather than accepted', () {
      expect(AmountEntry.empty.push('x').isEmpty, isTrue);
      expect(AmountEntry.empty.push('.').isEmpty, isTrue);
    });

    test('an amount can be loaded back for editing', () {
      expect(AmountEntry.fromMinor(4250).formatted('USD'), r'$42.50');
      expect(AmountEntry.fromMinor(0).isEmpty, isTrue);
    });
  });

  group('whether a send can go ahead', () {
    test('everything in place is allowed, and says the resulting balance', () {
      final c =
          SendRules.check(recipient: akosua, card: card, amountMinor: 12500);
      expect(c.ok, isTrue);
      expect(c.reason, isNull);
      expect(c.resultingBalanceMinor, 37500);
    });

    test('no recipient is named, not silently disabled', () {
      final c = SendRules.check(recipient: null, card: card, amountMinor: 100);
      expect(c.ok, isFalse);
      expect(c.reason, 'Choose who you are sending to.');
    });

    test('no amount is named', () {
      final c = SendRules.check(recipient: akosua, card: card, amountMinor: 0);
      expect(c.ok, isFalse);
      expect(c.reason, 'Enter an amount to send.');
    });

    test('no card is named', () {
      final c =
          SendRules.check(recipient: akosua, card: null, amountMinor: 100);
      expect(c.ok, isFalse);
      expect(c.reason, 'Choose a card to send from.');
    });

    test('too much says how much there is and what the most is', () {
      // Never just a disabled button: the reason has the two numbers the
      // person needs in order to fix it.
      final c =
          SendRules.check(recipient: akosua, card: card, amountMinor: 60000);
      expect(c.ok, isFalse);
      expect(c.reason, contains(r'$500.00'));
      expect(c.reason, contains('Everyday'));
      expect(c.resultingBalanceMinor, -10000);
    });

    test('spending the balance exactly is allowed', () {
      final c =
          SendRules.check(recipient: akosua, card: card, amountMinor: 50000);
      expect(c.ok, isTrue);
      expect(c.resultingBalanceMinor, 0);
    });

    test('a negative amount cannot be smuggled in', () {
      final c =
          SendRules.check(recipient: akosua, card: card, amountMinor: -500);
      expect(c.ok, isFalse);
      expect(c.reason, 'Enter an amount to send.');
    });

    test('the first problem is the one reported', () {
      // One sentence at a time; a list of four faults helps nobody.
      final c = SendRules.check(recipient: null, card: null, amountMinor: 0);
      expect(c.reason, 'Choose who you are sending to.');
    });
  });
}
