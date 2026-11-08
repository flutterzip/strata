import 'package:flutter/material.dart';

import '../../../config/design_tokens.dart';
import '../../../config/motion.dart';
import '../../../shared/widgets/stage_transition.dart';
import '../../../shared/widgets/strata_mark.dart';
import 'auth_backdrop.dart';

/// Shared shell for every auth screen.
///
/// Holds the ambient backdrop, the staged entrance and the title block, so
/// the six screens in this flow differ only by their fields. One ticker per
/// screen drives all four stages.
class AuthScaffold extends StatefulWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.fields,
    this.eyebrow,
    this.subtitle,
    this.footer,
    this.showBack = true,
    this.onBack,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;

  /// The form body.
  final List<Widget> fields;

  /// Pinned beneath the body, outside the scroll area.
  final Widget? footer;

  final bool showBack;
  final VoidCallback? onBack;

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: Motion.entrance,
  )..forward();

  late final _markIn = Motion.stage(_entrance, begin: 0.00, end: 0.38);
  late final _titleIn = Motion.stage(_entrance, begin: 0.12, end: 0.56);
  late final _bodyIn = Motion.stage(_entrance, begin: 0.26, end: 0.78);
  late final _footIn = Motion.stage(_entrance, begin: 0.42, end: 1.00);

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: AuthBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              StageTransition(
                animation: _markIn,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Space.lg, Space.sm, Space.xl, 0),
                  child: Row(
                    children: [
                      if (widget.showBack)
                        IconButton(
                          onPressed: widget.onBack ??
                              () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Back',
                        )
                      else
                        const SizedBox(width: Space.sm),
                      const Spacer(),
                      StrataMark(size: 26, color: scheme.onSurface),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                      Space.xxl, Space.xl, Space.xxl, Space.xl),
                  children: [
                    StageTransition(
                      animation: _titleIn,
                      rise: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.eyebrow != null) ...[
                            Text(
                              widget.eyebrow!.toUpperCase(),
                              style: text.labelSmall?.copyWith(
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: Space.sm),
                          ],
                          Text(widget.title, style: text.headlineMedium),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: Space.sm),
                            Text(widget.subtitle!, style: text.bodyMedium),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.xxxl),
                    StageTransition(
                      animation: _bodyIn,
                      child: Column(children: widget.fields),
                    ),
                  ],
                ),
              ),
              if (widget.footer != null)
                StageTransition(
                  animation: _footIn,
                  rise: 14,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Space.xxl, 0, Space.xxl, Space.lg),
                    child: widget.footer!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
