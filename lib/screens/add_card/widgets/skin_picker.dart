import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/design_tokens.dart';
import '../../../config/motion.dart';
import '../../../config/palette.dart';

/// Colour picker for the card face.
class SkinPickerRow extends StatelessWidget {
  const SkinPickerRow({
    super.key,
    required this.selected,
    required this.onChanged,
    this.skins = CardSkin.values,
  });

  final CardSkin selected;
  final ValueChanged<CardSkin> onChanged;
  final List<CardSkin> skins;

  @override
  Widget build(BuildContext context) {
    // A fixed Row cannot hold a label plus five 48dp targets on a narrow
    // phone, and grows worse with large text. A label above a Wrap survives
    // every width and text scale.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Card colour', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Space.xs),
        Wrap(
          children: [
            for (final skin in skins)
              _Swatch(
                skin: skin,
                isSelected: skin == selected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(skin);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.skin,
    required this.isSelected,
    required this.onTap,
  });

  final CardSkin skin;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: skin.label,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        // Visual swatch is 22dp but the tappable area meets the 48dp minimum.
        child: SizedBox(
          width: Hit.min,
          height: Hit.min,
          child: Center(
            child: AnimatedContainer(
              duration: context.motion(Motion.base),
              curve: Motion.emphasised,
              width: isSelected ? 26 : 22,
              height: isSelected ? 26 : 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: skin.gradient,
                border: Border.all(
                  color: isSelected ? scheme.primary : scheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: AnimatedOpacity(
                opacity: isSelected ? 1 : 0,
                duration: context.motion(Motion.quick),
                child: Icon(Icons.check_rounded, size: 14, color: skin.onFace),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
