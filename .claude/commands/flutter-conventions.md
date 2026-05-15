You are setting up or extending a Flutter project. Apply the exact conventions from the `didit` reference repo. Do not invent alternatives — follow the patterns below precisely.

---

## Project Structure

```
lib/
  db/
    database.dart       ← AppDatabase class + dbProvider
    database.g.dart     ← generated, never edit
    tables.dart         ← all Drift table definitions
  features/
    <feature>/
      <feature>_screen.dart
      <feature>_providers.dart
      <widget_name>.dart  ← reusable widgets scoped to this feature
    shared/             ← pure functions and logic used across features
  main.dart
  router.dart
  theme.dart
```

- One folder per feature under `features/`
- Each feature owns its screens, providers, and feature-scoped widgets
- Business logic that is reusable across features lives in `features/shared/` as pure Dart functions (no Flutter imports)
- Screen files: `*_screen.dart`
- Provider files: `*_providers.dart`
- Reusable widgets: descriptive name like `session_card.dart`, `delete_button.dart`
- Private widget classes within a file are prefixed with `_`

---

## pubspec.yaml — Canonical Dependencies

Use these exact packages. Resolve to latest compatible versions unless told otherwise.

```yaml
dependencies:
  flutter:
    sdk: flutter
  go_router: ^14.0.0        # or latest
  flutter_riverpod: ^3.1.0
  riverpod_annotation: ^4.0.0
  drift: ^2.20.0
  drift_flutter: ^0.2.4
  sqlite3_flutter_libs: ^0.5.0
  fl_chart: ^0.70.0         # for all charts — line, bar, pie
  flutter_animate: ^4.5.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.4.0
  drift_dev: ^2.20.0
  riverpod_generator: ^4.0.0
  custom_lint: ^0.8.0
  riverpod_lint: ^3.1.0
```

Add platform-specific packages only when needed (e.g. `flutter_blue_plus` for BLE, `health` for HealthKit/Health Connect).

---

## Drift — Database Layer

### Table definitions (`lib/db/tables.dart`)

```dart
import 'package:drift/drift.dart';

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get detectedPattern => text().nullable()(); // 'cardio' | 'intervals' | null
  TextColumn get hrSource => text()(); // 'ble' | 'healthkit' | 'health_connect'
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
}
```

Rules:
- `autoIncrement()` on every primary key
- Nullable columns use `.nullable()`
- Defaults use `.withDefault(const Constant(value))`
- Store dates as `dateTime()`, store plain date strings as `text()` in `YYYY-MM-DD` format
- Enum-like columns stored as `text()` with comment listing valid values
- Foreign keys use `.references(OtherTable, #id)`

### Database class (`lib/db/database.dart`)

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Sessions, HeartRateSamples])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor); // for tests

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.addColumn(sessions, sessions.someNewColumn);
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'app_db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
```

### Query patterns

```dart
// Reactive stream — use with StreamProvider
(db.select(db.sessions)
  ..where((s) => s.endedAt.isNotNull())
  ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
  .watch()

// One-time fetch
await db.select(db.sessions).get()

// Filtered update
await (db.update(db.sessions)
  ..where((s) => s.id.equals(id)))
  .write(SessionsCompanion(
    title: Value(title),
    modifiedAt: Value(DateTime.now()),
  ));

// Transaction
await db.transaction(() async { ... });
```

---

## Riverpod — State Management

**Do not use `@riverpod` code generation.** Write all providers manually.

### Provider types by use case

```dart
// Database-backed reactive stream
final sessionsProvider = StreamProvider<List<Session>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.sessions)
    ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
    .watch();
});

// Parameterised stream
final samplesForSessionProvider =
    StreamProvider.family<List<HeartRateSample>, int>((ref, sessionId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.heartRateSamples)
    ..where((s) => s.sessionId.equals(sessionId))
    ..orderBy([(s) => OrderingTerm.asc(s.recordedAt)]))
    .watch();
});

// Mutable state with methods
class ActiveSessionNotifier extends Notifier<ActiveSessionState> {
  @override
  ActiveSessionState build() => const ActiveSessionState.idle();

  void start() => state = const ActiveSessionState.recording();
  void stop() => state = const ActiveSessionState.idle();
}

final activeSessionProvider =
    NotifierProvider<ActiveSessionNotifier, ActiveSessionState>(
        ActiveSessionNotifier.new);
```

### Provider file placement

- Feature-specific providers → `features/<feature>/<feature>_providers.dart`
- `dbProvider` → `db/database.dart`
- Cross-feature providers → `features/shared/providers.dart`

### Consuming in widgets

```dart
class SessionListScreen extends ConsumerWidget {
  const SessionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (sessions) => _SessionList(sessions),
    );
  }
}
```

Always handle all three states of `.when()`. Never use `.value` directly without null-checking.

---

## go_router — Navigation

```dart
// lib/router.dart
final router = GoRouter(
  debugLogDiagnostics: true,
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(
      path: '/session/:id',
      builder: (_, state) => SessionDetailScreen(
        sessionId: int.parse(state.pathParameters['id']!),
      ),
    ),
  ],
);
```

Navigation extension (add to `router.dart`):

```dart
extension AppNavigation on BuildContext {
  void navigate(String route) {
    if (kIsWeb) {
      go(route);
    } else {
      push(route);
    }
  }
}
```

- Use path parameters for IDs: `/session/:id`
- Parse parameters immediately in the builder, never pass the raw `GoRouterState` into widgets
- Use `context.navigate()` for standard push-style nav, `context.go()` only for replacing the stack

---

## Theme

```dart
// lib/theme.dart
const Color kSeedColor = Color(0xFF______); // project-specific

ThemeData buildAppTheme() {
  final cs = ColorScheme.fromSeed(seedColor: kSeedColor);
  return ThemeData(
    colorScheme: cs,
    fontFamily: 'Inter',
    useMaterial3: true,
    splashFactory: NoSplash.splashFactory,
    highlightColor: kSeedColor.withValues(alpha: 0.1),
    scaffoldBackgroundColor: cs.surfaceContainerHigh,
  );
}
```

- Always `useMaterial3: true`
- Derive all colours from `ColorScheme.fromSeed` — no hardcoded colours in widgets
- Use `cs.primary`, `cs.surface`, `cs.surfaceContainerHigh`, etc. in widget code
- Never call `Theme.of(context).colorScheme` more than once per build — cache it: `final cs = Theme.of(context).colorScheme;`

---

## main.dart — Bootstrap

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // web only — clean URLs
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerStatefulWidget {
  const App({super.key});
  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // refresh any time-sensitive state here
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'App Name',
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
```

- `ProviderScope` always wraps the entire app
- Root widget is `ConsumerStatefulWidget` so it can observe lifecycle events
- `WidgetsBindingObserver` mixin for `didChangeAppLifecycleState`

---

## Widget Conventions

- Screens extend `ConsumerWidget` (or `ConsumerStatefulWidget` if local state is needed)
- Extract private sub-widgets as `class _WidgetName extends StatelessWidget` in the same file
- Do not split a screen into many small files unless a widget is reused across features
- Form screens use `GlobalKey<FormState>`, `TextEditingController` per field, disposed in `dispose()`
- Animations use `AnimationController` with `SingleTickerProviderStateMixin`

---

## Charts (fl_chart)

Use `fl_chart` for all data visualisation. Preferred chart types:

```dart
// Heart rate over time → LineChart
LineChart(
  LineChartData(
    lineBarsData: [
      LineChartBarData(
        spots: samples.map((s) => FlSpot(
          s.recordedAt.millisecondsSinceEpoch.toDouble(),
          s.bpm.toDouble(),
        )).toList(),
        isCurved: true,
        color: cs.primary,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: cs.primary.withValues(alpha: 0.15),
        ),
      ),
    ],
  ),
)

// HR zone distribution → BarChart or PieChart
// Round comparison → BarChart
```

- Derive chart colours from `ColorScheme`, never hardcode
- Always wrap charts in a `SizedBox` with explicit height
- Keep chart data computation outside the `build` method

---

## Code Generation

Run after any change to Drift tables or (if ever added) `@riverpod` annotations:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Never edit `*.g.dart` files directly. Commit them alongside the source file that generates them.

---

## Business Logic

- Pure functions (no Flutter, no Riverpod) live in `features/shared/`
- Database mutation helpers are async free functions that accept `AppDatabase` as a parameter
- Avoid putting logic in `build()` — compute derived values in providers or pure functions

---

## Platform Permissions Checklist

When adding BLE (`flutter_blue_plus`):
- Android: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` in `AndroidManifest.xml`; location permission for Android < 12
- iOS: `NSBluetoothAlwaysUsageDescription` in `Info.plist`

When adding Health (`health` package):
- iOS: `NSHealthReadUsageDescription` + HealthKit entitlement in `Runner.entitlements`
- Android: Health Connect permissions in `AndroidManifest.xml`
- App Store: HealthKit entitlement requires Apple approval — apply early
