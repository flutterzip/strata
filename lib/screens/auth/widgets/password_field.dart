import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';
import '../../../config/motion.dart';
import '../../../config/palette.dart';
import '../../../shared/utils/auth_validation.dart';
import 'auth_field.dart';

/// Password entry with a reveal toggle and an optional strength meter.
///
/// The meter uses the one accent stepped through the chart ramp rather than
/// a red-amber-green traffic light: a second and third hue would break the
/// palette, and colour alone never carries the meaning here — the label
/// spells out the verdict.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.focusNode,
    this.label = 'Password',
    this.hint,
    this.showStrength = false,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.validator,
    this.autofillHints,
    this.trailing,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final bool showStrength;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;

  /// Beside the label — "Forgot?" on sign in.
  final Widget? trailing;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    if (widget.showStrength) {
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    if (widget.showStrength) {
      widget.controller.removeListener(_onChanged);
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final score = AuthValidation.passwordStrength(widget.controller.text);
    final hasInput = widget.controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          label: widget.label,
          hint: widget.hint ??
              (widget.showStrength ? 'At least 8 characters' : 'Your password'),
          icon: Icons.lock_outline_rounded,
          trailing: widget.trailing,
          obscureText: _obscured,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          validator: widget.validator,
          autofillHints: widget.autofillHints,
          suffix: IconButton(
            onPressed: () => setState(() => _obscured = !_obscured),
            tooltip: _obscured ? 'Show password' : 'Hide password',
            icon: Icon(
              _obscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
            ),
          ),
        ),
        if (widget.showStrength) ...[
          const SizedBox(height: Space.md),
          AnimatedOpacity(
            opacity: hasInput ? 1 : 0.45,
            duration: context.motion(Motion.quick),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: AnimatedContainer(
                        duration: context.motion(Motion.base),
                        curve: Motion.standard,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: Radii.brPill,
                          color: i < score
                              // Darkest step first, so a stronger password
                              // reads as "more filled" not "different hue".
                              ? ChartRamp.at(3 - i, isDark)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: Space.sm),
                SizedBox(
                  width: 82,
                  child: Text(
                    hasInput ? AuthValidation.strengthLabel(score) : '',
                    textAlign: TextAlign.right,
                    style: text.labelSmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
