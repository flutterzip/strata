import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/palette.dart';
import '../models/payment_card.dart';
import '../services/local_wallet_repository.dart';
import '../services/wallet_repository.dart';

/// The app's storage. Swap this one line for [RemoteWalletRepository] — or
/// any other implementation — and no screen changes.
final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => LocalWalletRepository(),
);

/// The wallet's cards. Async so the UI exercises real loading/error states
/// rather than pretending data is always present.
class WalletNotifier extends AsyncNotifier<List<PaymentCard>> {
  WalletRepository get _repo => ref.read(walletRepositoryProvider);

  @override
  Future<List<PaymentCard>> build() => _repo.load();

  Future<void> add(PaymentCard card) async {
    final previous = state.valueOrNull ?? const <PaymentCard>[];
    state = AsyncData([...previous, card]);
    try {
      await _repo.add(card);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Update: apply an arbitrary change to one card.
  ///
  /// Optimistic, and rolls back then **rethrows** when storage refuses. It
  /// used to swallow the failure into [AsyncError], which meant a caller
  /// that had to know — a send, which must not leave a transfer recorded
  /// against a balance that never moved — could not find out.
  Future<void> edit(
    String id,
    PaymentCard Function(PaymentCard) change,
  ) async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    state = AsyncData([
      for (final c in previous) c.id == id ? change(c) : c,
    ]);
    try {
      await _repo.update(id, change);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> restyle(String id, CardSkin skin) async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    state = AsyncData([
      for (final c in previous) c.id == id ? c.copyWith(skin: skin) : c,
    ]);
    try {
      await _repo.restyle(id, skin);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Discard user changes and restore the bundled demo data.
  Future<void> resetDemoData() async {
    final repo = _repo;
    if (repo is! LocalWalletRepository) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(repo.resetToSeed);
  }

  Future<void> remove(String id) async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    state = AsyncData([
      for (final c in previous)
        if (c.id != id) c,
    ]);
    await _repo.remove(id);
  }
}

final walletProvider = AsyncNotifierProvider<WalletNotifier, List<PaymentCard>>(
    WalletNotifier.new);

/// Total balance across cards sharing the primary currency.
final totalBalanceProvider = Provider<({int minor, String currency})>((ref) {
  final cards = ref.watch(walletProvider).valueOrNull ?? const <PaymentCard>[];
  if (cards.isEmpty) return (minor: 0, currency: 'USD');
  final currency = cards.first.currency;
  final minor = cards
      .where((c) => c.currency == currency)
      .fold<int>(0, (sum, c) => sum + c.balanceMinor);
  return (minor: minor, currency: currency);
});

/// Index of the card currently centred in the carousel. Kept in app state so
/// the screens below the carousel can bind to it.
final focusedCardIndexProvider = StateProvider<int>((ref) => 0);

@immutable
class CardsRoute {
  const CardsRoute._();
  static const String path = '/cards';
}
