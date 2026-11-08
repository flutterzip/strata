import 'package:flutter_test/flutter_test.dart';
import 'package:strata/models/transaction.dart';
import 'package:strata/models/txn_filter.dart';
import 'package:strata/services/media_ref.dart';
import 'package:strata/shared/utils/money.dart';
import 'package:strata/shared/utils/txn_grouping.dart';

Transaction tx({
  String id = 't1',
  String cardId = 'c_forest',
  TxnKind kind = TxnKind.payment,
  String merchant = 'Blue Bottle',
  String category = 'Food',
  int amountMinor = -475,
  String currency = 'USD',
  required DateTime at,
  String? note,
}) =>
    Transaction(
      id: id,
      cardId: cardId,
      kind: kind,
      merchant: merchant,
      category: category,
      amountMinor: amountMinor,
      currency: currency,
      occurredAt: at,
      note: note,
    );

void main() {
  group('signed amount formatting', () {
    test('money out carries a minus, money in a plus', () {
      expect(Money.signed(-475, 'USD'), r'-$4.75');
      expect(Money.signed(475, 'USD'), r'+$4.75');
    });

    test('zero carries no sign at all', () {
      // "+$0.00" reads as a credit that did not happen.
      expect(Money.signed(0, 'USD'), r'$0.00');
    });

    test('the sign sits outside the currency symbol', () {
      // "€-4.75" is what naive formatting produces and it is unreadable.
      expect(Money.signed(-475, 'EUR'), '-€4.75');
      expect(Money.signed(-123456, 'GBP'), '-£1,234.56');
    });

    test('a transaction labels itself from its own sign', () {
      expect(tx(at: DateTime(2026, 3, 4)).amountLabel, r'-$4.75');
      expect(
        tx(at: DateTime(2026, 3, 4), amountMinor: 9900, kind: TxnKind.topUp)
            .amountLabel,
        r'+$99.00',
      );
    });

    test('the spoken label says paid or received, never a bare minus', () {
      expect(tx(at: DateTime(2026, 3, 4)).describedForAccessibility,
          r'Blue Bottle, paid $4.75, Food');
      expect(
        tx(at: DateTime(2026, 3, 4), amountMinor: 2500, kind: TxnKind.refund)
            .describedForAccessibility,
        r'Blue Bottle, received $25.00, Food',
      );
    });
  });

  group('JSON', () {
    test('round-trips every field without loss', () {
      final original = Transaction(
        id: 't_42',
        cardId: 'c_moss',
        kind: TxnKind.conversion,
        merchant: 'USD to EUR',
        category: 'Transfers',
        amountMinor: -15000,
        currency: 'USD',
        occurredAt: DateTime(2026, 2, 28, 14, 30),
        note: 'holiday money',
        receipt: const MediaRef(MediaSource.file, 'media/r_42.jpg'),
      );
      final back = Transaction.fromJson(original.toJson());

      expect(back.id, original.id);
      expect(back.cardId, original.cardId);
      expect(back.kind, TxnKind.conversion);
      expect(back.merchant, original.merchant);
      expect(back.category, original.category);
      expect(back.amountMinor, -15000);
      expect(back.currency, 'USD');
      expect(back.occurredAt, original.occurredAt);
      expect(back.note, 'holiday money');
      expect(back.receipt, original.receipt);
    });

    test('an unknown kind falls back rather than throwing on launch', () {
      final back = Transaction.fromJson(const {
        'id': 't1',
        'cardId': 'c_forest',
        'kind': 'cryptoWizardry',
        'merchant': 'X',
        'category': 'Other',
        'amountMinor': -100,
        'currency': 'USD',
        'occurredAt': '2026-03-04T10:00:00.000',
      });
      expect(back.kind, TxnKind.payment);
    });

    test('copyWith can clear a note, which null cannot express', () {
      final original = tx(at: DateTime(2026, 3, 4), note: 'keep me');
      expect(original.copyWith(category: 'Transport').note, 'keep me');
      expect(original.copyWith(clearNote: true).note, isNull);
    });
  });

  group('grouping by day', () {
    test('groups newest day first, newest first within a day', () {
      final groups = TxnGrouping.byDay([
        tx(id: 'a', at: DateTime(2026, 3, 4, 9)),
        tx(id: 'c', at: DateTime(2026, 3, 5, 8)),
        tx(id: 'b', at: DateTime(2026, 3, 4, 18)),
      ]);

      expect(groups.map((g) => g.day), [
        DateTime(2026, 3, 5),
        DateTime(2026, 3, 4),
      ]);
      expect(groups.first.items.map((t) => t.id), ['c']);
      expect(groups.last.items.map((t) => t.id), ['b', 'a']);
    });

    test('a month boundary splits into separate days, in order', () {
      // Sorting on day-of-month instead of the full date puts 31 January
      // after 1 February. Grouping must survive the rollover.
      final groups = TxnGrouping.byDay([
        tx(id: 'jan31', at: DateTime(2026, 1, 31, 12)),
        tx(id: 'feb01', at: DateTime(2026, 2, 1, 9)),
        tx(id: 'jan30', at: DateTime(2026, 1, 30, 12)),
      ]);

      expect(groups.map((g) => g.items.single.id), ['feb01', 'jan31', 'jan30']);
    });

    test('a year boundary orders by year, not by month number', () {
      final groups = TxnGrouping.byDay([
        tx(id: 'dec', at: DateTime(2025, 12, 31, 12)),
        tx(id: 'jan', at: DateTime(2026, 1, 1, 9)),
      ]);
      expect(groups.map((g) => g.items.single.id), ['jan', 'dec']);
    });

    test('times on the same calendar day never split', () {
      final groups = TxnGrouping.byDay([
        tx(id: 'early', at: DateTime(2026, 3, 4, 0, 0, 1)),
        tx(id: 'late', at: DateTime(2026, 3, 4, 23, 59, 59)),
      ]);
      expect(groups, hasLength(1));
      expect(groups.single.items.map((t) => t.id), ['late', 'early']);
    });

    test('a group nets its own signed amounts', () {
      final groups = TxnGrouping.byDay([
        tx(at: DateTime(2026, 3, 4, 9), amountMinor: -500),
        tx(id: 't2', at: DateTime(2026, 3, 4, 10), amountMinor: 2000),
      ]);
      expect(groups.single.netMinor, 1500);
    });

    test('an empty list groups into nothing', () {
      expect(TxnGrouping.byDay(const []), isEmpty);
    });
  });

  group('day labels', () {
    final now = DateTime(2026, 3, 4, 15);

    test('names today and yesterday rather than dating them', () {
      expect(TxnGrouping.dayLabel(DateTime(2026, 3, 4), now: now), 'Today');
      expect(TxnGrouping.dayLabel(DateTime(2026, 3, 3), now: now), 'Yesterday');
    });

    test('dates anything older in the current year without the year', () {
      expect(
          TxnGrouping.dayLabel(DateTime(2026, 2, 28), now: now), 'Sat 28 Feb');
    });

    test('adds the year once the date leaves it', () {
      expect(TxnGrouping.dayLabel(DateTime(2025, 12, 31), now: now),
          'Wed 31 Dec 2025');
    });
  });

  group('filtering', () {
    final a = tx(
        id: 'a',
        cardId: 'c_forest',
        category: 'Food',
        merchant: 'Blue Bottle',
        at: DateTime(2026, 3, 4));
    final b = tx(
        id: 'b',
        cardId: 'c_moss',
        category: 'Transport',
        merchant: 'City Rail',
        at: DateTime(2026, 2, 20));

    test('no filter matches everything', () {
      expect(TxnFilter.none.isActive, isFalse);
      expect([a, b].where(TxnFilter.none.matches), hasLength(2));
    });

    test('filters by card', () {
      final f = TxnFilter.none.copyWith(cardId: 'c_moss');
      expect([a, b].where(f.matches).map((t) => t.id), ['b']);
      expect(f.isActive, isTrue);
    });

    test('filters by category', () {
      final f = TxnFilter.none.copyWith(category: 'Food');
      expect([a, b].where(f.matches).map((t) => t.id), ['a']);
    });

    test('a date range includes both of its end days in full', () {
      // An exclusive upper bound silently drops everything that happened
      // after midnight on the last day the user picked.
      final f = TxnFilter.none.copyWith(
        from: DateTime(2026, 2, 20),
        to: DateTime(2026, 3, 4),
      );
      expect([a, b].where(f.matches).map((t) => t.id), ['a', 'b']);

      final narrow = TxnFilter.none.copyWith(
        from: DateTime(2026, 2, 20),
        to: DateTime(2026, 2, 20),
      );
      expect([a, b].where(narrow.matches).map((t) => t.id), ['b']);
    });

    test('search on merchant ignores case and surrounding space', () {
      final f = TxnFilter.none.copyWith(query: '  bottle ');
      expect([a, b].where(f.matches).map((t) => t.id), ['a']);
    });

    test('an empty query is not a filter', () {
      expect(TxnFilter.none.copyWith(query: '   ').isActive, isFalse);
    });

    test('facets combine, and a contradiction matches nothing', () {
      final f =
          TxnFilter.none.copyWith(cardId: 'c_forest', category: 'Transport');
      expect([a, b].where(f.matches), isEmpty);
    });

    test('clearing a facet is expressible', () {
      final f =
          TxnFilter.none.copyWith(cardId: 'c_moss', category: 'Transport');
      expect(f.cleared(TxnFacet.card).cardId, isNull);
      expect(f.cleared(TxnFacet.card).category, 'Transport');
      expect(f.cleared(TxnFacet.category).category, isNull);
    });

    test('counts its active facets for a badge, query included', () {
      expect(TxnFilter.none.activeCount, 0);
      expect(
        TxnFilter.none
            .copyWith(cardId: 'c_moss', category: 'Food', query: 'rail')
            .activeCount,
        3,
      );
      expect(
        TxnFilter.none
            .copyWith(from: DateTime(2026, 1, 1), to: DateTime(2026, 2, 1))
            .activeCount,
        1,
      );
    });
  });
}
