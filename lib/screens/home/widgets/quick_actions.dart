import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';
import '../../../shared/widgets/pressable.dart';

typedef QuickAction = ({IconData icon, String label, VoidCallback? onTap});

class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final a in actions)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xs),
              child: _ActionTile(action: a),
            ),
          ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: action.onTap,
      pressedScale: 0.94,
      semanticLabel: action.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: Radii.brLg,
              color: scheme.surfaceContainerHigh,
            ),
            child: Icon(action.icon, color: scheme.onSurface, size: 22),
          ),
          const SizedBox(height: Space.sm),
          Text(action.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
