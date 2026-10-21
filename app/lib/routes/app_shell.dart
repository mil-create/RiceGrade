import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    (Icons.home, 'Home'),
    (Icons.camera_alt, 'Capture'),
    (Icons.analytics, 'Results'),
    (Icons.history, 'History'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    void onSelect(int i) => navigationShell.goBranch(i);

    return Scaffold(
      body: Row(
        children: [
          if (isTablet)
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: onSelect,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final (icon, label) in _items)
                  NavigationRailDestination(
                      icon: Icon(icon), label: Text(label)),
              ],
            ),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: isTablet
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: index,
              onTap: onSelect,
              items: [
                for (final (icon, label) in _items)
                  BottomNavigationBarItem(icon: Icon(icon), label: label),
              ],
            ),
    );
  }
}
