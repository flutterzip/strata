import 'package:flutter/material.dart';

import '../../config/design_tokens.dart';

/// A centred empty, error or informational state.
///
/// Every async surface needs these three, and hand-rolling them per screen is
/// how an app ends up with four slightly different ways of saying nothing is
/// here.
class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.emphasised = false,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Sits inside an existing card rather than filling the screen.
  final bool compact;

  /// Renders the action as the primary call to action. Use when the action
  /// is the only sensible next step, as on a first-run empty state.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: Space.lg),
        ],
        Text(title,
            style: compact ? text.titleSmall : text.titleMedium,
            textAlign: TextAlign.center),
        if (message != null) ...[
          const SizedBox(height: Space.sm),
          Text(message!, style: text.bodySmall, textAlign: TextAlign.center),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: Space.xl),
          if (emphasised)
            FilledButton(onPressed: onAction, child: Text(actionLabel!))
          else
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? Space.lg : Space.xxl),
        child: body,
      ),
    );
  }
}
