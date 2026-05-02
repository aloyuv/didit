// Design docs:
// - docs/design/screens.md
// - docs/design/tech-stack.md

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'features/home/home_screen.dart';
import 'features/tracker_type/tracker_type_screen.dart';
import 'features/tracker_type/habit_edit_screen.dart';
import 'features/tracker_type/goal_edit_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/tracker_details/tracker_details_screen.dart';
import 'features/tracker_details/mass_edit_screen.dart';

// go_router's push() doesn't update the browser URL on web; go() does but clears the
// Flutter nav stack, removing AppBar back buttons on mobile. This picks the right one.
extension AppNavigation on BuildContext {
  void navigate(String route) {
    if (kIsWeb) {
      go(route);
    } else {
      push(route);
    }
  }
}

final router = GoRouter(
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/tracker-type',
      builder: (context, state) => const TrackerTypeScreen(),
    ),
    GoRoute(
      path: '/habit-edit',
      builder: (context, state) => const HabitEditScreen(),
    ),
    GoRoute(
      path: '/habit-edit/:id',
      builder: (context, state) =>
          HabitEditScreen(trackerId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/goal-edit',
      builder: (context, state) => const GoalEditScreen(),
    ),
    GoRoute(
      path: '/goal-edit/:id',
      builder: (context, state) =>
          GoalEditScreen(trackerId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/tracker/:id',
      builder: (context, state) => TrackerDetailsScreen(
          trackerId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/mass-edit/:id',
      builder: (context, state) =>
          MassEditScreen(trackerId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
