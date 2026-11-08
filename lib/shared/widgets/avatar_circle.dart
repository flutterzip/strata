import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/design_tokens.dart';
import '../../providers/media_providers.dart';
import '../../services/media_ref.dart';
import 'pressable.dart';

/// A round avatar with an initials fallback.
///
/// Three things can be true, and all three have to look deliberate:
///
/// 1. there is a picture on disk;
/// 2. there is a picture that has just been chosen and is still being
///    written ([pendingBytes]);
/// 3. there is no picture, or the file behind the record has gone — a
///    restored backup, cleared storage — and the initials stand in.
///
/// Case 3 is the one that breaks in most apps, because a record is allowed
/// to outlive its file. `MediaRef.imageProvider()` already answers null when
/// the file is missing, and this never shows a broken-image box.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.initials,
    this.avatar,
    this.pendingBytes,
    this.size = 62,
    this.onTap,
    this.semanticLabel,
    this.semanticHint,
    this.showEditAffordance = false,
  });

  final String initials;
  final MediaRef? avatar;

  /// Bytes to show in place of [avatar], for a picture chosen moments ago
  /// whose file may not be written yet.
  final Uint8List? pendingBytes;

  final double size;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final String? semanticHint;

  /// Draws a small camera badge, for the one avatar that can be changed.
  final bool showEditAffordance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: _Content(
        initials: initials,
        avatar: avatar,
        pendingBytes: pendingBytes,
        size: size,
      ),
    );

    if (showEditAffordance) {
      circle = Stack(
        clipBehavior: Clip.none,
        children: [
          circle,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * 0.36,
              height: size * 0.36,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Icon(
                Icons.photo_camera_outlined,
                size: size * 0.18,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      );
    }

    if (onTap == null) {
      return Semantics(
        label: semanticLabel,
        image: avatar != null || pendingBytes != null,
        child: ExcludeSemantics(child: circle),
      );
    }

    return Pressable(
      onTap: onTap,
      pressedScale: 0.94,
      semanticLabel: semanticLabel,
      semanticHint: semanticHint,
      child: circle,
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.initials,
    required this.avatar,
    required this.pendingBytes,
    required this.size,
  });

  final String initials;
  final MediaRef? avatar;
  final Uint8List? pendingBytes;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pendingBytes != null) {
      return Image.memory(
        pendingBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    if (avatar == null) return _Initials(initials: initials, size: size);

    // Null covers "still resolving", "the file is gone" and "it failed". The
    // initials are right in every one of those, and they are the same size,
    // so nothing shifts when the picture does arrive.
    final provider = ref.watch(mediaImageProvider(avatar!)).valueOrNull;
    if (provider == null) return _Initials(initials: initials, size: size);

    return Image(
      image: provider,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, _, __) =>
          _Initials(initials: initials, size: size),
    );
  }
}

/// Initials rather than a stock silhouette: an avatar with no photo should
/// still feel like a person, not a placeholder.
class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      initials,
      style: TextStyle(
        // Proportional to the circle, so one widget serves a 32dp list row
        // and a 120dp crop preview.
        fontSize: size * 0.36,
        height: 1,
        fontWeight: FontWeight.w700,
        color: scheme.onPrimaryContainer,
      ),
    );
  }
}

/// Shared sizing, so a row avatar and a header avatar cannot drift apart.
abstract final class AvatarSize {
  static const double row = 40;
  static const double header = 62;
  static const double hero = 120;

  /// Minimum tappable avatar, for the one that opens a picker.
  static const double tappable = Hit.min;
}
