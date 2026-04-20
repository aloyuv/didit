import 'package:didit/db/database.dart';
import 'package:didit/features/home/streak_display.dart';
import 'package:didit/theme.dart';
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
}
