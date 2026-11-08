import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import 'pressable.dart';
import 'strata_sheet.dart';

/// One choice in a [showSelectSheet] list.
class SelectOption<T> {
  const SelectOption({
    required this.value,
    required this.label,
    this.detail,
    this.icon,
    this.semanticLabel,
    this.startsGroup = false,
  });

  final T value;
  final String label;

  /// Second line — a balance, a mask, a date range. Never load-bearing on
  /// its own; the label still has to identify the option.
  final String? detail;

  final IconData? icon;

  /// Spoken form, when [label] alone is not enough out of context.
  final String? semanticLabel;

  /// Draws a hairline above this row. Used to fence the "all / any" clearing
  /// option off from its real peers.
  final bool startsGroup;
}

/// What [showSelectSheet] came back with.
///
/// Three outcomes, and they are genuinely different: `null` means the sheet
/// was dismissed and nothing should change, [SelectValue] carries a choice,
/// and [SelectCustom] means the reader asked for the escape hatch instead —
/// a free-text category, a date range, an amount the presets do not cover.
/// Collapsing dismissal into "chose nothing" is how a picker ends up
/// clearing a filter because someone swiped it away.
sealed class SelectResult<T> {
  const SelectResult();
}

class SelectValue<T> extends SelectResult<T> {
  const SelectValue(this.value);
  final T value;
}

class SelectCustom<T> extends SelectResult<T> {
  const SelectCustom();
}

/// One value, one line: label, the value as it stands, and a chevron.
///
/// This replaces a [Wrap] of pills for every list that is longer than three
/// options or that grows with the data. A wrap of variable-width pills has no
/// stable shape — three cards look like a tidy row and seven look like a
/// ragged three-line block — and a horizontally scrolling strip is worse
/// still, because the options past the right edge are simply invisible.
///
/// A row is full width at rest and its picker is full width open, so the
/// control looks identical at three options and at thirty. It also shows the
/// current value without being opened, which is what lets a sheet full of
/// them read as a summary of what is in force.
class SelectRow extends StatelessWidget {
  const SelectRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.detail,
    this.icon,
    this.placeholder = false,
    this.semanticLabel,
  });

  final String label;

  /// The value as it stands. Never empty — pass the "any" wording rather
  /// than a blank, so the row always says what is in force.
  final String value;

  /// Secondary line under the label.
  final String? detail;

  /// Sits beside the value. For a state worth naming before it bites —
  /// a frozen card, say.
  final IconData? icon;

  /// Styles [value] as unset rather than chosen.
  final bool placeholder;

  final String? semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Pressable(
      onTap: onTap,
      pressedScale: 0.985,
      enforceMinTarget: false,
      semanticLabel: semanticLabel ?? '$label, $value',
      semanticHint: 'Opens a list of options',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Hit.min),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.md),
          child: Row(
            children: [
              // Both sides are Expanded with an ellipsis rather than one of
              // them sitting next to a Spacer: at the top of the text-scale
              // range on a narrow phone the pair is wider than the row, and
              // a bare Row has nowhere to put the overflow.
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        detail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                flex: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 15, color: scheme.onSurfaceVariant),
                      const SizedBox(width: Space.xs),
                    ],
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyLarge?.copyWith(
                          color: placeholder
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                          fontWeight:
                              placeholder ? FontWeight.w500 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.unfold_more_rounded,
                  size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Present the options for a [SelectRow].
///
/// The order it is given is the order it shows. Moving the chosen option to
/// the front would mean the list rearranges itself as a consequence of the
/// reader's own tap, which destroys the spatial memory that makes a picker
/// fast on the second visit. Selection is shown by a check and a tinted
/// surface instead, and the list opens scrolled to it.
Future<SelectResult<T>?> showSelectSheet<T>(
  BuildContext context, {
  required String title,
  required List<SelectOption<T>> options,
  required T? selected,
  String? message,
  IconData icon = Icons.checklist_rounded,

  /// An escape hatch below the list — "New category…", "Custom amount…".
  /// Pops [SelectCustom].
  String? customLabel,
  IconData customIcon = Icons.edit_outlined,
}) {
  return showStrataSheet<SelectResult<T>>(
    context,
    builder: (_) => _SelectSheet<T>(
      title: title,
      message: message,
      icon: icon,
      options: options,
      selected: selected,
      customLabel: customLabel,
      customIcon: customIcon,
    ),
  );
}

class _SelectSheet<T> extends StatefulWidget {
  const _SelectSheet({
    required this.title,
    required this.message,
    required this.icon,
    required this.options,
    required this.selected,
    required this.customLabel,
    required this.customIcon,
  });

  final String title;
  final String? message;
  final IconData icon;
  final List<SelectOption<T>> options;
  final T? selected;
  final String? customLabel;
  final IconData customIcon;

  @override
  State<_SelectSheet<T>> createState() => _SelectSheetState<T>();
}

class _SelectSheetState<T> extends State<_SelectSheet<T>> {
  final _scroll = ScrollController();

  /// Uniform, so the scroll-to-selection arithmetic is exact rather than a
  /// guess that drifts further down a long list.
  double get _extent => widget.options.any((o) => o.detail != null) ? 64 : 54;

  @override
  void initState() {
    super.initState();
    // After the first layout, because the viewport height is not known
    // before it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelection());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _revealSelection() {
    if (!mounted || !_scroll.hasClients) return;
    final i = widget.options.indexWhere((o) => o.value == widget.selected);
    if (i < 0) return;

    final position = _scroll.position;
    final rowTop = i * _extent;
    final rowBottom = rowTop + _extent;
    final viewport = position.viewportDimension;
    // Already in view: leave it alone. Scrolling a visible selection under
    // the reader is motion for nothing.
    if (rowTop >= position.pixels && rowBottom <= position.pixels + viewport) {
      return;
    }
    // A third of a viewport above the row, so it lands in reading position
    // rather than flush against the top edge.
    final target = rowTop - viewport / 3;
    position.jumpTo(target.clamp(0.0, position.maxScrollExtent));
  }

  void _pick(SelectResult<T> result) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return StrataSheet(
      icon: widget.icon,
      title: widget.title,
      message: widget.message,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            // The list scrolls inside the sheet. StrataSheet's own
            // `scrollable` would work, but it owns the ScrollView and this
            // needs the controller to open on the selection.
            constraints: BoxConstraints(maxHeight: media.size.height * 0.46),
            child: ListView.builder(
              controller: _scroll,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemExtent: _extent,
              itemCount: widget.options.length,
              itemBuilder: (context, i) {
                final option = widget.options[i];
                return _OptionTile<T>(
                  option: option,
                  selected: option.value == widget.selected,
                  onTap: () => _pick(SelectValue<T>(option.value)),
                );
              },
            ),
          ),
          if (widget.customLabel != null) ...[
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: () => _pick(SelectCustom<T>()),
              icon: Icon(widget.customIcon, size: 18),
              label: Text(widget.customLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile<T> extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SelectOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: option.semanticLabel ?? option.label,
      child: ExcludeSemantics(
        child: Pressable(
          onTap: onTap,
          pressedScale: 0.985,
          enforceMinTarget: false,
          child: Padding(
            padding: EdgeInsets.only(top: option.startsGroup ? Space.xs : 0),
            child: Container(
              decoration: BoxDecoration(
                border: option.startsGroup
                    ? Border(top: BorderSide(color: scheme.outlineVariant))
                    : null,
              ),
              child: AnimatedContainer(
                duration: context.motion(Motion.quick),
                curve: Motion.standard,
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.symmetric(
                    horizontal: Space.md, vertical: Space.sm),
                decoration: BoxDecoration(
                  borderRadius: Radii.brMd,
                  color:
                      selected ? scheme.primaryContainer : Colors.transparent,
                ),
                child: Row(
                  children: [
                    if (option.icon != null) ...[
                      Icon(option.icon,
                          size: 17,
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant),
                      const SizedBox(width: Space.md),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            option.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyLarge?.copyWith(
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          if (option.detail != null)
                            Text(
                              option.detail!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: selected
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Selection is a check and a surface, not a hue: there is
                    // one accent in this app and the chart owns it.
                    if (selected) ...[
                      const SizedBox(width: Space.sm),
                      Icon(Icons.check_rounded,
                          size: 19, color: scheme.onPrimaryContainer),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
