import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';

/// A small unread/pending count.
///
/// Defined once so the bell, the settings row and anything else that counts
/// something look identical. Renders nothing at zero rather than a "0".
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, this.max = 99});

  final int count;

  /// Counts above this show as "max+", so the pill cannot grow unbounded.
  final int max;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final label = count > max ? '$max+' : '$count';

    return Semantics(
      label: '$count unread',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minWidth: 18),
          height: 18,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: Radii.brPill,
            // A hairline in the surface colour keeps the pill legible when it
            // overlaps an icon.
            border: Border.all(color: scheme.surface, width: 1.5),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}

/// An icon button carrying a [CountBadge] in its top-right corner.
class BadgedIconButton extends StatelessWidget {
  const BadgedIconButton({
    super.key,
    required this.icon,
    required this.count,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final int count;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0 ? '$tooltip, $count unread' : tooltip,
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onPressed,
              tooltip: tooltip,
              icon: Icon(icon),
            ),
            if (count > 0)
              Positioned(
                right: 4,
                top: 4,
                child: IgnorePointer(child: CountBadge(count: count)),
              ),
          ],
        ),
      ),
    );
  }
}
