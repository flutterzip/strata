import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/models/app_notification.dart';
import 'package:strata/models/user_profile.dart';
import 'package:strata/services/demo_data.dart';
import 'package:strata/services/json_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DemoData.clearCache();
  });

  JsonDocumentStore<UserProfile> profileStore() =>
      JsonDocumentStore<UserProfile>(
        storageKey: 'test.profile',
        seedFile: 'profile.json',
        fromJson: UserProfile.fromJson,
        toJson: (p) => p.toJson(),
      );

  JsonCollectionStore<AppNotification> notificationStore() =>
      JsonCollectionStore<AppNotification>(
        storageKey: 'test.notifications',
        seedFile: 'notifications.json',
        seedKey: 'notifications',
        fromJson: AppNotification.fromJson,
        toJson: (n) => n.toJson(),
      );

  group('UserProfile', () {
    test('derives initials from one or two names', () {
      expect(
          const UserProfile(name: 'Ada Oladipo', email: '', handle: '')
              .initials,
          'AO');
      expect(
          const UserProfile(name: 'Ada', email: '', handle: '').initials, 'A');
      expect(
          const UserProfile(name: 'Ada Grace Oladipo', email: '', handle: '')
              .initials,
          'AO');
      expect(
          const UserProfile(name: '  ', email: '', handle: '').initials, '?');
    });

    test('round-trips through JSON including theme mode', () {
      const p = UserProfile(
        name: 'Olympicson',
        email: 'hello@flutterzip.com',
        handle: '@olympicson',
        themeMode: ThemeMode.dark,
      );
      final back = UserProfile.fromJson(p.toJson());
      expect(back, p);
      expect(back.themeMode, ThemeMode.dark);
    });

    test('an unknown theme mode falls back to system', () {
      expect(UserProfile.fromJson(const {'themeMode': 'neon'}).themeMode,
          ThemeMode.system);
    });
  });

  group('JsonDocumentStore', () {
    test('seeds from the bundle then persists edits', () async {
      final seeded = await profileStore().load();
      expect(seeded.name, isNotEmpty);

      await profileStore().save(seeded.copyWith(name: 'Changed Name'));
      expect((await profileStore().load()).name, 'Changed Name');
    });

    test('reset discards edits', () async {
      final seeded = await profileStore().load();
      await profileStore().save(seeded.copyWith(name: 'Temporary'));
      final reset = await profileStore().resetToSeed();
      expect(reset.name, seeded.name);
    });

    test('corrupt stored data falls back to the seed', () async {
      SharedPreferences.setMockInitialValues({'test.profile': '}{ broken'});
      expect((await profileStore().load()).name, isNotEmpty);
    });
  });

  group('notifications', () {
    test('seed parses with kinds and read flags', () async {
      final items = await notificationStore().load();
      expect(items, hasLength(10));
      expect(items.where((n) => !n.read), hasLength(4));
      expect(
          items.map((n) => n.kind),
          containsAll([
            NotificationKind.payment,
            NotificationKind.security,
            NotificationKind.system,
          ]));
    });

    test('seed includes a long body, so truncation is exercised', () async {
      final items = await notificationStore().load();
      expect(items.map((n) => n.body.length).reduce((a, b) => a > b ? a : b),
          greaterThan(200),
          reason: 'demo data must prove a long message does not break the '
              'list');
    });

    test('every notification has a title, body and distinct id', () async {
      final items = await notificationStore().load();
      expect(
          items.every((n) => n.title.isNotEmpty && n.body.isNotEmpty), isTrue);
      expect(items.map((n) => n.id).toSet(), hasLength(items.length));
    });

    test('an unknown kind degrades to system rather than throwing', () {
      final n = AppNotification.fromJson(const {
        'id': 'x',
        'kind': 'telepathy',
        'title': 't',
        'body': 'b',
        'sentAt': '2026-01-01T00:00:00Z',
        'read': false,
      });
      expect(n.kind, NotificationKind.system);
    });

    test('marking read persists', () async {
      final store = notificationStore();
      final items = await store.load();
      await store.save([
        for (final n in items)
          n.id == items.first.id ? n.copyWith(read: true) : n,
      ]);
      final reloaded = await notificationStore().load();
      expect(reloaded.firstWhere((n) => n.id == items.first.id).read, isTrue);
    });

    test('deleting persists', () async {
      final store = notificationStore();
      final items = await store.load();
      await store.save(items.where((n) => n.id != items.first.id).toList());
      expect((await notificationStore().load()), hasLength(items.length - 1));
    });

    test('a malformed timestamp does not crash parsing', () {
      final n = AppNotification.fromJson(const {
        'id': 'x',
        'kind': 'system',
        'title': 't',
        'body': 'b',
        'sentAt': 'not a date',
        'read': false,
      });
      expect(n.sentAt, isA<DateTime>());
    });
  });
}
