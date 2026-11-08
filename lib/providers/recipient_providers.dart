import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipient.dart';
import '../services/local_recipient_repository.dart';
import '../services/recipient_repository.dart';
import '../shared/utils/recipient_lookup.dart';
import 'profile_providers.dart';

/// Storage for recipients. Swap for a directory service and no screen
/// changes.
final recipientRepositoryProvider = Provider<RecipientRepository>(
  (ref) => LocalRecipientRepository(),
);

/// Everyone who can be sent to, most recently paid first.
class RecipientNotifier extends AsyncNotifier<List<Recipient>> {
  RecipientRepository get _repo => ref.read(recipientRepositoryProvider);

  @override
  Future<List<Recipient>> build() async =>
      RecipientLookup.ordered(await _repo.load());

  List<Recipient> _ordered(Iterable<Recipient> items) =>
      RecipientLookup.ordered(items.toList());

  Future<void> create(Recipient recipient) async {
    final previous = state.valueOrNull ?? const <Recipient>[];
    state = AsyncData(_ordered([...previous, recipient]));
    try {
      await _repo.add(recipient);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> edit(String id, Recipient Function(Recipient) change) async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    state = AsyncData(_ordered([
      for (final r in previous) r.id == id ? change(r) : r,
    ]));
    try {
      await _repo.update(id, change);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> remove(String id) async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    state = AsyncData([
      for (final r in previous)
        if (r.id != id) r,
    ]);
    try {
      await _repo.remove(id);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  /// Record that money just went to this recipient, so the list reorders.
  Future<void> markUsed(String id, {DateTime? at}) =>
      edit(id, (r) => r.copyWith(lastUsedAt: at ?? DateTime.now()));

  /// Discard user changes and restore the bundled demo data.
  Future<void> resetDemoData() async {
    final repo = _repo;
    if (repo is! LocalRecipientRepository) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () async => RecipientLookup.ordered(await repo.resetToSeed()));
  }
}

final recipientsProvider =
    AsyncNotifierProvider<RecipientNotifier, List<Recipient>>(
        RecipientNotifier.new);

/// What someone has typed into the recipient field.
final recipientQueryProvider = StateProvider<String>((ref) => '');

/// The resolved match for that text — found, unverified, you, or nobody.
///
/// Derived rather than held, so the state on screen can never disagree with
/// what is in the field.
final recipientMatchProvider = Provider<RecipientMatch>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  return RecipientLookup.resolve(
    ref.watch(recipientQueryProvider),
    directory: ref.watch(recipientsProvider).valueOrNull ?? const [],
    ownerHandle: profile?.handle ?? '',
    ownerEmail: profile?.email ?? '',
  );
});

/// The recipients to list under the field as someone types.
final recipientSuggestionsProvider =
    Provider<List<Recipient>>((ref) => RecipientLookup.suggest(
          ref.watch(recipientQueryProvider),
          ref.watch(recipientsProvider).valueOrNull ?? const [],
        ));
