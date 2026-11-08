import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';

/// A quiet inline note above or below a form.
///
/// Sized to the sentence it carries, not to the screen. An earlier version
/// was a full-width boxed alert with 16dp padding all round, which for a
/// single line read as a warning panel and left its icon floating above the
/// text. This one is compact, vertically centred against short copy, and
/// only grows when the message genuinely wraps.
///
/// Two tones, both inside the palette: notes use the accent wash, problems
/// use the ochre container. Colour never carries the meaning alone — each
/// has an icon and plain words.
class AuthBanner extends StatelessWidget {
  const AuthBanner._({
    required this.message,
    required this.icon,
    required this.isError,
    required this.shrink,
  });

  /// A note. [shrink] sizes it to its content and centres it, for places
  /// like the PIN screen where a full-width bar would dominate.
  factory AuthBanner.info({required String message, bool shrink = false}) =>
      AuthBanner._(
        message: message,
        icon: Icons.info_outline_rounded,
        isError: false,
        shrink: shrink,
      );

  factory AuthBanner.error({required String message, bool shrink = false}) =>
      AuthBanner._(
        message: message,
        icon: Icons.error_outline_rounded,
        isError: true,
        shrink: shrink,
      );

  final String message;
  final IconData icon;
  final bool isError;
  final bool shrink;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isError ? scheme.errorContainer : scheme.primaryContainer;
    final fg = isError ? scheme.onErrorContainer : scheme.onPrimaryContainer;

    final row = Row(
      mainAxisSize: shrink ? MainAxisSize.min : MainAxisSize.max,
      // Centre, not start: against one line of text a top-aligned icon
      // reads as misaligned.
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: fg),
        const SizedBox(width: Space.sm),
        Flexible(
          child: Text(
            message,
            textAlign: shrink ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: fg,
                  height: 1.35,
                ),
          ),
        ),
      ],
    );

    final box = Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Space.md, vertical: Space.sm + 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: Radii.brMd,
      ),
      child: row,
    );

    return Semantics(
      liveRegion: true,
      container: true,
      child: shrink ? Center(child: box) : box,
    );
  }
}
