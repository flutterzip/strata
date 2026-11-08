import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/models/recipient.dart';
import 'package:strata/services/demo_data.dart';
import 'package:strata/services/local_recipient_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DemoData.clearCache();
  });

  Future<List<Recipient>> seeded() async =>
      (await DemoData.loadList(LocalRecipientRepository.seedFile, 'recipients'))
          .map(Recipient.fromJson)
          .toList();

  group('seed data', () {
    test('recipients.json parses, with a handle and an email each', () async {
      // Both are required: a send is resolved by either, and a record
      // missing one is unreachable by half the ways people type.
      final rows = await seeded();
      expect(rows, isNotEmpty);
      for (final r in rows) {
        expect(r.name, isNotEmpty, reason: r.id);
        expect(r.handle, startsWith('@'), reason: r.id);
        expect(r.handle.length, greaterThan(1), reason: r.id);
        expect(r.email, contains('@'), reason: r.id);
      }
    });

    test('ids, handles and emails are all unique', () async {
      final rows = await seeded();
      expect(rows.map((r) => r.id).toSet(), hasLength(rows.length));
      expect(rows.map((r) => r.handle.toLowerCase()).toSet(),
          hasLength(rows.length));
      expect(rows.map((r) => r.email.toLowerCase()).toSet(),
          hasLength(rows.length));
    });

    test('at least one recipient is unconfirmed, so that state is reachable',
        () async {
      final rows = await seeded();
      expect(rows.where((r) => !r.verified), isNotEmpty);
      expect(rows.where((r) => r.verified), isNotEmpty);
    });

    test('some have been used and some have not, so ordering is visible',
        () async {
      final rows = await seeded();
      expect(rows.where((r) => r.lastUsedAt != null), isNotEmpty);
      expect(rows.where((r) => r.lastUsedAt == null), isNotEmpty);
    });

    test('no seeded recipient is the demo account itself', () async {
      // Sending to yourself is a state the lookup reports; it must not be
      // reachable by picking a row.
      final profile = await DemoData.loadJson('profile.json');
      final rows = await seeded();
      expect(
        rows.map((r) => r.email.toLowerCase()),
        isNot(contains((profile['email'] as String).toLowerCase())),
      );
      expect(
        rows.map((r) => r.handle.toLowerCase()),
        isNot(contains((profile['handle'] as String).toLowerCase())),
      );
    });
  });

  group('LocalRecipientRepository', () {
    Future<LocalRecipientRepository> repo() async =>
        LocalRecipientRepository(prefs: await SharedPreferences.getInstance());

    test('first load seeds from the bundle', () async {
      expect(await (await repo()).load(), isNotEmpty);
    });

    test('an added recipient survives a new repository instance', () async {
      const added = Recipient(
        id: 'r_new',
        name: 'Dayo Adeyemi',
        handle: '@dayo',
        email: 'dayo@example.com',
      );
      await (await repo()).add(added);

      final reloaded = await (await repo()).load();
      expect(reloaded.where((r) => r.id == 'r_new'), hasLength(1));
      expect(reloaded.firstWhere((r) => r.id == 'r_new').verified, isFalse);
    });

    test('an edit persists and touches nothing else', () async {
      final r = await repo();
      final before = await r.load();
      await r.update(before.first.id, (x) => x.copyWith(name: 'Renamed'));

      final after = await (await repo()).load();
      expect(after.firstWhere((x) => x.id == before.first.id).name, 'Renamed');
      expect(after, hasLength(before.length));
    });

    test('a handle is stored with exactly one leading @', () async {
      final r = await repo();
      final before = await r.load();
      await r.update(before.first.id, (x) => x.copyWith(handle: 'noat'));
      expect(
          (await (await repo()).load())
              .firstWhere((x) => x.id == before.first.id)
              .handle,
          '@noat');

      await r.update(before.first.id, (x) => x.copyWith(handle: '@withat'));
      expect(
          (await (await repo()).load())
              .firstWhere((x) => x.id == before.first.id)
              .handle,
          '@withat');
    });

    test('a delete persists', () async {
      final r = await repo();
      final before = await r.load();
      await r.remove(before.first.id);

      final after = await (await repo()).load();
      expect(after, hasLength(before.length - 1));
      expect(after.map((x) => x.id), isNot(contains(before.first.id)));
    });

    test('editing an id that is gone fails loudly rather than silently',
        () async {
      final r = await repo();
      await r.load();
      expect(() => r.update('nope', (x) => x), throwsA(isA<StateError>()));
    });

    test('reset discards user changes and re-reads the bundle', () async {
      final r = await repo();
      final before = await r.load();
      await r.remove(before.first.id);
      expect(await r.load(), hasLength(before.length - 1));

      await r.resetToSeed();
      expect(await r.load(), hasLength(before.length));
    });

    test('lastUsedAt round-trips through storage', () async {
      final r = await repo();
      final before = await r.load();
      final when = DateTime(2026, 11, 6, 9, 30);
      await r.update(before.first.id, (x) => x.copyWith(lastUsedAt: when));

      final reloaded = (await (await repo()).load())
          .firstWhere((x) => x.id == before.first.id);
      expect(reloaded.lastUsedAt, when);
    });
  });
}
