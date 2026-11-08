import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/design_tokens.dart';
import '../../../config/motion.dart';
import '../../../shared/widgets/pressable.dart';

/// Dot row showing how many PIN digits have been entered.
///
/// Shakes on a wrong code. The shake is the feedback people actually read —
/// faster than text and unmistakable — so the error message supports it
/// rather than carrying the whole load.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    required this.length,
    this.hasError = false,
  });

  final int filled;
  final int length;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$filled of $length digits entered',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                child: AnimatedContainer(
                  duration: context.motion(Motion.quick),
                  curve: Motion.emphasised,
                  width: i < filled ? 16 : 13,
                  height: i < filled ? 16 : 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasError
                        ? scheme.error
                        : i < filled
                            ? scheme.primary
                            : Colors.transparent,
                    border: Border.all(
                      color: hasError
                          ? scheme.error
                          : i < filled
                              ? scheme.primary
                              : scheme.outline,
                      width: 1.6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shakes its child horizontally when [trigger] changes.
class Shaker extends StatefulWidget {
  const Shaker({super.key, required this.trigger, required this.child});

  final Object? trigger;
  final Widget child;

  @override
  State<Shaker> createState() => _ShakerState();
}

class _ShakerState extends State<Shaker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(Shaker old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger != null) {
      if (context.reduceMotion) return;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          // A decaying oscillation, so it reads as a physical rebuff rather
          // than a looped wobble.
          final decay = 1 - _c.value;
          final dx = 11 * decay * math.sin(_c.value * math.pi * 7);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: widget.child,
      );
}

/// The numeric keypad.
///
/// A real keypad rather than the system keyboard: the targets are far
/// larger, the layout never shifts, and the screen cannot be covered by a
/// keyboard appearing underneath the dots.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final rows = <List<String>>[
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [onBiometric != null ? 'bio' : '', '0', 'del'],
    ];

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                      child: _Key(
                        value: key,
                        enabled: enabled,
                        onDigit: onDigit,
                        onBackspace: onBackspace,
                        onBiometric: onBiometric,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.value,
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox(height: 62);

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isAction = value == 'del' || value == 'bio';

    return Pressable(
      enforceMinTarget: false,
      pressedScale: 0.92,
      haptic: false,
      semanticLabel: switch (value) {
        'del' => 'Delete',
        'bio' => 'Use biometrics',
        _ => value,
      },
      onTap: !enabled
          ? null
          : () {
              switch (value) {
                case 'del':
                  HapticFeedback.selectionClick();
                  onBackspace();
                case 'bio':
                  HapticFeedback.mediumImpact();
                  onBiometric?.call();
                default:
                  HapticFeedback.lightImpact();
                  onDigit(value);
              }
            },
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: isAction ? Colors.transparent : scheme.surfaceContainer,
          borderRadius: Radii.brLg,
          border: Border.all(
            color: isAction ? Colors.transparent : scheme.outlineVariant,
          ),
        ),
        alignment: Alignment.center,
        child: switch (value) {
          'del' => Icon(Icons.backspace_outlined,
              size: 21, color: scheme.onSurfaceVariant),
          'bio' =>
            Icon(Icons.fingerprint_rounded, size: 25, color: scheme.primary),
          _ => Text(value,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
        },
      ),
    );
  }
}
