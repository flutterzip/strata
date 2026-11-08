import '../../../config/app_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/design_tokens.dart';
import '../../../providers/profile_providers.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/strata_sheet.dart';

/// Light / dark / follow the system.
class AppearanceSheet extends ConsumerWidget {
  const AppearanceSheet({super.key, required this.current});

  final ThemeMode current;

  static const _options = [
    (
      mode: ThemeMode.system,
      label: 'Match device',
      icon: Icons.contrast_rounded
    ),
    (mode: ThemeMode.light, label: 'Light', icon: Icons.light_mode_outlined),
    (mode: ThemeMode.dark, label: 'Dark', icon: Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StrataSheet(
      icon: Icons.palette_outlined,
      title: 'Appearance',
      message: '${AppBrand.name} is designed for both. Pick whichever you '
          'read best.',
      body: Column(
        children: [
          for (final o in _options)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: _Option(
                label: o.label,
                icon: o.icon,
                selected: o.mode == current,
                onTap: () {
                  ref.read(profileProvider.notifier).setThemeMode(o.mode);
                  Navigator.of(context).pop();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.98,
        enforceMinTarget: false,
        semanticLabel: label,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Space.lg, vertical: Space.lg),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHigh,
            borderRadius: Radii.brLg,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        )),
              ),
              if (selected)
                Icon(Icons.check_rounded,
                    size: 20, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
