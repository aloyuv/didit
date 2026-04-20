import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'router.dart';
import 'theme.dart';

void main() {
  usePathUrlStrategy();
  runApp(const ProviderScope(child: DiditApp()));
}

class DiditApp extends StatelessWidget {
  const DiditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Didit',
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
