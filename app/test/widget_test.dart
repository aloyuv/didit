import 'package:didit/db/database.dart';
import 'package:didit/features/home/streak_display.dart';
import 'package:didit/features/tracker_denormalized.dart';
import 'package:didit/theme.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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

  test('unlogged cards use a neutral grey gradient', () {
    final colorScheme = ColorScheme.fromSeed(seedColor: kSeedColor);

    expect(
      cardGradientBottom(colorScheme, 0),
      Color.lerp(colorScheme.surface, colorScheme.surfaceContainerHighest, 0.5),
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
}
