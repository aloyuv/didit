import 'package:didit/db/database.dart';
import 'package:didit/features/settings/drive_backup_service.dart';
import 'package:didit/features/habit_log_actions.dart';
import 'package:didit/features/home/milestone_utils.dart';
import 'package:didit/features/home/streak_display.dart';
import 'package:didit/features/tracker_details/log_edit_sheet.dart';
import 'package:didit/features/tracker_details/value_breakdown.dart';
import 'package:didit/features/tracker_denormalized.dart';
import 'package:didit/features/tracker_type/template_goal_presets.dart';
import 'package:didit/theme.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () {
    expect(1 + 1, 2);
  });

  test('theme uses the logo color as its seed', () {
    expect(kSeedColor, const Color(0xFF6CCA65));
  });

  test('tracker stores emoji separately from its name', () {
    final now = DateTime(2026, 4, 20);
    final tracker = Tracker(
      id: 1,
      name: 'Run',
      emoji: '🏃',
      type: 'habit',
      sortOrder: 1,
      archived: false,
      createdAt: now,
      modifiedAt: now,
    );

    final json = tracker.toJson();

    expect(json['name'], 'Run');
    expect(json['emoji'], '🏃');
  });

  test('daily goal template target includes today through end of year', () {
    final target = targetForDailyGoalThroughEndOfYear(
      today: DateTime(2026, 6, 18, 15, 30),
      dailyAmount: 4,
    );

    expect(target, 788);
  });

  test('daily goal template target counts Dec 31 as one remaining day', () {
    final target = targetForDailyGoalThroughEndOfYear(
      today: DateTime(2026, 12, 31, 23, 59),
      dailyAmount: 4,
    );

    expect(target, 4);
  });

  test('unlogged cards use a neutral grey gradient', () {
    final colorScheme = ColorScheme.fromSeed(seedColor: kSeedColor);

    expect(
      cardGradientBottom(colorScheme, 0),
      Color.lerp(colorScheme.surface, colorScheme.surfaceContainerHighest, 0.2),
    );
  });

  test('logged cards use a light logo green gradient', () {
    final colorScheme = ColorScheme.fromSeed(seedColor: kSeedColor);

    expect(
      cardGradientTop(colorScheme, 1),
      Color.lerp(colorScheme.surface, colorScheme.primaryContainer, 0.9),
    );
    expect(
      cardGradientBottom(colorScheme, 1),
      Color.lerp(colorScheme.primaryContainer, kSeedColor, 0.18),
    );
  });

  test('habit display shows yesterday streak before today is logged', () {
    final display = habitStreakDisplay(
      doneToday: false,
      logDates: const {},
      today: DateTime(2026, 4, 20),
      cachedStreak: 2,
    );

    expect(display.label, '2 days yesterday');
  });

  test('habit display shows current streak after today is logged', () {
    final display = habitStreakDisplay(
      doneToday: true,
      logDates: {'2026-04-18', '2026-04-19', '2026-04-20'},
      today: DateTime(2026, 4, 20),
    );

    expect(display.label, '3 day streak');
  });

  test('habit display parses log dates only when cached streak is missing', () {
    final display = habitStreakDisplay(
      doneToday: false,
      logDates: {'2026-04-18', '2026-04-19'},
      today: DateTime(2026, 4, 20),
      cachedStreak: 0,
    );

    expect(display.label, '2 days yesterday');
  });

  test(
      'habit denormalized streak keeps yesterday streak before today is logged',
      () {
    final streak = calculateHabitStreak(
      logDates: const {'2026-04-17', '2026-04-18', '2026-04-19'},
      today: DateTime(2026, 4, 20),
    );

    expect(streak, 3);
  });

  test('habit denormalized streak is zero after a missed day', () {
    final streak = calculateHabitStreak(
      logDates: const {'2026-04-15', '2026-04-16', '2026-04-17'},
      today: DateTime(2026, 4, 20),
    );

    expect(streak, 0);
  });

  // Weekly streak tests (weeks start Monday)
  // 2026-04-20 is a Monday

  test('weekly streak counts consecutive logged weeks', () {
    // Logged on Mon Apr 6, Mon Apr 13, Mon Apr 20 (3 different weeks)
    final streak = calculateHabitStreak(
      logDates: const {'2026-04-06', '2026-04-13', '2026-04-20'},
      today: DateTime(2026, 4, 20),
      period: 'weekly',
    );

    expect(streak, 3);
  });

  test('weekly streak is zero after a missed week', () {
    // Logged week of Apr 6 and Apr 20 but not Apr 13 — gap breaks streak
    final streak = calculateHabitStreak(
      logDates: const {'2026-04-06', '2026-04-20'},
      today: DateTime(2026, 4, 20),
      period: 'weekly',
    );

    expect(streak, 1);
  });

  test('weekly streak counts this week even when logged mid-week', () {
    // Today is Wednesday Apr 22; logged Monday Apr 20 (same week) and last week
    final streak = calculateHabitStreak(
      logDates: const {'2026-04-13', '2026-04-20'},
      today: DateTime(2026, 4, 22),
      period: 'weekly',
    );

    expect(streak, 2);
  });

  test('weekly streak preserves last-week streak when this week not yet logged',
      () {
    // Today is Wednesday Apr 22; only logged last week — streak is still 1
    final streak = calculateHabitStreak(
      logDates: const {'2026-04-13', '2026-04-14'},
      today: DateTime(2026, 4, 22),
      period: 'weekly',
    );

    expect(streak, 1);
  });

  test('weekly display shows week streak label when logged this week', () {
    // Logged earlier this week (not today) — period=weekly should detect this week
    final display = habitStreakDisplay(
      doneToday: false,
      logDates: const {'2026-04-20', '2026-04-13'},
      today: DateTime(2026, 4, 22),
      period: 'weekly',
    );

    expect(display.label, '2 week streak');
  });

  test('weekly display shows last week label when this week not logged', () {
    final display = habitStreakDisplay(
      doneToday: false,
      logDates: const {'2026-04-13', '2026-04-06'},
      today: DateTime(2026, 4, 22),
      period: 'weekly',
    );

    expect(display.label, '2 weeks last week');
  });

  // Monthly streak tests

  test('monthly streak counts consecutive logged months', () {
    final streak = calculateHabitStreak(
      logDates: const {'2026-02-15', '2026-03-10', '2026-04-01'},
      today: DateTime(2026, 4, 20),
      period: 'monthly',
    );

    expect(streak, 3);
  });

  test('monthly streak is zero after a missed month', () {
    // Feb and Apr logged but not March
    final streak = calculateHabitStreak(
      logDates: const {'2026-02-15', '2026-04-01'},
      today: DateTime(2026, 4, 20),
      period: 'monthly',
    );

    expect(streak, 1);
  });

  test(
      'monthly streak preserves last-month streak when this month not yet logged',
      () {
    final streak = calculateHabitStreak(
      logDates: const {'2026-02-15', '2026-03-10'},
      today: DateTime(2026, 4, 20),
      period: 'monthly',
    );

    expect(streak, 2);
  });

  test('monthly streak handles year boundary', () {
    final streak = calculateHabitStreak(
      logDates: const {'2025-11-01', '2025-12-01', '2026-01-01'},
      today: DateTime(2026, 1, 15),
      period: 'monthly',
    );

    expect(streak, 3);
  });

  test('monthly display shows month streak label when logged this month', () {
    final display = habitStreakDisplay(
      doneToday: false,
      logDates: const {'2026-04-01', '2026-03-15'},
      today: DateTime(2026, 4, 20),
      period: 'monthly',
    );

    expect(display.label, '2 month streak');
  });

  test('monthly display shows last month label when this month not logged', () {
    final display = habitStreakDisplay(
      doneToday: false,
      logDates: const {'2026-02-15', '2026-03-10'},
      today: DateTime(2026, 4, 20),
      period: 'monthly',
    );

    expect(display.label, '2 months last month');
  });

  // ---------------------------------------------------------------------------
  // resolveHabitTapIntent — pure function, no Flutter or DB needed
  // ---------------------------------------------------------------------------

  Log logWithValue(double? value) => Log(
        id: 1,
        trackerId: 1,
        logDate: '2026-04-20',
        createdAt: DateTime(2026, 4, 20),
        modifiedAt: DateTime(2026, 4, 20),
        value: value,
        isFreeze: null,
        note: null,
      );

  const toggle3 = ['bad', 'ok', 'great']; // exactly K=3 → Toggle
  const pick4 = ['1', '2', '3', '4']; // K+1 → Pick

  // Anytime habit (isAllowMultiple)
  test('anytime, unlogged, no options → insertBinary', () {
    expect(
      resolveHabitTapIntent(
          isAllowMultiple: true, valueOptions: [], existing: null),
      HabitTapIntent.insertBinary,
    );
  });

  test('anytime, unlogged, with options → showInsertPicker', () {
    expect(
      resolveHabitTapIntent(
          isAllowMultiple: true, valueOptions: toggle3, existing: null),
      HabitTapIntent.showInsertPicker,
    );
  });

  test('anytime, logged → showAddOrUpdateDialog regardless of options', () {
    final log = logWithValue(0);
    expect(
      resolveHabitTapIntent(
          isAllowMultiple: true, valueOptions: toggle3, existing: log),
      HabitTapIntent.showAddOrUpdateDialog,
    );
    expect(
      resolveHabitTapIntent(
          isAllowMultiple: true, valueOptions: [], existing: log),
      HabitTapIntent.showAddOrUpdateDialog,
    );
  });

  // Periodic binary habit (no options)
  test('periodic binary, unlogged → insertBinary', () {
    expect(
      resolveHabitTapIntent(
          isAllowMultiple: false, valueOptions: [], existing: null),
      HabitTapIntent.insertBinary,
    );
  });

  test('periodic binary, logged → deleteBinary', () {
    expect(
      resolveHabitTapIntent(
          isAllowMultiple: false,
          valueOptions: [],
          existing: logWithValue(null)),
      HabitTapIntent.deleteBinary,
    );
  });

  // Periodic Toggle habit (≤K options)
  test('toggle, unlogged → cycleNext', () {
    expect(
      resolveHabitTapIntent(
          isAllowMultiple: false, valueOptions: toggle3, existing: null),
      HabitTapIntent.cycleNext,
    );
  });

  test('toggle, logged at index 0 of 3 → cycleNext (mid-cycle)', () {
    expect(
      resolveHabitTapIntent(
          isAllowMultiple: false,
          valueOptions: toggle3,
          existing: logWithValue(0)),
      HabitTapIntent.cycleNext,
    );
  });

  test('toggle, logged at index 1 of 3 → cycleNext (mid-cycle)', () {
    expect(
      resolveHabitTapIntent(
          isAllowMultiple: false,
          valueOptions: toggle3,
          existing: logWithValue(1)),
      HabitTapIntent.cycleNext,
    );
  });

  test('toggle, logged at last index → showLogEditor (end of cycle)', () {
    expect(
      resolveHabitTapIntent(
          isAllowMultiple: false,
          valueOptions: toggle3,
          existing: logWithValue(2)),
      HabitTapIntent.showLogEditor,
    );
  });

  // Periodic Pick habit (>K options)
  test('pick, unlogged → showInsertPicker', () {
    expect(
      resolveHabitTapIntent(
          isAllowMultiple: false, valueOptions: pick4, existing: null),
      HabitTapIntent.showInsertPicker,
    );
  });

  test('pick, logged → showUpdatePicker', () {
    expect(
      resolveHabitTapIntent(
          isAllowMultiple: false,
          valueOptions: pick4,
          existing: logWithValue(2)),
      HabitTapIntent.showUpdatePicker,
    );
  });

  // ---------------------------------------------------------------------------
  // isMilestoneNumber
  // ---------------------------------------------------------------------------

  for (final (n, expected) in [
    (1, false), (5, false), (9, false), // single digits
    (11, false), (23, false), (99, false), // non-round two-digit
    (10, true), (20, true), (50, true), (90, true), // multiples of 10
    (100, true), (200, true), (500, true), // multiples of 100
    (111, true), (222, true), (333, true), (666, true), (999, true),
    (1111, true), // repeated digits
    (365, true), (730, true), // year multiples
  ]) {
    test('isMilestoneNumber($n) == $expected', () {
      expect(isMilestoneNumber(n), expected);
    });
  }

  // ---------------------------------------------------------------------------
  // goalMilestoneCrossed
  // ---------------------------------------------------------------------------

  for (final (old, next, label) in [
    (0.0, 10.0, null), // below first milestone
    (26.0, 40.0, null), // already past 25%, not crossing anything new
    (0.0, 25.0, '25%'), // exact 25%
    (30.0, 50.0, '50%'), // exact 50%
    (90.0, 100.0, '100%'), // completing the goal
    (24.0, 76.0, '75%'), // jump over 25% and 50% — highest wins
    (0.0, 100.0, '100%'), // jump all the way — 100% wins
  ]) {
    test('goalMilestoneCrossed($old → $next / 100) == $label', () {
      expect(goalMilestoneCrossed(old, next, 100), label);
    });
  }

  // ---------------------------------------------------------------------------
  // isBackupDue
  // ---------------------------------------------------------------------------

  final t0 = DateTime.utc(2026, 1, 1, 12, 0, 0);

  for (final (elapsed, expected, label) in [
    (null, true, 'no previous backup'),
    (const Duration(hours: 1, seconds: 1), true, 'over 1 hour ago'),
    (const Duration(hours: 1), true, 'exactly 1 hour ago'),
    (const Duration(minutes: 59), false, 'under 1 hour ago'),
    (Duration.zero, false, 'immediately after backup'),
  ]) {
    test('isBackupDue: $label', () {
      final lastMs =
          elapsed == null ? null : t0.subtract(elapsed).millisecondsSinceEpoch;
      expect(isBackupDue(lastMs, t0), expected);
    });
  }

  // ---------------------------------------------------------------------------

  test('two taps racing on the same day insert only one log', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final trackerId = await db.into(db.trackers).insert(
          TrackersCompanion.insert(
            name: 'Running',
            type: 'habit',
            sortOrder: 0,
            createdAt: DateTime(2026, 7, 14),
            modifiedAt: DateTime(2026, 7, 14),
            habitPeriod: const Value('daily'),
          ),
        );
    final tracker = await (db.select(db.trackers)
          ..where((t) => t.id.equals(trackerId)))
        .getSingle();

    // Both calls see "not logged yet" — the state the UI is in while the drift
    // stream has not emitted the first insert yet.
    final ids = await Future.wait([
      insertLogIfAbsent(db, tracker, '2026-07-14'),
      insertLogIfAbsent(db, tracker, '2026-07-14'),
    ]);

    final logs = await db.select(db.logs).get();
    expect(logs.length, 1);
    expect(logs.single.logDate, '2026-07-14');
    expect(ids.where((id) => id != null).length, 1);
    expect(ids.where((id) => id == null).length, 1);

    await db.close();
  });

  test('cycleHabitValueOption reports the stored value when existing is stale',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final trackerId = await db.into(db.trackers).insert(
          TrackersCompanion.insert(
            name: 'Reading',
            type: 'habit',
            sortOrder: 0,
            createdAt: DateTime(2026, 7, 14),
            modifiedAt: DateTime(2026, 7, 14),
            habitPeriod: const Value('daily'),
          ),
        );
    final tracker = await (db.select(db.trackers)
          ..where((t) => t.id.equals(trackerId)))
        .getSingle();

    // The day is already logged at option index 2, but the UI's snapshot still
    // says unlogged — the cycle must report 2, not the 0 it would have written.
    await insertLogIfAbsent(db, tracker, '2026-07-14', value: 2);
    final idx = await cycleHabitValueOption(
        db, tracker, '2026-07-14', null, ['a', 'b', 'c']);

    expect(idx, 2);
    final logs = await db.select(db.logs).get();
    expect(logs.length, 1);
    expect(logs.single.value, 2);

    await db.close();
  });

  test('insertLogIfAbsent still logs a day that has no log yet', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final trackerId = await db.into(db.trackers).insert(
          TrackersCompanion.insert(
            name: 'Running',
            type: 'habit',
            sortOrder: 0,
            createdAt: DateTime(2026, 7, 14),
            modifiedAt: DateTime(2026, 7, 14),
            habitPeriod: const Value('daily'),
          ),
        );
    final tracker = await (db.select(db.trackers)
          ..where((t) => t.id.equals(trackerId)))
        .getSingle();

    await insertLogIfAbsent(db, tracker, '2026-07-13', value: 2);
    final second = await insertLogIfAbsent(db, tracker, '2026-07-14');

    expect(second != null, isTrue);
    final logs = await db.select(db.logs).get();
    expect(logs.map((l) => l.logDate), ['2026-07-13', '2026-07-14']);
    expect(logs.first.value, 2);

    await db.close();
  });

  Future<int> insertTracker(AppDatabase db, String name,
          {String type = 'habit'}) =>
      db.into(db.trackers).insert(TrackersCompanion.insert(
            name: name,
            type: type,
            sortOrder: 0,
            createdAt: DateTime(2026, 5, 1),
            modifiedAt: DateTime(2026, 5, 1),
          ));

  test('deleting a tracker deletes its logs and leaves others alone', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final keep = await insertTracker(db, 'Keeper');
    final doomed = await insertTracker(db, 'Doomed');
    for (final id in [keep, doomed]) {
      await db.into(db.logs).insert(LogsCompanion.insert(
            trackerId: id,
            logDate: '2026-05-07',
            createdAt: DateTime(2026, 5, 7),
            modifiedAt: DateTime(2026, 5, 7),
          ));
    }

    await db.deleteTrackerWithLogs(doomed);

    final logs = await db.select(db.logs).get();
    expect(logs.map((l) => l.trackerId), [keep]);

    await db.close();
  });

  test('a log cannot be left pointing at a tracker that does not exist',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await insertTracker(db, 'Keeper');

    await expectLater(
      db.into(db.logs).insert(LogsCompanion.insert(
            trackerId: 999,
            logDate: '2026-05-07',
            createdAt: DateTime(2026, 5, 7),
            modifiedAt: DateTime(2026, 5, 7),
          )),
      throwsA(isA<Exception>()),
    );

    await db.close();
  });

  test('a restored backup cannot hand old logs to a brand-new tracker',
      () async {
    // A backup taken after the tracker that owned log 500 was deleted: the log
    // survived the delete and points past the highest surviving tracker id.
    final backup = {
      'version': 1,
      'exportedAt': DateTime(2026, 7, 13).millisecondsSinceEpoch,
      'trackers': [
        Tracker(
          id: 1,
          name: 'Daily cardio',
          type: 'habit',
          sortOrder: 0,
          archived: false,
          createdAt: DateTime(2026, 4, 25),
          modifiedAt: DateTime(2026, 4, 25),
          habitPeriod: 'daily',
        ).toJson(),
      ],
      'logs': [
        Log(
          id: 500,
          trackerId: 2, // orphaned by a tracker delete
          logDate: '2026-05-07',
          createdAt: DateTime(2026, 5, 7),
          modifiedAt: DateTime(2026, 5, 7),
          value: 1,
          isFreeze: null,
          note: null,
        ).toJson(),
      ],
    };

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.importData(backup);
    expect(await db.select(db.logs).get(), isEmpty);

    // The next tracker created takes id 2 — the orphan's id.
    final newGoal = await insertTracker(db, 'Shuffles', type: 'goal');
    expect(newGoal, 2);
    final adopted = await (db.select(db.logs)
          ..where((l) => l.trackerId.equals(newGoal)))
        .get();
    expect(adopted, isEmpty);

    await db.close();
  });

  test('the schema-4 sweep clears logs an older version orphaned', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final keep = await insertTracker(db, 'Keeper');
    await db.into(db.logs).insert(LogsCompanion.insert(
          trackerId: keep,
          logDate: '2026-05-06',
          createdAt: DateTime(2026, 5, 6),
          modifiedAt: DateTime(2026, 5, 6),
        ));

    // Recreate what a pre-schema-4 tracker delete left behind: the log stays,
    // its tracker does not.
    final doomed = await insertTracker(db, 'Doomed');
    await db.into(db.logs).insert(LogsCompanion.insert(
          trackerId: doomed,
          logDate: '2026-05-07',
          createdAt: DateTime(2026, 5, 7),
          modifiedAt: DateTime(2026, 5, 7),
        ));
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await (db.delete(db.trackers)..where((t) => t.id.equals(doomed))).go();
    await db.customStatement('PRAGMA foreign_keys = ON');
    expect((await db.select(db.logs).get()).length, 2);

    await db.deleteOrphanLogs();

    final logs = await db.select(db.logs).get();
    expect(logs.map((l) => l.logDate), ['2026-05-06']);

    await db.close();
  });

  test('export/import round-trips all tracker and log data', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    final trackerId = await db.into(db.trackers).insert(
          TrackersCompanion.insert(
            name: 'Running',
            emoji: const Value('🏃'),
            type: 'habit',
            sortOrder: 0,
            createdAt: DateTime(2026, 1, 1),
            modifiedAt: DateTime(2026, 1, 1),
            habitPeriod: const Value('daily'),
          ),
        );

    await db.into(db.logs).insert(LogsCompanion.insert(
          trackerId: trackerId,
          logDate: '2026-04-01',
          createdAt: DateTime(2026, 4, 1),
          modifiedAt: DateTime(2026, 4, 1),
          note: const Value('felt great'),
        ));

    final exported = await db.exportData();
    await db.importData(exported);

    final restoredTrackers = await db.select(db.trackers).get();
    expect(restoredTrackers.length, 1);
    expect(restoredTrackers.first.id, trackerId);
    expect(restoredTrackers.first.name, 'Running');
    expect(restoredTrackers.first.emoji, '🏃');
    expect(restoredTrackers.first.habitPeriod, 'daily');

    final restoredLogs = await db.select(db.logs).get();
    expect(restoredLogs.length, 1);
    expect(restoredLogs.first.trackerId, trackerId);
    expect(restoredLogs.first.logDate, '2026-04-01');
    expect(restoredLogs.first.note, 'felt great');

    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Log edit sheet — saves as you type, no Save button
  // ---------------------------------------------------------------------------

  Future<(AppDatabase, Tracker, Log)> seedTrackerWithLog() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final trackerId = await db.into(db.trackers).insert(
          TrackersCompanion.insert(
            name: 'Running',
            type: 'habit',
            sortOrder: 0,
            createdAt: DateTime(2026, 7, 14),
            modifiedAt: DateTime(2026, 7, 14),
            habitPeriod: const Value('daily'),
          ),
        );
    final tracker = await (db.select(db.trackers)
          ..where((t) => t.id.equals(trackerId)))
        .getSingle();
    await db.into(db.logs).insert(LogsCompanion.insert(
          trackerId: trackerId,
          logDate: '2026-07-14',
          createdAt: DateTime(2026, 7, 14),
          modifiedAt: DateTime(2026, 7, 14),
        ));
    final log = await db.select(db.logs).getSingle();
    return (db, tracker, log);
  }

  Future<void> openLogEditSheet(
    WidgetTester tester,
    AppDatabase db,
    Tracker tracker,
    Log log,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showLogEditSheet(context, ref, log: log, tracker: tracker),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the log editor has no Save button', (tester) async {
    final (db, tracker, log) = await seedTrackerWithLog();
    await openLogEditSheet(tester, db, tracker, log);

    expect(find.text('Save'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Done'), findsOneWidget);

    await db.close();
  });

  testWidgets('a typed note is saved once typing pauses', (tester) async {
    final (db, tracker, log) = await seedTrackerWithLog();
    await openLogEditSheet(tester, db, tracker, log);

    await tester.enterText(find.byType(TextField), 'felt great');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    final stored = await db.select(db.logs).getSingle();
    expect(stored.note, 'felt great');

    await db.close();
  });

  testWidgets('a note is saved even when the sheet closes mid-edit',
      (tester) async {
    final (db, tracker, log) = await seedTrackerWithLog();
    await openLogEditSheet(tester, db, tracker, log);

    // Closing before the debounce elapses must still flush the edit.
    await tester.enterText(find.byType(TextField), 'closed too fast');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final stored = await db.select(db.logs).getSingle();
    expect(stored.note, 'closed too fast');

    await db.close();
  });

  // ---------------------------------------------------------------------------
  // tallyLogsByValue — "how many runs vs cycles"
  // ---------------------------------------------------------------------------

  Log logOnDate(String date, double? value) => Log(
        id: date.hashCode,
        trackerId: 1,
        logDate: date,
        createdAt: DateTime(2026, 4, 20),
        modifiedAt: DateTime(2026, 4, 20),
        value: value,
        isFreeze: null,
        note: null,
      );

  test('tallies each value option in option order', () {
    final tallies = tallyLogsByValue(
      options: ['Run', 'Cycle', 'Swim'],
      logs: [
        logOnDate('2026-04-01', 1),
        logOnDate('2026-04-02', 0),
        logOnDate('2026-04-03', 1),
        logOnDate('2026-04-04', 1),
      ],
    );

    expect(tallies.map((t) => t.label), ['Run', 'Cycle']);
    expect(tallies.map((t) => t.count), [1, 3]);
    expect(tallies.map((t) => t.optionIndex), [0, 1]);
  });

  test('tallies keep the option index so repeated labels stay distinct', () {
    final tallies = tallyLogsByValue(
      options: ['Walk', 'Walk'],
      logs: [logOnDate('2026-04-01', 1)],
    );

    expect(tallies.single.label, 'Walk');
    expect(tallies.single.optionIndex, 1);
  });

  test('logs with no usable value land in one trailing bucket', () {
    final tallies = tallyLogsByValue(
      options: ['Run', 'Cycle'],
      logs: [
        logOnDate('2026-04-01', 0),
        // Logged before the habit had options, and a value out of range.
        logOnDate('2026-04-02', null),
        logOnDate('2026-04-03', 7),
      ],
    );

    expect(tallies.map((t) => t.label), ['Run', unspecifiedValueLabel]);
    expect(tallies.last.count, 2);
    expect(tallies.last.optionIndex, null);
  });

  test('a habit with no logs tallies nothing', () {
    expect(tallyLogsByValue(options: ['Run'], logs: []), isEmpty);
  });
}
