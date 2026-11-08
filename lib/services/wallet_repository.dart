import '../config/palette.dart';
import '../models/card_brand.dart';
import '../models/payment_card.dart';

/// Contract for card storage, so a real backend can replace the in-memory
/// implementation without touching the UI layer.
abstract interface class WalletRepository {
  Future<List<PaymentCard>> load();
  Future<PaymentCard> add(PaymentCard card);
  Future<void> remove(String id);
  Future<PaymentCard> restyle(String id, CardSkin skin);

  /// Apply an arbitrary change to one card. The general update operation;
  /// [restyle] is a convenience on top of it.
  Future<PaymentCard> update(
      String id, PaymentCard Function(PaymentCard) change);
}

/// In-memory implementation seeded with realistic demo data.
class InMemoryWalletRepository implements WalletRepository {
  InMemoryWalletRepository({List<PaymentCard>? seed, this.latency})
      : _cards = [...(seed ?? _defaultSeed)];

  final List<PaymentCard> _cards;

  /// Simulated network delay, so loading states are exercised in the demo.
  final Duration? latency;

  Future<void> _settle() async {
    if (latency != null) await Future<void>.delayed(latency!);
  }

  static final List<PaymentCard> _defaultSeed = [
    const PaymentCard(
      id: 'c_forest',
      last4: '8152',
      brand: CardBrand.mastercard,
      funding: CardFunding.debit,
      holder: 'OLYMPICSON',
      expiryMonth: 7,
      expiryYear: 2029,
      skin: CardSkin.forest,
      balanceMinor: 2409267,
      currency: 'USD',
    ),
    const PaymentCard(
      id: 'c_moss',
      last4: '4410',
      brand: CardBrand.visa,
      funding: CardFunding.virtualDebit,
      holder: 'OLYMPICSON',
      expiryMonth: 11,
      expiryYear: 2028,
      skin: CardSkin.moss,
      balanceMinor: 506254,
      currency: 'EUR',
    ),
    const PaymentCard(
      id: 'c_sage',
      last4: '7731',
      brand: CardBrand.visa,
      funding: CardFunding.credit,
      holder: 'OLYMPICSON',
      expiryMonth: 3,
      expiryYear: 2030,
      skin: CardSkin.sage,
      balanceMinor: 118940,
      currency: 'USD',
    ),
  ];

  @override
  Future<List<PaymentCard>> load() async {
    await _settle();
    return List.unmodifiable(_cards);
  }

  @override
  Future<PaymentCard> add(PaymentCard card) async {
    await _settle();
    _cards.add(card);
    return card;
  }

  @override
  Future<void> remove(String id) async {
    await _settle();
    _cards.removeWhere((c) => c.id == id);
  }

  @override
  Future<PaymentCard> restyle(String id, CardSkin skin) =>
      update(id, (c) => c.copyWith(skin: skin));

  @override
  Future<PaymentCard> update(
    String id,
    PaymentCard Function(PaymentCard) change,
  ) async {
    await _settle();
    final i = _cards.indexWhere((c) => c.id == id);
    if (i == -1) throw StateError('No card $id');
    return _cards[i] = change(_cards[i]);
  }
}
