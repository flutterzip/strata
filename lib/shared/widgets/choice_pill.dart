import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import 'pressable.dart';

/// A selectable pill, for option lists whose labels vary in length.
///
/// [SegmentedToggle] divides a fixed width between equal segments, which is
/// right for two or three symmetrical choices and wrong for "every card" or
/// "every category" — those wrap, vary in width and grow with the data.
///
/// Selection is shown by surface and weight rather than by a second hue:
/// there is one accent in this app and the chart already owns it.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Spoken form, when [label] alone is not enough out of context.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: Pressable(
          onTap: onTap,
          pressedScale: 0.96,
          // The painted pill stays compact; the box around it carries the
          // 48dp target. Growing the pill itself to 48 would make a wrap of
          // them twice as tall as it needs to be.
          enforceMinTarget: false,
          child: SizedBox(
            height: Hit.min,
            child: Center(
              child: AnimatedContainer(
                duration: context.motion(Motion.quick),
                curve: Motion.standard,
                padding: const EdgeInsets.symmetric(
                    horizontal: Space.lg, vertical: Space.sm),
                decoration: BoxDecoration(
                  borderRadius: Radii.brPill,
                  color: selected
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHigh,
                  border: Border.all(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon,
                          size: 15,
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant),
                      const SizedBox(width: Space.sm),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge?.copyWith(
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pill that removes one active filter facet.
class RemovablePill extends StatelessWidget {
  const RemovablePill({
    super.key,
    required this.label,
    required this.onRemove,
    required this.semanticLabel,
  });

  final String label;
  final VoidCallback onRemove;

  /// Says what removing it does — "Remove the Food filter", not "Food".
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Pressable(
          onTap: onRemove,
          pressedScale: 0.94,
          // As above: a compact chip inside a full-size target.
          enforceMinTarget: false,
          child: SizedBox(
            height: Hit.min,
            child: Center(
              child: Container(
                padding: const EdgeInsets.only(
                    left: Space.md, right: Space.sm, top: 6, bottom: 6),
                decoration: BoxDecoration(
                  borderRadius: Radii.brPill,
                  color: scheme.primaryContainer,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium
                              ?.copyWith(color: scheme.onPrimaryContainer)),
                    ),
                    const SizedBox(width: Space.xs),
                    Icon(Icons.close_rounded,
                        size: 15, color: scheme.onPrimaryContainer),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
