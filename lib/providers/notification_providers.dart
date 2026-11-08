import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../services/json_store.dart';
import '../shared/utils/ids.dart';

final notificationStoreProvider =
    Provider<JsonCollectionStore<AppNotification>>(
  (ref) => JsonCollectionStore<AppNotification>(
    storageKey: 'strata.notifications.v1',
    seedFile: 'notifications.json',
    seedKey: 'notifications',
    fromJson: AppNotification.fromJson,
    toJson: (n) => n.toJson(),
  ),
);

class NotificationNotifier extends AsyncNotifier<List<AppNotification>> {
  JsonCollectionStore<AppNotification> get _store =>
      ref.read(notificationStoreProvider);

  @override
  Future<List<AppNotification>> build() async {
    final items = await _store.load();
    items.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return items;
  }

  Future<void> _commit(List<AppNotification> next) async {
    state = AsyncData(next);
    await _store.save(next);
  }

  /// Add a notification, newest first and unread.
  ///
  /// Used by the flows that move money: a transfer the person cannot find
  /// any trace of afterwards is indistinguishable from one that failed.
  Future<AppNotification> push({
    required NotificationKind kind,
    required String title,
    required String body,
    DateTime? sentAt,
  }) async {
    final items = state.valueOrNull ?? const <AppNotification>[];
    final notification = AppNotification(
      id: Ids.next('n'),
      kind: kind,
      title: title,
      body: body,
      sentAt: sentAt ?? DateTime.now(),
      read: false,
    );
    await _commit(
        [notification, ...items]..sort((a, b) => b.sentAt.compareTo(a.sentAt)));
    return notification;
  }

  Future<void> markRead(String id, {bool read = true}) async {
    final items = state.valueOrNull;
    if (items == null) return;
    await _commit([
      for (final n in items) n.id == id ? n.copyWith(read: read) : n,
    ]);
  }

  Future<void> markAllRead() async {
    final items = state.valueOrNull;
    if (items == null) return;
    await _commit([for (final n in items) n.copyWith(read: true)]);
  }

  Future<void> remove(String id) async {
    final items = state.valueOrNull;
    if (items == null) return;
    await _commit([
      for (final n in items)
        if (n.id != id) n,
    ]);
  }

  Future<void> resetDemoData() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final items = await _store.resetToSeed();
      items.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      return items;
    });
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationNotifier, List<AppNotification>>(
        NotificationNotifier.new);

/// Count of unread notifications, for the badge.
final unreadCountProvider = Provider<int>((ref) =>
    ref
        .watch(notificationsProvider)
        .valueOrNull
        ?.where((n) => !n.read)
        .length ??
    0);
