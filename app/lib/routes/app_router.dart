import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_shell.dart';
import '../features/capture/capture_screen.dart';
import '../features/results/results_screen.dart';
import '../features/history/compare_screen.dart';
import '../features/history/history_screen.dart';

// Placeholder home page - replace with actual implementation later
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Home Page'));
  }
}

final GoRouter appRouter = GoRouter(
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/capture',
              builder: (context, state) => const CaptureScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/results',
              builder: (context, state) => const ResultsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
      ],
    ),
    // Full screen, outside the shell, so it gets a back button.
    GoRoute(
      path: '/compare',
      builder: (context, state) => CompareScreen(
        firstId: int.tryParse(state.uri.queryParameters['a'] ?? ''),
        secondId: int.tryParse(state.uri.queryParameters['b'] ?? ''),
      ),
    ),
  ],
);
