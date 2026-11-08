import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/design_tokens.dart';

/// Strata's modal surface — the one place modals are built.
///
/// Deliberately not a stock [AlertDialog]: a centred grey box with two blue
/// text buttons is the most anonymous shape in mobile software. This rises
/// from the bottom edge on the sheet spring, sits on paper with a hairline
/// and a grab handle, blurs what is behind it rather than dimming it to mud,
/// and gives its actions real size so they can be hit with a thumb.
///
/// Everything modal in the app routes through here, so there is exactly one
/// modal look to maintain and no screen invents its own.
class StrataSheet extends StatelessWidget {
  const StrataSheet({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.body,
    this.actions = const [],
    this.scrollable = false,
  });

  final String title;
  final String? message;
  final IconData? icon;

  /// Arbitrary content between the message and the actions.
  final Widget? body;

  final List<Widget> actions;

  /// Let a tall body scroll rather than overflow.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);

    // Split in two so a long body can scroll while the actions stay put.
    // A primary action that scrolls off the bottom of a tall form is a
    // button the thumb cannot find, which is how a sheet ends up feeling
    // broken on a small phone.
    final reading = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (icon != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: Radii.brMd,
              ),
              child: Icon(icon, size: 21, color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: Space.lg),
        ],
        Text(title, style: text.headlineSmall),
        if (message != null) ...[
          const SizedBox(height: Space.sm),
          Text(message!, style: text.bodyMedium),
        ],
        if (body != null) ...[
          const SizedBox(height: Space.xl),
          body!,
        ],
      ],
    );

    final actionBar = actions.isEmpty
        ? null
        : Container(
            padding: const EdgeInsets.only(top: Space.xxl),
            decoration: scrollable
                ? BoxDecoration(
                    // Hairline only when something can pass underneath it.
                    border: Border(
                      top: BorderSide(color: scheme.outlineVariant),
                    ),
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, a) in actions.indexed) ...[
                  if (i > 0) const SizedBox(height: Space.md),
                  a,
                ],
              ],
            ),
          );

    return Padding(
      // Lift clear of the keyboard when the body holds fields.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        // A long list must scroll inside the sheet rather than run off the
        // top of the screen.
        constraints: BoxConstraints(maxHeight: media.size.height * 0.86),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Radii.sheet),
            ),
            border: Border(
              top: BorderSide(color: scheme.outlineVariant),
              left: BorderSide(color: scheme.outlineVariant),
              right: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  Space.xxl, Space.md, Space.xxl, Space.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Grab handle: tells the thumb this is draggable before it
                  // tries.
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: Space.xl),
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: Radii.brPill,
                      ),
                    ),
                  ),
                  if (scrollable)
                    Flexible(child: SingleChildScrollView(child: reading))
                  else
                    reading,
                  if (actionBar != null) actionBar,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Present a [StrataSheet]. Returns whatever the sheet pops with.
Future<T?> showStrataSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    // Blur rather than dim: the app stays legible behind the sheet, which
    // keeps the modal feeling like a layer instead of a page change.
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: builder(context),
    ),
  );
}

/// Ask before doing something irreversible.
///
/// Returns true only on explicit confirmation. The destructive action is
/// named in the button — never "OK" — so the label alone says what happens.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline_rounded,
  bool destructive = false,
}) async {
  final result = await showStrataSheet<bool>(
    context,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return StrataSheet(
        icon: icon,
        title: title,
        message: message,
        actions: [
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.errorContainer,
                    foregroundColor: scheme.onErrorContainer,
                  )
                : null,
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(sheetContext).pop(true);
            },
            child: Text(confirmLabel),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(sheetContext).pop(false),
            child: Text(cancelLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
