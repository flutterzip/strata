import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/json_store.dart';
import 'media_providers.dart';

final profileStoreProvider = Provider<JsonDocumentStore<UserProfile>>(
  (ref) => JsonDocumentStore<UserProfile>(
    storageKey: 'strata.profile.v1',
    seedFile: 'profile.json',
    fromJson: UserProfile.fromJson,
    toJson: (p) => p.toJson(),
  ),
);

class ProfileNotifier extends AsyncNotifier<UserProfile> {
  JsonDocumentStore<UserProfile> get _store => ref.read(profileStoreProvider);

  @override
  Future<UserProfile> build() => _store.load();

  /// Apply an edit and persist it.
  Future<void> edit(UserProfile Function(UserProfile) change) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = change(current);
    state = AsyncData(next);
    await _store.save(next);
  }

  /// Store [bytes] as the avatar.
  ///
  /// The picture appears immediately — [pendingAvatarProvider] carries it —
  /// while the encode and the write happen behind it. A failure drops the
  /// optimistic image and rethrows, so the sheet that asked can say so and
  /// the profile is left exactly as it was.
  ///
  /// The file that was replaced is deleted by [MediaStore.replace], and only
  /// after the new one is safely on disk. Orphaned media is invisible and
  /// grows forever.
  Future<void> setAvatarBytes(Uint8List bytes) async {
    final current = state.valueOrNull;
    if (current == null) return;

    ref.read(pendingAvatarProvider.notifier).state = bytes;
    try {
      final stored = await ref.read(mediaStoreProvider).replace(
            bytes,
            entity: 'avatar',
            id: 'me',
            previous: current.avatar,
          );
      final next = current.copyWith(avatar: stored);
      state = AsyncData(next);
      await _store.save(next);
    } catch (_) {
      ref.read(pendingAvatarProvider.notifier).state = null;
      rethrow;
    }
  }

  /// Drop the avatar and the file behind it, falling back to initials.
  Future<void> removeAvatar() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final previous = current.avatar;
    final next = current.copyWith(clearAvatar: true);
    state = AsyncData(next);
    ref.read(pendingAvatarProvider.notifier).state = null;
    try {
      await _store.save(next);
      await ref.read(mediaStoreProvider).delete(previous);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      edit((p) => p.copyWith(themeMode: mode));

  Future<void> setShowDemoHints(bool value) =>
      edit((p) => p.copyWith(showDemoHints: value));

  Future<void> resetDemoData() async {
    // The optimistic avatar is session state, not stored state; leaving it
    // set would keep showing a picture the reset just discarded.
    ref.read(pendingAvatarProvider.notifier).state = null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_store.resetToSeed);
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, UserProfile>(ProfileNotifier.new);

/// Theme mode, read from the stored profile. Falls back to system while the
/// profile is still loading so the first frame is never the wrong theme.
final themeModeProvider = Provider<ThemeMode>((ref) =>
    ref.watch(profileProvider).valueOrNull?.themeMode ?? ThemeMode.system);

/// Whether demo-only hints are shown. Defaults to on while the profile
/// loads, so a first-time viewer is never left guessing.
final showDemoHintsProvider = Provider<bool>(
    (ref) => ref.watch(profileProvider).valueOrNull?.showDemoHints ?? true);
