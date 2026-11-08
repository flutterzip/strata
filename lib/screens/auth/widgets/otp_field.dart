import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/design_tokens.dart';
import '../../../config/motion.dart';

/// A one-time-code entry built from a single hidden field behind styled
/// boxes.
///
/// One real [EditableText] rather than six, because six separate fields
/// break paste, break autofill of an SMS code, and make backspace behave
/// unpredictably at box boundaries. The boxes here are decoration over one
/// continuous value.
class OtpField extends StatefulWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.hasError = false,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final int length;

  /// Fired once the final digit lands, so the caller can submit without the
  /// user hunting for a button.
  final ValueChanged<String>? onCompleted;

  final bool hasError;
  final bool autofocus;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    final v = widget.controller.text;
    if (v.length == widget.length) {
      HapticFeedback.lightImpact();
      widget.onCompleted?.call(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final value = widget.controller.text;

    return Semantics(
      label: 'Verification code, ${widget.length} digits',
      textField: true,
      value: value.isEmpty ? 'empty' : '${value.length} of ${widget.length}',
      child: ExcludeSemantics(
        child: Stack(
          children: [
            // The real field, invisible but fully functional: paste, SMS
            // autofill and the system keyboard all keep working.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  maxLength: widget.length,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  showCursor: false,
                  style: const TextStyle(height: 1),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _focus.requestFocus(),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  for (var i = 0; i < widget.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: i == widget.length - 1 ? 0 : Space.sm),
                        child: _Box(
                          digit: i < value.length ? value[i] : null,
                          active: _focus.hasFocus && i == value.length,
                          hasError: widget.hasError,
                          style: text.headlineSmall,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.digit,
    required this.active,
    required this.hasError,
    required this.style,
  });

  final String? digit;
  final bool active;
  final bool hasError;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = digit != null;

    final border = hasError
        ? scheme.error
        : active
            ? scheme.primary
            : filled
                ? scheme.outline
                : scheme.outlineVariant;

    return AnimatedContainer(
      duration: context.motion(Motion.quick),
      curve: Motion.standard,
      height: 60,
      decoration: BoxDecoration(
        color: filled ? scheme.surfaceContainer : scheme.surfaceContainerHigh,
        borderRadius: Radii.brLg,
        border: Border.all(color: border, width: active || hasError ? 1.8 : 1),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: context.motion(Motion.quick),
        transitionBuilder: (child, a) => ScaleTransition(
          scale: Tween(begin: 0.6, end: 1.0).animate(a),
          child: FadeTransition(opacity: a, child: child),
        ),
        child: filled
            ? Text(digit!, key: ValueKey(digit), style: style)
            : SizedBox(
                key: const ValueKey('empty'),
                width: 8,
                height: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: Radii.brPill,
                  ),
                ),
              ),
      ),
    );
  }
}
