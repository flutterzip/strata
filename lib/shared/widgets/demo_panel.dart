import 'package:flutter/material.dart';

import '../../screens/splash/splash_gate.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../providers/auth_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/recipient_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/wallet_providers.dart';
import 'pressable.dart';
import 'settings_row.dart';
import 'strata_sheet.dart';

/// A floating control for everything you need while demonstrating the app.
///
/// Mounted globally, so it is reachable from the intro and the PIN pad as
/// well as the main shell — the places where there is otherwise no way to
/// reach settings at all. Deliberately small and quiet until touched.
/// A floating control for everything you need while demonstrating the app.
///
/// Draggable, because a fixed overlay will eventually sit on top of the one
/// thing someone wants to tap. Drag it anywhere; on release it springs to
/// the nearer side so it never ends up stranded mid-screen, and it stays
/// inside the safe area.
/// True while the demo settings sheet is up.
final ValueNotifier<bool> _sheetOpen = ValueNotifier<bool>(false);

/// The floating button steps aside during the splash and while its own
/// sheet is open — over the sheet it would sit on top of the controls.
final Listenable _hiddenSource =
    Listenable.merge([SplashGate.showing, _sheetOpen]);
final ValueNotifier<bool> _hidden = () {
  final n = ValueNotifier<bool>(SplashGate.showing.value || _sheetOpen.value);
  _hiddenSource.addListener(
      () => n.value = SplashGate.showing.value || _sheetOpen.value);
  return n;
}();

/// Opens the demo settings sheet. The one way in, for the floating button
/// and the `startSheet=demo` launch hook alike.
Future<void> showDemoPanelSheet(BuildContext context) async {
  _sheetOpen.value = true;
  try {
    await showStrataSheet<void>(
      context,
      builder: (_) => const DemoPanelSheet(),
    );
  } finally {
    _sheetOpen.value = false;
  }
}

class DemoPanelButton extends ConsumerStatefulWidget {
  const DemoPanelButton({super.key});

  /// On the button's fade, so tests can read whether it is showing.
  static const Key fadeKey = ValueKey('demo-panel-fade');

  @override
  ConsumerState<DemoPanelButton> createState() => _DemoPanelButtonState();
}

class _DemoPanelButtonState extends ConsumerState<DemoPanelButton> {
  static const double _size = 46;
  static const double _margin = Space.lg;

  /// Null until first laid out, then the top-left in global coordinates.
  Offset? _position;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    // A new button means a new app: no sheet can be open yet. Clears a
    // flag left set by a sheet that was torn down rather than closed (a
    // hot restart, or a test ending with it up), which would otherwise
    // keep this button hidden for good.
    _sheetOpen.value = false;
  }

  /// Right edge, around two-thirds down: clear of the header and clear of
  /// the primary call to action, which almost always sits at the bottom.
  Offset _defaultFor(Size screen, EdgeInsets pad) => Offset(
        screen.width - _size - _margin - pad.right,
        (screen.height - pad.top - pad.bottom) * 0.62 + pad.top,
      );

  Offset _clamp(Offset p, Size screen, EdgeInsets pad) => Offset(
        p.dx.clamp(
            _margin + pad.left, screen.width - _size - _margin - pad.right),
        p.dy.clamp(
            _margin + pad.top, screen.height - _size - _margin - pad.bottom),
      );

  void _snapToEdge(Size screen, EdgeInsets pad) {
    final p = _position;
    if (p == null) return;
    final goLeft = p.dx + _size / 2 < screen.width / 2;
    setState(() {
      _dragging = false;
      _position = _clamp(
        Offset(
          goLeft
              ? _margin + pad.left
              : screen.width - _size - _margin - pad.right,
          p.dy,
        ),
        screen,
        pad,
      );
    });
  }

  void _open() {
    // The Navigator's context, not this one: anything in
    // MaterialApp.builder sits above the Navigator, so Navigator.of here
    // would find no ancestor.
    final navigator = StrataApp.navigatorKey.currentContext;
    if (navigator == null) return;
    HapticFeedback.lightImpact();
    showDemoPanelSheet(navigator);
  }

  @override
  Widget build(BuildContext context) {
    // Screenshot hook: `--dart-define=hideDemoControl=true` keeps the
    // floating button out of store and README shots.
    if (const bool.fromEnvironment('hideDemoControl')) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final screen = media.size;
    final pad = media.padding;
    final pos = _position ??= _defaultFor(screen, pad);

    return AnimatedPositioned(
      duration: _dragging ? Duration.zero : context.motion(Motion.gentle),
      curve: Motion.emphasised,
      left: pos.dx,
      top: pos.dy,
      width: _size,
      height: _size,
      // Kept off the splash: the brand moment is not the place for a
      // floating settings button.
      child: ValueListenableBuilder<bool>(
        valueListenable: _hidden,
        builder: (context, hidden, child) => IgnorePointer(
          ignoring: hidden,
          child: AnimatedOpacity(
            key: DemoPanelButton.fadeKey,
            opacity: hidden ? 0 : 1,
            duration: context.motion(Motion.slow),
            curve: Motion.standard,
            child: child,
          ),
        ),
        child: Semantics(
          button: true,
          label: 'Demo settings',
          hint: 'Theme, demo hints and reset. Drag to move.',
          child: ExcludeSemantics(
            child: GestureDetector(
              onPanStart: (_) => setState(() => _dragging = true),
              onPanUpdate: (d) => setState(() {
                _position = _clamp(pos + d.delta, screen, pad);
              }),
              onPanEnd: (_) => _snapToEdge(screen, pad),
              onPanCancel: () => _snapToEdge(screen, pad),
              // Material + InkWell rather than the app's own Pressable: this
              // sits outside any Scaffold and needs its own Material
              // ancestor for ink and elevation.
              child: Material(
                color: scheme.surfaceContainer.withValues(alpha: 0.94),
                shape: CircleBorder(
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                elevation: _dragging ? 10 : 4,
                shadowColor: Colors.black.withValues(alpha: 0.3),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _open,
                  customBorder: const CircleBorder(),
                  child: Icon(
                    _dragging
                        ? Icons.drag_indicator_rounded
                        : Icons.tune_rounded,
                    size: 19,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DemoPanelSheet extends ConsumerWidget {
  const DemoPanelSheet({super.key});

  static const _modes = [
    (mode: ThemeMode.system, label: 'Auto', icon: Icons.contrast_rounded),
    (mode: ThemeMode.light, label: 'Light', icon: Icons.light_mode_outlined),
    (mode: ThemeMode.dark, label: 'Dark', icon: Icons.dark_mode_outlined),
  ];

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      icon: Icons.restart_alt_rounded,
      title: 'Reset demo data?',
      message: 'Cards, profile and notifications go back to how they '
          'shipped, and the app returns to the welcome screens. This cannot '
          'be undone.',
      confirmLabel: 'Reset everything',
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    await Future.wait([
      ref.read(walletProvider.notifier).resetDemoData(),
      ref.read(profileProvider.notifier).resetDemoData(),
      ref.read(notificationsProvider.notifier).resetDemoData(),
      ref.read(transactionsProvider.notifier).resetDemoData(),
      ref.read(recipientsProvider.notifier).resetDemoData(),
    ]);
    // Last: swapping the auth stage rebuilds the whole tree beneath us.
    await ref.read(authProvider.notifier).restartOnboarding();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mode = ref.watch(themeModeProvider);
    final hints = ref.watch(showDemoHintsProvider);

    return StrataSheet(
      icon: Icons.tune_rounded,
      title: 'Demo settings',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('APPEARANCE',
              style: text.labelSmall
                  ?.copyWith(letterSpacing: 1.0, fontWeight: FontWeight.w700)),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              for (final m in _modes)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: Space.sm),
                    child: _ModeChip(
                      label: m.label,
                      icon: m.icon,
                      selected: m.mode == mode,
                      onTap: () => ref
                          .read(profileProvider.notifier)
                          .setThemeMode(m.mode),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: Radii.brXl,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                SettingsRow(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Demo hints',
                  subtitle: hints
                      ? 'Showing prefilled credentials and codes'
                      : 'Prefilled credentials and codes are hidden',
                  onTap: () => ref
                      .read(profileProvider.notifier)
                      .setShowDemoHints(!hints),
                  trailing: Switch(
                    value: hints,
                    onChanged: (v) =>
                        ref.read(profileProvider.notifier).setShowDemoHints(v),
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                SettingsRow(
                  icon: Icons.restart_alt_rounded,
                  title: 'Reset demo data',
                  subtitle: 'Restore everything and replay the intro',
                  destructive: true,
                  onTap: () => _reset(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
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
        enforceMinTarget: false,
        pressedScale: 0.96,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: context.motion(Motion.quick),
          curve: Motion.standard,
          padding: const EdgeInsets.symmetric(vertical: Space.md),
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
          child: Column(
            children: [
              Icon(icon,
                  size: 18,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      )),
            ],
          ),
        ),
      ),
    );
  }
}
