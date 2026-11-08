import 'package:shared_preferences/shared_preferences.dart';

import '../config/palette.dart';
import '../models/payment_card.dart';
import 'json_store.dart';
import 'wallet_repository.dart';

/// Persists the wallet locally, seeded from `assets/data/cards.json`.
///
/// All the seed-then-persist machinery lives in [JsonCollectionStore]; this
/// class only knows about cards. Nothing secret is stored: as everywhere in
/// this app, the full card number and security code are never written.
class LocalWalletRepository implements WalletRepository {
  LocalWalletRepository({SharedPreferences? prefs})
      : _store = JsonCollectionStore<PaymentCard>(
          storageKey: storageKey,
          seedFile: seedFile,
          seedKey: 'cards',
          fromJson: PaymentCard.fromJson,
          toJson: (c) => c.toJson(),
          prefs: prefs,
        );

  static const String storageKey = 'strata.wallet.v1';
  static const String seedFile = 'cards.json';

  final JsonCollectionStore<PaymentCard> _store;

  @override
  Future<List<PaymentCard>> load() => _store.load();

  @override
  Future<PaymentCard> add(PaymentCard card) async {
    final cards = await load()
      ..add(card);
    await _store.save(cards);
    return card;
  }

  @override
  Future<void> remove(String id) async {
    final cards = await load()
      ..removeWhere((c) => c.id == id);
    await _store.save(cards);
  }

  @override
  Future<PaymentCard> restyle(String id, CardSkin skin) async =>
      update(id, (c) => c.copyWith(skin: skin));

  @override
  Future<PaymentCard> update(
    String id,
    PaymentCard Function(PaymentCard) change,
  ) async {
    final cards = await load();
    final i = cards.indexWhere((c) => c.id == id);
    if (i == -1) throw StateError('No card $id');
    final updated = cards[i] = change(cards[i]);
    await _store.save(cards);
    return updated;
  }

  /// Discard user changes and restore the bundled demo data.
  Future<List<PaymentCard>> resetToSeed() => _store.resetToSeed();
}
