import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../providers/media_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../services/image_encoder.dart';
import '../../../services/photo_picker.dart';
import '../../../shared/widgets/strata_sheet.dart';
import '../avatar_crop_screen.dart';

/// Keys for the avatar flow, declared in one place so the test and the
/// screens cannot drift apart.
abstract final class AvatarKeys {
  static const Key avatar = Key('profile-avatar');
  static const Key camera = Key('avatar-camera');
  static const Key choose = Key('avatar-choose');
  static const Key remove = Key('avatar-remove');
}

/// Change or remove the profile picture.
///
/// Remove only appears when there is something to remove — an action that
/// does nothing is worse than an action that is absent.
class AvatarSheet extends ConsumerStatefulWidget {
  const AvatarSheet({super.key, required this.hasAvatar});

  final bool hasAvatar;

  @override
  ConsumerState<AvatarSheet> createState() => _AvatarSheetState();
}

class _AvatarSheetState extends ConsumerState<AvatarSheet> {
  String? _problem;
  bool _busy = false;

  Future<void> _pick(PhotoOrigin origin) async {
    setState(() {
      _busy = true;
      _problem = null;
    });

    Uint8List? picked;
    try {
      picked = await ref.read(photoPickerProvider).pick(origin);
    } on PhotoAccessDenied catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // A refusal is a normal path with a way forward, not a dead end:
        // say what is missing and leave the other route on screen.
        _problem = origin == PhotoOrigin.camera
            ? '${e.message} You can still choose an existing photo.'
            : '${e.message} Change this in Settings, or take a new photo '
                'instead.';
      });
      return;
    } on PhotoPickFailed catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = e.message;
      });
      return;
    }

    // Dismissed without choosing. Nothing to say about it.
    if (picked == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    if (!mounted) return;
    // Never centre-crop someone's face without showing them: the circle is
    // chosen on the next screen.
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => AvatarCropScreen(bytes: picked!)),
    );
    if (!mounted) return;
    if (cropped == null) {
      setState(() => _busy = false);
      return;
    }

    try {
      await ref.read(profileProvider.notifier).setAvatarBytes(cropped);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ImageDecodeException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      // The optimistic picture has already been dropped by the notifier.
      setState(() {
        _busy = false;
        _problem = 'Could not save that photo. Your old one is still here.';
      });
    }
  }

  Future<void> _remove() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await ref.read(profileProvider.notifier).removeAvatar();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = 'Could not remove that photo. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return StrataSheet(
      icon: Icons.photo_camera_outlined,
      title: 'Profile picture',
      message: widget.hasAvatar
          ? 'Replace it, or remove it and go back to your initials.'
          : 'Add a photo, or keep your initials.',
      body: _problem == null
          ? null
          : Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 18, color: scheme.error),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(_problem!,
                      style: text.bodySmall?.copyWith(color: scheme.error)),
                ),
              ],
            ),
      actions: [
        FilledButton.icon(
          key: AvatarKeys.camera,
          onPressed: _busy ? null : () => _pick(PhotoOrigin.camera),
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: const Text('Take a photo'),
        ),
        OutlinedButton.icon(
          key: AvatarKeys.choose,
          onPressed: _busy ? null : () => _pick(PhotoOrigin.gallery),
          icon: const Icon(Icons.photo_library_outlined, size: 18),
          label: const Text('Choose a photo'),
        ),
        if (widget.hasAvatar)
          OutlinedButton.icon(
            key: AvatarKeys.remove,
            onPressed: _busy ? null : _remove,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Remove photo'),
            style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
