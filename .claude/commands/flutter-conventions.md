These are the conventions and patterns used in this Flutter codebase. Treat them as strong defaults — follow them unless you have specific context that justifies a different approach, and note when you deviate and why.

---

## Design Docs

Maintain a `docs/design/` folder alongside the code. This is where intent lives. Code shows how something works; design docs explain why it works that way, what the user experience is supposed to be, and what edge cases were considered. Without this, every future agent (or human) has to reverse-engineer decisions from the code.

**Suggested files:**

```
docs/design/
  README.md        ← one paragraph: what this folder is and how to use it
  data-model.md    ← every entity, every field, what nullability means, derived fields
  screens.md       ← every screen, what it shows, tap/interaction behavior, decision tables
  tech-stack.md    ← why each dependency was chosen, what alternatives were rejected
docs/development.md  ← how to run, test, build, and release
```

**README.md** should explain that every source file links back to the design doc it implements, so when the code changes the doc gets updated too. Add a `// Design docs: ../../../docs/design/screens.md` comment near the top of each file that has a design doc counterpart.

**data-model.md** should define every database entity in plain English before writing a single Drift table. Include: what the entity represents, every field and its purpose, what nullable means for each nullable field, and which fields are denormalized (computed and cached). This catches schema mistakes before they reach users. Example shape:

```markdown
## Session

A single recording of heart rate data from start to stop.

- **id** — surrogate primary key
- **startedAt** — when the user tapped "start"
- **endedAt** — null while the session is in progress; set when the user taps "stop"
- **title** — user-editable label; null until the user sets it or auto-generation runs
- **detectedPattern** — 'cardio' | 'intervals' | null; computed post-session, null until analysis runs
- **avgBpm** — denormalized; recomputed from HeartRateSamples after session ends, null during recording
```

**screens.md** should describe interaction behavior as decision tables, not prose. Prose hides edge cases. A table like:

```markdown
| State                | Tap behavior          |
|----------------------|-----------------------|
| Session in progress  | Shows live HR + stop  |
| Session ended        | Shows summary + edit  |
| No sessions yet      | Shows empty state CTA |
```

...is unambiguous. In this project, a complex tap behavior took 450 lines of code changes and a lot of thought to get right — the commit message said "wow, it's a tiny bit of the app and it took a huge amount of design, code, testing, and work to address." A decision table in the design doc written upfront would have resolved the ambiguity before a line of code was written.

**tech-stack.md** should record the reasoning behind each dependency choice. When a future agent (or you in 6 months) wonders "why flutter_blue_plus and not bluetooth_classic?", the answer should be findable in 10 seconds.

---

## Project Structure

```
lib/
  db/
    database.dart       ← AppDatabase class + dbProvider
    database.g.dart     ← generated, never edit manually
    tables.dart         ← all Drift table definitions
  features/
    <feature>/
      <feature>_screen.dart
      <feature>_providers.dart
      <widget>.dart       ← widgets scoped to this feature
    shared/              ← pure functions and logic used across features
  main.dart
  router.dart
  theme.dart
docs/
  design/
  development.md
```

Feature-based structure keeps everything that changes together in one place. When you work on the "session detail" screen, you only need to touch `features/session_detail/` — not hunt across a flat `screens/`, `providers/`, and `models/` folder. The `shared/` folder is for business logic (pure functions) that more than one feature needs; resist putting things there prematurely.

Naming conventions:
- `*_screen.dart` — top-level route targets
- `*_providers.dart` — all Riverpod providers for a feature
- Private widget classes within a file are prefixed with `_` (e.g. `_SessionCard`)
- No `_widget.dart` suffix — if a widget is reusable across features it goes in `shared/`, otherwise it stays in the feature folder with a descriptive name

---

## App Name and Database Filename

Set these as constants on day one and treat them as separate concerns:

```dart
// lib/db/database.dart
const String dbFileName = 'pulse'; // Never change this after first release
```

```xml
<!-- ios/Runner/Info.plist -->
<key>CFBundleDisplayName</key>
<string>Pulse</string>
```

The database filename and the display name are independent. The display name is marketing and can change. The database filename is infrastructure — changing it without a migration silently drops all user data on upgrade. This happened in this codebase: the app was renamed, the `driftDatabase(name: ...)` call was updated to match, and every existing user lost their data on the next update. Define `dbFileName` as a constant in one place so it's never accidentally changed, and write a migration if you ever do need to move it.

Verify the display name by building and running on a real device and looking at the home screen. The iOS plist and Android manifest have separate places for it that are easy to leave as `"App"`.

---

## Drift — Database Layer

### Table definitions

```dart
// lib/db/tables.dart
import 'package:drift/drift.dart';

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get note => text().nullable()();
  // Enum-like: 'cardio' | 'intervals' | null — set post-analysis
  TextColumn get detectedPattern => text().nullable()();
  // Denormalized: recomputed after session ends, null during recording
  RealColumn get avgBpm => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
}

class HeartRateSamples extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id)();
  DateTimeColumn get recordedAt => dateTime()();
  IntColumn get bpm => integer()();
}
```

`autoIncrement()` on every primary key — Drift uses this to infer the primary key, and without it you need to override `primaryKey`. Always store enum-like strings with a comment listing the valid values. Drift doesn't have a native enum column type, so the comment is the only documentation of the constraint.

Nullable fields should mean something specific — write what `null` means in a comment or in the design doc. `endedAt: null` means "session is still in progress" is a meaningful state; `avgBpm: null` means "not computed yet." Without this documentation, readers can't tell if null is "unknown," "not applicable," or "a bug."

Denormalized fields (cached computed values stored alongside the source data) are fine and are used in this codebase. Mark them with a comment so it's clear they're derived. Recompute them from source whenever the source changes — never update them directly without also checking the source.

### Database class

```dart
// lib/db/database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Sessions, HeartRateSamples])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor); // keeps tests fast and isolated

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
      name: dbFileName,
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

`AppDatabase.forTesting(super.executor)` lets tests inject an in-memory database without any file I/O, keeping tests fast. Always include it.

The `MigrationStrategy` must handle every schema version transition. Each time `schemaVersion` increments, add a branch. If you add a column and ship without adding it here, existing users get a crash on upgrade.

### Query patterns

```dart
// Reactive — use this with StreamProvider so UI rebuilds when data changes
(db.select(db.sessions)
  ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
  .watch()

// One-time read
await db.select(db.sessions).get()

// Conditional update — always use the cascade form, not a manual where-clause string
await (db.update(db.sessions)
  ..where((s) => s.id.equals(id)))
  .write(SessionsCompanion(
    title: Value(title),
    modifiedAt: Value(DateTime.now()),
  ));

// Multi-step write — wrap in transaction so it's atomic
await db.transaction(() async {
  await db.into(db.sessions).insert(...);
  await db.into(db.heartRateSamples).insertAll(...);
});
```

Use `.watch()` for anything the UI displays — it makes the UI automatically reflect database changes without manual refresh logic. Use `.get()` only when you need a one-time read that doesn't need to stay fresh. Always wrap multi-step writes in `db.transaction()` so partial writes can't leave the database in an inconsistent state.

---

## Riverpod — State Management

**Do not use `@riverpod` code generation.** Write providers manually. The generator saves a little boilerplate but adds a build step, obscures the provider type in the generated code, and makes it harder to see at a glance what kind of provider you have. Manual providers are explicit and readable.

### Provider types by use case

```dart
// Reactive database query — rebuilds any widget that watches it when data changes
final sessionsProvider = StreamProvider<List<Session>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.sessions)
    ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
    .watch();
});

// Parameterized — one stream per session ID
final samplesProvider =
    StreamProvider.family<List<HeartRateSample>, int>((ref, sessionId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.heartRateSamples)
    ..where((s) => s.sessionId.equals(sessionId))
    ..orderBy([(s) => OrderingTerm.asc(s.recordedAt)]))
    .watch();
});

// Mutable state with actions
class RecordingNotifier extends Notifier<RecordingState> {
  @override
  RecordingState build() => const RecordingState.idle();

  void start() => state = RecordingState.recording(startedAt: DateTime.now());
  void stop() => state = const RecordingState.idle();
}

final recordingProvider =
    NotifierProvider<RecordingNotifier, RecordingState>(RecordingNotifier.new);
```

`StreamProvider` is the right tool for any data that comes from the database — Drift's `.watch()` returns a `Stream`, and `StreamProvider` bridges that stream into Riverpod's reactivity graph. When the database changes, the stream emits, the provider updates, and only the widgets that watch that provider rebuild.

`NotifierProvider` is for state that lives outside the database — UI state, active recording state, BLE connection state.

Providers should depend on each other through `ref.watch()`, not by passing data down the widget tree. This is what makes Riverpod useful: a provider that depends on two others automatically recomputes when either changes.

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

Always handle all three states in `.when()`. Never use `.value` directly without checking for null/error — it silently shows nothing when the data hasn't loaded yet, which looks like a bug.

Provider file placement:
- Feature-specific providers → `features/<feature>/<feature>_providers.dart`
- `dbProvider` → `db/database.dart`
- Cross-feature providers → `features/shared/providers.dart`

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

extension AppNavigation on BuildContext {
  void navigate(String route) {
    // On web, go() updates the URL and replaces the history entry.
    // On mobile, push() maintains the back stack.
    if (kIsWeb) {
      go(route);
    } else {
      push(route);
    }
  }
}
```

Parse path parameters immediately in the `builder` — pass typed values (`int sessionId`) into widgets, not raw `GoRouterState`. Widgets shouldn't know about routing internals.

Use `context.navigate()` for standard navigation and `context.go()` only when you want to explicitly replace the back stack (e.g. after login, or navigating to home from a deep link).

---

## Theme

```dart
// lib/theme.dart
const Color kSeedColor = Color(0xFF______); // choose one brand color

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

Derive all colors from `ColorScheme.fromSeed`. Never hardcode hex values in widget files — if the seed color changes, everything should update automatically. In widgets: `final cs = Theme.of(context).colorScheme;` once per `build`, then use `cs.primary`, `cs.surface`, etc.

**Emoji rendering:** If you use a custom font (like Inter), emoji will render incorrectly — the font has text-style glyphs that override the system emoji renderer, turning ❤️ black and flat. Always display emoji with a style that opts out of font inheritance:

```dart
// lib/theme.dart — define once, use everywhere
const kEmojiStyle = TextStyle(
  inherit: false, // critical: don't inherit the app font
  fontSize: 24,
  textBaseline: TextBaseline.alphabetic,
);

// Usage
Text(emoji, style: kEmojiStyle)
```

This happened in this codebase and required touching every emoji Text widget to fix. Define `kEmojiStyle` centrally and use it from the start.

---

## Responsive UI

Flutter runs on phones, tablets, and web. Design for multiple widths from the start — retrofitting responsiveness is significantly more work than building it in.

**The core pattern: read the available width and make layout decisions from it.**

```dart
@override
Widget build(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final isWide = width > 600;

  return isWide
      ? Row(children: [_Sidebar(), Expanded(child: _Content())])
      : _Content();
}
```

Use `MediaQuery.sizeOf(context)` instead of `MediaQuery.of(context).size` — the former only rebuilds when size changes, which is more efficient.

Common breakpoints: `< 600` is phone portrait, `600–900` is phone landscape / small tablet, `> 900` is tablet/desktop. You rarely need more than two layout variants.

**For lists and grids,** let the cross-axis count respond to width:

```dart
final cols = width < 600 ? 1 : width < 900 ? 2 : 3;
GridView.count(crossAxisCount: cols, ...)
```

**For text and spacing,** avoid hardcoded pixel values for anything that needs to scale. Use the theme's text styles (`Theme.of(context).textTheme.bodyLarge`) and define spacing constants rather than magic numbers scattered through the code.

**Test on multiple sizes** by using Flutter's device preview or by resizing the browser window when running on web. Don't assume portrait phone is the only form factor.

---

## Low Latency UI

Perceived performance matters more than measured performance. A 300ms operation feels instant if there's immediate feedback; a 50ms operation feels broken if the UI doesn't react.

**Optimistic updates:** For writes that are very likely to succeed (e.g. logging a heart rate sample), update the UI immediately and let the database catch up in the background. Don't wait for the database write to complete before showing the new state.

**Never block the main thread.** All database reads and writes via Drift are already async — always `await` them and never call `.get()` synchronously. For expensive computations (signal analysis, HR zone calculations over thousands of samples), use `compute()` to run them on a background isolate:

```dart
final zones = await compute(_computeHrZones, samples);
```

**Show progress for anything over ~500ms.** A `LinearProgressIndicator` is enough. Disable the trigger button during the operation to prevent double-submits. This project had a mass edit operation that was slow and showed no feedback — the fix was a progress indicator and a disabled button while saving:

```dart
FilledButton(
  onPressed: _saving ? null : _save, // null disables it
  child: _saving
      ? const LinearProgressIndicator()
      : const Text('Save'),
)
```

**For real-time data (BLE heart rate stream),** Riverpod `StreamProvider` handles the stream efficiently without polling. The widget tree only rebuilds when a new sample arrives. To avoid rebuilding the entire chart on every sample, keep the chart data in a local list and use `setState` only on the chart widget, not the whole screen.

**For charts with many data points,** downsample before rendering. A LineChart with 10,000 points where 9,000 are off-screen is wasteful. Show at most ~500 points at a time and resample when the user zooms or pans.

---

## Charts (fl_chart)

Use `fl_chart` for all data visualization. It covers every chart type needed (line, bar, pie) and derives well from `ColorScheme`.

```dart
// Heart rate over time
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
        dotData: const FlDotData(show: false), // dots slow down large datasets
        belowBarData: BarAreaData(
          show: true,
          color: cs.primary.withValues(alpha: 0.15),
        ),
      ),
    ],
  ),
)
```

Always:
- Wrap charts in a `SizedBox` with an explicit height — charts don't size themselves
- Derive all colors from `ColorScheme`, never hardcode
- Compute chart data outside `build()` — put it in a provider or cache it in a local variable

---

## Business Logic

Pure functions (no Flutter imports, no Riverpod) live in `features/shared/`. They should take plain Dart values and return plain Dart values. This makes them easy to unit test and reuse.

When the logic is about deciding what to do in response to a user action, return an **enum** from a pure function rather than performing the action directly:

```dart
// Good — pure, testable, no side effects
enum HrZone { zone1, zone2, zone3, zone4, zone5 }

HrZone classifyBpm(int bpm, int maxHr) {
  final pct = bpm / maxHr;
  if (pct < 0.60) return HrZone.zone1;
  if (pct < 0.70) return HrZone.zone2;
  if (pct < 0.80) return HrZone.zone3;
  if (pct < 0.90) return HrZone.zone4;
  return HrZone.zone5;
}
```

Database mutation helpers are `async` functions that accept `AppDatabase` as a parameter:

```dart
Future<void> finalizeSession(AppDatabase db, int sessionId, List<HeartRateSample> samples) async {
  final avg = samples.map((s) => s.bpm).reduce((a, b) => a + b) ~/ samples.length;
  await (db.update(db.sessions)..where((s) => s.id.equals(sessionId)))
      .write(SessionsCompanion(
        endedAt: Value(DateTime.now()),
        avgBpm: Value(avg.toDouble()),
        modifiedAt: Value(DateTime.now()),
      ));
}
```

**When iterating to find the "best" match** (highest milestone crossed, most relevant suggestion), iterate from highest priority first and return on the first match — not lowest-first. This project had a bug where a user jumping from 24% to 76% was shown the 25% milestone instead of the 75% one because the list iterated ascending. Iterate `[1.0, 0.75, 0.5, 0.25]`, not `[0.25, 0.5, 0.75, 1.0]`.

---

## main.dart Bootstrap

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // web: clean URLs without hash (#)
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
      // Reconnect BLE, refresh stale state, etc.
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

`ProviderScope` wraps the entire app — this is the Riverpod root. The root widget is a `ConsumerStatefulWidget` rather than `StatelessWidget` because it needs to observe lifecycle events (app backgrounded, resumed) to react appropriately — reconnecting BLE, refreshing time-sensitive state, etc.

---

## Widget Conventions

Screens extend `ConsumerWidget` (read-only) or `ConsumerStatefulWidget` (when local state like `TextEditingController`, `AnimationController`, or form state is needed). Prefer `ConsumerWidget` — if you find yourself using `setState`, consider whether the state belongs in a `NotifierProvider` instead.

Extract private sub-widgets (`class _SessionCard extends StatelessWidget`) in the same file when a widget is only used within that screen. This keeps the `build` method readable without creating unnecessary files. Only move a widget to its own file if it's reused across multiple features.

For forms:
```dart
class _EditSessionState extends ConsumerState<EditSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _titleController.dispose(); // always dispose controllers
    super.dispose();
  }
}
```

Always dispose `TextEditingController`, `AnimationController`, and `FocusNode` in `dispose()`. Forgetting this causes memory leaks that are invisible until the app is running for a long time.

Dialog buttons should be full-width, tall (at least 48dp), and visually distinct for destructive actions. `SimpleDialogOption` is too basic — use `ElevatedButton` or `FilledButton` with explicit padding:

```dart
SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: onDelete,
    style: ElevatedButton.styleFrom(
      backgroundColor: cs.errorContainer,
      foregroundColor: cs.onErrorContainer,
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
    child: const Text('Delete session'),
  ),
)
```

---

## Code Generation

Run after changing any Drift table definition:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Never edit `*.g.dart` files. Commit them alongside the source file — they're generated artifacts that should be in version control so CI doesn't require a build step to compile.

---

## iOS Build and CI

Set these up correctly before the first build attempt, not after CI fails:

**Podfile** — uncomment the platform line and set an explicit version:
```ruby
platform :ios, '13.0'
```
Without this, pods may pick an incompatible version and fail in ways that are hard to diagnose.

**Xcode Cloud `ci_post_clone.sh`** (in `ios/ci_scripts/`):
```sh
#!/bin/sh
flutter config --no-analytics
flutter precache --ios
pod install
```
Without this, Xcode Cloud won't know how to run `flutter` and the build will fail on the first try.

**Info.plist** — set display name and all required permission strings before the first TestFlight build:
```xml
<key>CFBundleDisplayName</key>
<string>Your App Name</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Used to connect to your heart rate monitor.</string>
```
Missing permission strings cause App Store rejection or runtime crashes on iOS — they're not warnings.

**HealthKit** (if using the `health` package): the HealthKit entitlement requires explicit Apple approval for App Store distribution. Apply for it early — it can take time.

---

## Platform Permissions Checklist

**BLE (flutter_blue_plus):**
- Android `AndroidManifest.xml`: `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`; on Android < 12 also `ACCESS_FINE_LOCATION`
- iOS `Info.plist`: `NSBluetoothAlwaysUsageDescription`

**Health (health package):**
- iOS: `NSHealthReadUsageDescription` in `Info.plist` + HealthKit entitlement in `Runner.entitlements`
- Android: Health Connect permissions in `AndroidManifest.xml`

Add these before writing any code that uses these APIs — missing permissions cause crashes or silent failures that are confusing to debug.
