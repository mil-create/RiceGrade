import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Home Page'));
  }
}

class AppShell extends StatelessWidget {
  const AppShell({Key? key, required this.navigationShell}) : super(key: key);

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = navigationShell.currentIndex;
    // Determine if we are on a tablet (width >= 600) or phone
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      body: Row(
        children: [
          if (isTablet)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) {
                navigationShell.goBranch(value);
              },
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.camera_alt),
                  label: Text('Capture'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.analytics),
                  label: Text('Results'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history),
                  label: Text('History'),
                ),
              ],
            ),
          Expanded(
            child: navigationShell,
          ),
        ],
      ),
      bottomNavigationBar: !isTablet
          ? BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: (value) {
                navigationShell.goBranch(value);
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.camera_alt),
                  label: 'Capture',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.analytics),
                  label: 'Results',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
              ],
            )
          : null,
    );
  }
}
