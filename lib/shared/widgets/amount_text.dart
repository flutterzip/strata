import 'package:flutter/material.dart';

import '../utils/money.dart';

/// A currency amount with de-emphasised minor units.
///
/// The cents carry almost no information at a glance, so they are dimmed —
/// the eye lands on the figure that matters. Shrinks rather than overflows
/// when text scaling is turned up, and exposes a single spoken label so a
/// screen reader reads one amount instead of two fragments.
class AmountText extends StatelessWidget {
  const AmountText({
    super.key,
    required this.minor,
    required this.currency,
    this.style,
    this.semanticsPrefix,
  });

  /// Amount in the smallest currency unit.
  final int minor;
  final String currency;
  final TextStyle? style;

  /// Prepended to the spoken label, e.g. "Total balance".
  final String? semanticsPrefix;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.displaySmall;
    final (major, cents) = Money.parts(minor, currency);
    final formatted = Money.format(minor, currency);
    final label =
        semanticsPrefix == null ? formatted : '$semanticsPrefix $formatted';

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: RichText(
            text: TextSpan(
              style: base,
              children: [
                TextSpan(text: major),
                TextSpan(
                  text: cents,
                  style: base?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
