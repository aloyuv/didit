// The navigation bar shared by the top-level screens.
// Design doc: docs/design/screens.md

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router.dart';

/// Top-level destinations, in the order they appear in the bar.
enum AppTab { settings, home, archive, add }

class AppBottomNav extends StatelessWidget {
  final AppTab current;

  const AppBottomNav({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      // Past three items the bar switches to its shifting style, which hides
      // the labels of everything but the selected tab.
      type: BottomNavigationBarType.fixed,
      currentIndex: current.index,
      onTap: (i) => _go(context, AppTab.values[i]),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.archive_outlined), label: 'Archive'),
        BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add'),
      ],
    );
  }

  void _go(BuildContext context, AppTab tab) {
    if (tab == current) return;
    switch (tab) {
      // The top-level screens replace each other rather than stacking up.
      case AppTab.settings:
        context.go('/settings');
      case AppTab.home:
        context.go('/');
      case AppTab.archive:
        context.go('/archive');
      // Adding a tracker is a detour, so it pushes and keeps a back button.
      case AppTab.add:
        context.navigate('/tracker-type');
    }
  }
}
