import 'config/app_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_theme.dart';
import 'shared/widgets/demo_panel.dart';
import 'providers/profile_providers.dart';
import 'models/payment_card.dart';
import 'screens/add_card/add_card_screen.dart';
import 'screens/add_card/card_added_screen.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/profile/widgets/notifications_sheet.dart';
import 'screens/convert/convert_screen.dart';
import 'screens/send/send_screen.dart';
import 'screens/splash/splash_gate.dart';
import 'screens/transactions/transactions_screen.dart';
import 'shared/widgets/strata_sheet.dart';

class StrataApp extends ConsumerWidget {
  const StrataApp({super.key});

  static String get name => AppBrand.name;

  /// Lets globally-mounted overlays reach the Navigator.
  ///
  /// Anything placed in [MaterialApp.builder] sits *above* the Navigator —
  /// the builder's `child` is the Navigator — so `Navigator.of(context)`
  /// from there finds no ancestor and routes cannot be pushed. This key is
  /// how the floating demo control opens its sheet.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: name,
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Follows the stored preference from the profile.
      themeMode: ref.watch(themeModeProvider),
      // The splash sits over the auth gate until the first screen is ready.
      home: const _Launch(child: SplashGate(child: AuthGate())),
      onGenerateRoute: (settings) => switch (settings.name) {
        '/add-card' => MaterialPageRoute<void>(
            builder: (_) => const AddCardScreen(),
            settings: settings,
          ),
        '/card-added' => MaterialPageRoute<void>(
            builder: (_) =>
                CardAddedScreen(card: settings.arguments! as PaymentCard),
            settings: settings,
          ),
        TransactionsScreen.route => MaterialPageRoute<void>(
            builder: (_) => const TransactionsScreen(),
            settings: settings,
          ),
        SendScreen.route => MaterialPageRoute<void>(
            builder: (_) => const SendScreen(),
            settings: settings,
          ),
        ConvertScreen.route => MaterialPageRoute<void>(
            builder: (_) => const ConvertScreen(),
            settings: settings,
          ),
        _ => null,
      },
      builder: (context, child) {
        // Clamp text scaling so extreme settings cannot break card layouts,
        // while still honouring most of the user's preference.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.35,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          // Mounted above every route, so the demo controls are reachable
          // from the intro and the PIN pad too, not only the main shell.
          // Tapping anywhere outside a field dismisses the keyboard.
          // Translucent so it never swallows a tap meant for a control:
          // the innermost recogniser still wins the arena.
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Stack(
              children: [
                child!,
                const DemoPanelButton(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Screenshot/automation hook. With no `startRoute` define this is a plain
/// pass-through, so release builds behave exactly as if it were absent.
class _Launch extends StatefulWidget {
  const _Launch({required this.child});

  final Widget child;

  static const String _route = String.fromEnvironment('startRoute');

  /// Opens a sheet at launch, for screenshots: `notifications` or `demo`.
  static const String _sheet = String.fromEnvironment('startSheet');

  @override
  State<_Launch> createState() => _LaunchState();
}

class _LaunchState extends State<_Launch> {
  @override
  void initState() {
    super.initState();
    final hooks = <VoidCallback>[
      if (_Launch._route.isNotEmpty)
        () => Navigator.of(context).pushNamed(_Launch._route),
      if (_Launch._sheet == 'demo') () => showDemoPanelSheet(context),
      if (_Launch._sheet == 'notifications')
        () => showStrataSheet<void>(context,
            builder: (_) => const NotificationsSheet()),
    ];
    if (hooks.isEmpty) return;
    // Run once the splash has gone: a route or sheet opened on the first
    // frame would land on top of the splash, or be lost under it.
    void run() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final hook in hooks) {
          hook();
        }
      });
    }

    if (!SplashGate.showing.value) return run();
    void onChange() {
      if (SplashGate.showing.value) return;
      SplashGate.showing.removeListener(onChange);
      run();
    }

    SplashGate.showing.addListener(onChange);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
