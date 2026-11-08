import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strata/config/palette.dart';
import 'package:strata/models/card_brand.dart';
import 'package:strata/models/payment_card.dart';
import 'package:strata/services/demo_data.dart';
import 'package:strata/services/local_wallet_repository.dart';
import 'package:strata/services/media_ref.dart';
import 'package:strata/services/remote_wallet_repository.dart';

import '../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DemoData.clearCache();
  });

  group('seed data', () {
    test('cards.json parses into cards', () async {
      final rows = await DemoData.loadList('cards.json', 'cards');
      expect(rows, isNotEmpty);
      final cards = rows.map(PaymentCard.fromJson).toList();
      expect(cards.first.brand, isA<CardBrand>());
      expect(cards.every((c) => c.last4.length == 4), isTrue);
    });

    test('card ids are unique', () async {
      // A chained string replace during a rename once gave two seed cards
      // the same id. The carousel tolerated it; the keyed wallet stack did
      // not, and the app crashed with "Duplicate keys found".
      final rows = await DemoData.loadList('cards.json', 'cards');
      final ids = rows.map((r) => r['id'] as String).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate id: $ids');
    });

    test('every card is active, and one carries a monthly limit', () async {
      // Active by default: a wallet that opens with a frozen card looks
      // broken. One limit, so the meter and the subtitle on More are
      // visible on first run rather than only after someone sets one.
      final cards = (await DemoData.loadList('cards.json', 'cards'))
          .map(PaymentCard.fromJson)
          .toList();
      expect(cards.every((c) => !c.frozen), isTrue);
      expect(cards.where((c) => c.hasSpendLimit), hasLength(1));
      final capped = cards.firstWhere((c) => c.hasSpendLimit);
      expect(capped.spendLimitMinor, greaterThan(0));
    });

    test('notification ids are unique', () async {
      final rows =
          await DemoData.loadList('notifications.json', 'notifications');
      final ids = rows.map((r) => r['id'] as String).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate id: $ids');
    });

    test('a missing key fails loudly rather than silently', () {
      expect(() => DemoData.loadList('cards.json', 'nope'),
          throwsA(isA<FormatException>()));
    });
  });

  group('PaymentCard JSON', () {
    test('round-trips without loss', () {
      final back = PaymentCard.fromJson(sampleCard.toJson());
      expect(back.id, sampleCard.id);
      expect(back.last4, sampleCard.last4);
      expect(back.brand, sampleCard.brand);
      expect(back.funding, sampleCard.funding);
      expect(back.skin, sampleCard.skin);
      expect(back.expiryLabel, sampleCard.expiryLabel);
      expect(back.balanceMinor, sampleCard.balanceMinor);
    });

    test('never serialises a full number or security code', () {
      final json = sampleCard.toJson();
      expect(json.keys, isNot(contains('number')));
      expect(json.keys, isNot(contains('pan')));
      expect(json.keys, isNot(contains('cvc')));
      expect(json.values.join(), isNot(contains('4242424242424242')));
    });
  });

  group('LocalWalletRepository', () {
    test('seeds from the bundled JSON on first run', () async {
      final cards = await LocalWalletRepository().load();
      expect(cards, isNotEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocalWalletRepository.storageKey), isNotNull,
          reason: 'the seed must be written through, not just returned');
    });

    test('an added card survives a new repository instance', () async {
      await LocalWalletRepository().add(sampleCard);
      // A fresh instance stands in for an app relaunch.
      final reloaded = await LocalWalletRepository().load();
      expect(reloaded.map((c) => c.id), contains(sampleCard.id));
    });

    test('removal persists', () async {
      final repo = LocalWalletRepository();
      await repo.add(sampleCard);
      await repo.remove(sampleCard.id);
      expect((await LocalWalletRepository().load()).map((c) => c.id),
          isNot(contains(sampleCard.id)));
    });

    test('restyle persists', () async {
      final repo = LocalWalletRepository();
      final seeded = await repo.load();
      await repo.restyle(seeded.first.id, CardSkin.stone);
      expect((await LocalWalletRepository().load()).first.skin, CardSkin.stone);
    });

    test('reset discards user changes and restores the seed', () async {
      final repo = LocalWalletRepository();
      final seeded = await repo.load();
      await repo.add(sampleCard);
      expect((await repo.load()).length, seeded.length + 1);

      final reset = await repo.resetToSeed();
      expect(reset.length, seeded.length);
      expect(reset.map((c) => c.id), isNot(contains(sampleCard.id)));
    });

    test('corrupt stored data falls back to the seed instead of crashing',
        () async {
      SharedPreferences.setMockInitialValues({
        LocalWalletRepository.storageKey: 'not json at all',
      });
      expect(await LocalWalletRepository().load(), isNotEmpty);
    });
  });

  group('MediaRef', () {
    test('parses both schemes and round-trips', () {
      final a = MediaRef.parse('asset:cards/aurora.png')!;
      expect(a.source, MediaSource.asset);
      expect(a.path, 'cards/aurora.png');
      expect(a.assetKey, 'assets/images/cards/aurora.png');
      expect(MediaRef.parse(a.encoded), a);

      final f = MediaRef.parse('file:media/ab12.png')!;
      expect(f.source, MediaSource.file);
      expect(f.path, 'media/ab12.png');
      expect(MediaRef.parse(f.encoded), f);
    });

    test('treats a bare path as a bundled asset', () {
      expect(MediaRef.parse('cards/x.png')!.source, MediaSource.asset);
    });

    test('null and empty mean no media', () {
      expect(MediaRef.parse(null), isNull);
      expect(MediaRef.parse(''), isNull);
    });
  });

  group('RemoteWalletRepository', () {
    test('is an explicit template, not a silent no-op', () async {
      const repo = RemoteWalletRepository(baseUrl: 'https://example.test');
      await expectLater(repo.load(), throwsUnimplementedError);
    });
  });
}
