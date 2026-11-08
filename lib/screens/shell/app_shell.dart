import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/design_tokens.dart';
import '../../shared/widgets/strata_nav_bar.dart';
import '../cards/cards_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';

/// Root navigation. Adapts between the floating bar and a rail by window
/// class, keeping every tab alive so scroll position survives switching.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Screenshot/automation hook. Defaults to 0, so normal builds are
  /// unaffected: `--dart-define=startTab=1` opens straight to Cards.
  int _index = const int.fromEnvironment('startTab');

  static const List<NavItem> _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    (
      icon: Icons.credit_card_outlined,
      activeIcon: Icons.credit_card_rounded,
      label: 'Cards'
    ),
    (
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile'
    ),
  ];

  void _openAddCard() => Navigator.of(context).pushNamed('/add-card');

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onAddCard: _openAddCard, onSeeCards: () => _go(1)),
      CardsScreen(onAddCard: _openAddCard),
      const ProfileScreen(),
    ];

    final windowClass = Breakpoints.of(MediaQuery.sizeOf(context).width);
    final body = IndexedStack(index: _index, children: pages);

    if (windowClass != WindowClass.compact) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _items)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.activeIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      // The bar floats over content rather than reserving a shelf, so the
      // page behind it keeps its full height.
      extendBody: true,
      body: body,
      bottomNavigationBar: StrataNavBar(
        items: _items,
        index: _index,
        onChanged: _go,
      ),
    );
  }
}
