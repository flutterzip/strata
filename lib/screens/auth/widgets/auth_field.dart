import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/design_tokens.dart';
import '../../../config/motion.dart';

/// A form field with its title set *above* the box, not floating inside it.
///
/// The stock floating label sat at 12.5pt in secondary grey inside the
/// outline, then shrank further on focus — on a form whose whole job is
/// these four fields it read as an afterthought. Here the title is a real
/// label in the ink colour at label weight, the box carries a hint showing
/// what goes in it, and a leading icon says what kind of field it is at a
/// glance. On focus the title and icon take the accent, so you can see
/// where you are typing without hunting for the caret.
///
/// [trailing] sits at the right of the title row — "Forgot?" beside
/// Password, for instance — so a related action lives next to its field.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.hint,
    this.icon,
    this.trailing,
    this.suffix,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final String? hint;
  final IconData? icon;
  final Widget? trailing;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(AuthField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _own)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _own?.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final focused = _focus.hasFocus;

    Color iconColor(Set<WidgetState> s) => s.contains(WidgetState.error)
        ? scheme.error
        : s.contains(WidgetState.focused)
            ? scheme.primary
            : scheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title row. Read before the field, so a screen reader hears
        // "Email", then the field and its hint.
        //
        // The trailing control floats over the row rather than sitting in
        // it: a TextButton is 48dp tall for its touch target, and in a Row
        // that height became the title row's, opening a gap above every
        // field that had one. Floated, it centres on the label's line and
        // the row stays the label's own height.
        Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.only(
                left: Space.xxs,
                bottom: Space.sm,
                right: widget.trailing == null ? 0 : 150,
              ),
              child: AnimatedDefaultTextStyle(
                duration: context.motion(Motion.quick),
                curve: Motion.standard,
                style: text.labelMedium!.copyWith(
                  fontSize: 13.5,
                  height: 1.2,
                  letterSpacing: 0.1,
                  color: focused ? scheme.primary : scheme.onSurface,
                ),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (widget.trailing != null)
              Positioned(
                // The label line is ~16dp; centre a 48dp target on it, and
                // pull the button's own side padding back to the edge.
                top: -16,
                right: -Space.sm,
                height: Hit.min,
                child: Center(child: widget.trailing!),
              ),
          ],
        ),
        TextFormField(
          controller: widget.controller,
          focusNode: _focus,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          autofillHints: widget.autofillHints,
          validator: widget.validator,
          onFieldSubmitted: widget.onSubmitted,
          obscureText: widget.obscureText,
          autocorrect: widget.autocorrect,
          enableSuggestions: widget.enableSuggestions,
          inputFormatters: widget.inputFormatters,
          style: text.bodyLarge,
          cursorColor: scheme.primary,
          decoration: InputDecoration(
            hintText: widget.hint,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 17),
            prefixIcon: widget.icon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(widget.icon, size: 20),
                  ),
            prefixIconColor: WidgetStateColor.resolveWith(iconColor),
            suffixIconColor: WidgetStateColor.resolveWith(iconColor),
            suffixIcon: widget.suffix,
          ),
        ),
      ],
    );
  }
}
