import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'features/home/home_providers.dart';
import 'router.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(const ProviderScope(child: DiditApp()));
}

class DiditApp extends ConsumerStatefulWidget {
  const DiditApp({super.key});

  @override
  ConsumerState<DiditApp> createState() => _DiditAppState();
}

class _DiditAppState extends ConsumerState<DiditApp>
    with WidgetsBindingObserver {
  late final Timer _dateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.read(currentDateProvider.notifier).refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(currentDateProvider.notifier).refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Didit',
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
