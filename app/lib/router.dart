import 'package:go_router/go_router.dart';
import 'features/home/home_screen.dart';
import 'features/tracker_type/tracker_type_screen.dart';
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
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
