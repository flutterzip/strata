import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/models/payment_card.dart';
import 'package:strata/models/transaction.dart';
import 'package:strata/services/demo_data.dart';
import 'package:strata/services/local_transaction_repository.dart';
import 'package:strata/services/transaction_seed.dart';

Transaction tx(String id, DateTime at, {int amountMinor = -500}) => Transaction(
      id: id,
      cardId: 'c_forest',
      kind: TxnKind.payment,
      merchant: 'M',
      category: 'Food',
      amountMinor: amountMinor,
      currency: 'USD',
      occurredAt: at,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DemoData.clearCache();
  });

  group('seed data', () {
    test('transactions.json parses into transactions', () async {
      final rows = await DemoData.loadList(
          TransactionSeed.seedFile, TransactionSeed.seedKey);
      expect(rows.length, greaterThanOrEqualTo(30));
      final txns = rows.map(Transaction.fromJson).toList();
      expect(txns.every((t) => t.merchant.isNotEmpty), isTrue);
      expect(txns.every((t) => t.amountMinor != 0), isTrue);
    });

    test('transaction ids are unique', () async {
      final rows = await DemoData.loadList(
          TransactionSeed.seedFile, TransactionSeed.seedKey);
      final ids = rows.map((r) => r['id'] as String).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate id: $ids');
    });

    test('every transaction belongs to a seeded card, in that card currency',
        () async {
      // A transaction in USD on a EUR card would make the card balance and
      // its history disagree, and no screen could reconcile them.
      final cards = (await DemoData.loadList('cards.json', 'cards'))
          .map(PaymentCard.fromJson)
          .toList();
      final byId = {for (final c in cards) c.id: c};
      final txns = (await DemoData.loadList(
              TransactionSeed.seedFile, TransactionSeed.seedKey))
          .map(Transaction.fromJson);

      for (final t in txns) {
        expect(byId.containsKey(t.cardId), isTrue,
            reason: '${t.id} references unknown card ${t.cardId}');
        expect(t.currency, byId[t.cardId]!.currency, reason: t.id);
      }
    });

    test('spans more than one month, so grouping is exercised', () async {
      final txns = (await DemoData.loadList(
              TransactionSeed.seedFile, TransactionSeed.seedKey))
          .map(Transaction.fromJson)
          .toList();
      expect(
          txns.map((t) => '${t.occurredAt.year}-${t.occurredAt.month}').toSet(),
          hasLength(greaterThan(1)));
    });

    test('covers every seeded card, so filtering by card is never empty',
        () async {
      final cardIds = (await DemoData.loadList('cards.json', 'cards'))
          .map((r) => r['id'] as String)
          .toSet();
      final used = (await DemoData.loadList(
              TransactionSeed.seedFile, TransactionSeed.seedKey))
          .map((r) => r['cardId'] as String)
          .toSet();
      expect(used, containsAll(cardIds));
    });
  });

  group('seed rebasing', () {
    test('shifts the whole set forward by the age of the seed', () async {
      // Without this the demo chart is empty a week after release.
      final rebased = TransactionSeed.rebase(
        [tx('a', DateTime(2026, 11, 7, 8, 14))],
        asOf: DateTime(2026, 11, 7),
        now: DateTime(2026, 12, 7, 20),
      );
      expect(rebased.single.occurredAt, DateTime(2026, 12, 7, 8, 14));
    });

    test('keeps the time of day and the gaps between rows', () async {
      final rebased = TransactionSeed.rebase(
        [
          tx('a', DateTime(2026, 11, 7, 8, 14)),
          tx('b', DateTime(2026, 10, 28, 21, 40)),
        ],
        asOf: DateTime(2026, 11, 7),
        now: DateTime(2027, 1, 1, 9),
      );
      expect(
          rebased[0].occurredAt.difference(rebased[1].occurredAt),
          DateTime(2026, 11, 7, 8, 14)
              .difference(DateTime(2026, 10, 28, 21, 40)));
      expect(rebased[0].occurredAt.hour, 8);
      expect(rebased[1].occurredAt.minute, 40);
    });

    test('never moves a transaction into the future', () async {
      // A template dated ahead of the clock, or a device with its date set
      // back, must not produce history that has not happened yet.
      final rebased = TransactionSeed.rebase(
        [tx('a', DateTime(2026, 11, 7, 8, 14))],
        asOf: DateTime(2026, 11, 7),
        now: DateTime(2026, 10, 1),
      );
      expect(rebased.single.occurredAt, DateTime(2026, 11, 7, 8, 14));
    });

    test('is a no-op on the day the seed was written', () async {
      final rebased = TransactionSeed.rebase(
        [tx('a', DateTime(2026, 11, 7, 8, 14))],
        asOf: DateTime(2026, 11, 7),
        now: DateTime(2026, 11, 7, 23, 59),
      );
      expect(rebased.single.occurredAt, DateTime(2026, 11, 7, 8, 14));
    });
  });

  group('LocalTransactionRepository', () {
    Future<LocalTransactionRepository> repo() async =>
        LocalTransactionRepository(
            prefs: await SharedPreferences.getInstance());

    test('first load seeds from the bundle, newest first', () async {
      final loaded = await (await repo()).load();
      expect(loaded.length, greaterThanOrEqualTo(30));
      for (var i = 1; i < loaded.length; i++) {
        expect(loaded[i - 1].occurredAt.isBefore(loaded[i].occurredAt), isFalse,
            reason: 'row $i is out of order');
      }
    });

    test('an added transaction survives a new repository instance', () async {
      final added = tx('t_new', DateTime(2026, 11, 7, 12), amountMinor: -1234);
      await (await repo()).add(added);

      final reloaded = await (await repo()).load();
      expect(reloaded.where((t) => t.id == 't_new'), hasLength(1));
      expect(reloaded.firstWhere((t) => t.id == 't_new').amountMinor, -1234);
    });

    test('an edit persists and touches nothing else', () async {
      final r = await repo();
      final before = await r.load();
      final target = before.first;

      await r.update(
          target.id, (t) => t.copyWith(note: 'checked', category: 'Home'));

      final after = await (await repo()).load();
      final updated = after.firstWhere((t) => t.id == target.id);
      expect(updated.note, 'checked');
      expect(updated.category, 'Home');
      expect(updated.amountMinor, target.amountMinor);
      expect(after, hasLength(before.length));
    });

    test('a delete persists', () async {
      final r = await repo();
      final before = await r.load();
      await r.remove(before.first.id);

      final after = await (await repo()).load();
      expect(after, hasLength(before.length - 1));
      expect(after.map((t) => t.id), isNot(contains(before.first.id)));
    });

    test('editing an id that is gone fails loudly rather than silently',
        () async {
      final r = await repo();
      await r.load();
      expect(() => r.update('nope', (t) => t), throwsA(isA<StateError>()));
    });

    test('reset discards user changes and re-reads the bundle', () async {
      final r = await repo();
      final before = await r.load();
      await r.remove(before.first.id);
      expect(await r.load(), hasLength(before.length - 1));

      await r.resetToSeed();
      expect(await r.load(), hasLength(before.length));
    });
  });
}
