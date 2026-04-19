import 'package:go_router/go_router.dart';
import 'features/home/home_screen.dart';
import 'features/tracker_type/tracker_type_screen.dart';
import 'features/tracker_type/habit_edit_screen.dart';
import 'features/tracker_type/goal_edit_screen.dart';
import 'features/settings/settings_screen.dart';

final router = GoRouter(
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
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
