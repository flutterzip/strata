import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/design_tokens.dart';
import '../../config/motion.dart';

typedef Segment = ({IconData icon, String label});

/// A two-or-more way switch with a sliding thumb.
///
/// Built here rather than using Material's segmented button so it shares the
/// app's spring, surfaces and hairline, and so the thumb travels rather than
/// cross-fading.
class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.segments,
    required this.index,
    required this.onChanged,
  });

  final List<Segment> segments;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reduce = context.reduceMotion;

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: Radii.brPill,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / segments.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: reduce ? Duration.zero : Motion.base,
                curve: Motion.standard,
                left: slot * index,
                width: slot,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: Radii.brPill,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (i, seg) in segments.indexed)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        inMutuallyExclusiveGroup: true,
                        label: seg.label,
                        child: ExcludeSemantics(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (i == index) return;
                              HapticFeedback.selectionClick();
                              onChanged(i);
                            },
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(seg.icon,
                                      size: 15,
                                      color: i == index
                                          ? scheme.onSurface
                                          : scheme.onSurfaceVariant),
                                  const SizedBox(width: Space.xs),
                                  Text(
                                    seg.label,
                                    style: text.labelSmall?.copyWith(
                                      color: i == index
                                          ? scheme.onSurface
                                          : scheme.onSurfaceVariant,
                                      fontWeight: i == index
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
