import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';
import 'count_badge.dart';
import 'pressable.dart';

/// One row in a settings list. Defined once so every row in the app has the
/// same height, icon treatment, trailing affordance and hit target.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.badgeCount,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Shows a count pill when greater than zero.
  final int? badgeCount;

  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tint = destructive ? scheme.error : scheme.onSurface;

    return Pressable(
      onTap: onTap,
      pressedScale: 0.985,
      enforceMinTarget: false,
      semanticLabel: title,
      semanticHint: subtitle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: destructive
                    ? scheme.errorContainer
                    : scheme.surfaceContainerHigh,
                borderRadius: Radii.brMd,
              ),
              child: Icon(icon, size: 19, color: tint),
            ),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: text.bodyLarge
                          ?.copyWith(color: tint, fontWeight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!, style: text.bodySmall),
                  ],
                ],
              ),
            ),
            if (badgeCount != null && badgeCount! > 0) ...[
              CountBadge(count: badgeCount!),
              const SizedBox(width: Space.md),
            ],
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// A titled group of [SettingsRow]s on a card surface.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  /// Omitted when the rows sit under a heading the sheet already gave them.
  final String? title;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: Space.xs, bottom: Space.sm),
            child: Text(title!.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.0, fontWeight: FontWeight.w700)),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: Radii.brXl,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}
