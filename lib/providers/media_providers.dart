import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/avatar_store.dart';
import '../services/media_ref.dart';
import '../services/photo_picker.dart';

/// Where user-supplied media is written. Swap for an uploader and no screen
/// changes.
final mediaStoreProvider = Provider<MediaStore>((ref) => LocalMediaStore());

/// The camera / library gateway. Overridden in tests with fixed bytes.
final photoPickerProvider =
    Provider<PhotoPicker>((ref) => PlatformPhotoPicker());

/// The avatar being shown before its file is on disk.
///
/// Held outside [UserProfile] on purpose: the profile stores a [MediaRef],
/// and there is no reference to store until the write succeeds. This lets
/// the new picture appear the instant it is cropped while the encode and the
/// write happen behind it, and it is what gets dropped if the write fails.
///
/// It is also kept *after* a successful write rather than cleared, because
/// clearing it would hand the circle back to an asynchronous file read and
/// flash the initials for a frame. The file is authoritative on next launch.
final pendingAvatarProvider = StateProvider<Uint8List?>((ref) => null);

/// The resolved image for one media reference, or null when there is nothing
/// to show and the fallback should stand in.
///
/// A provider rather than a `FutureBuilder` inside the widget on purpose: a
/// `FutureBuilder` given a newly-created future on every build completes,
/// rebuilds, creates another, and never settles — which hangs the widget in
/// a test and burns frames in the app. Riverpod caches per reference, so the
/// load happens once per picture and again only when the reference changes.
final mediaImageProvider = FutureProvider.family<ImageProvider?, MediaRef>(
    (ref, mediaRef) => ref.watch(mediaStoreProvider).imageFor(mediaRef));
