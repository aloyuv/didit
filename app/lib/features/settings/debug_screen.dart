import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show Value, InsertMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../db/database.dart';
import '../milestones/milestone_explosion.dart';
import '../tracker_denormalized.dart';

class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  bool _loading = false;

  Future<void> _addTestData() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(dbProvider);
      final now = DateTime.now();

      String dateKey(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      Future<Tracker> insertHabit({
        required String name,
        String? emoji,
        required String period,
        required int sortOrder,
      }) async {
        final id = await db.into(db.trackers).insert(TrackersCompanion.insert(
              name: name,
              emoji: Value(emoji),
              type: 'habit',
              sortOrder: sortOrder,
              createdAt: now,
              modifiedAt: now,
              habitPeriod: Value(period),
            ));
        return (db.select(db.trackers)..where((t) => t.id.equals(id)))
            .getSingle();
      }

      Future<void> insertDailyLogs(Tracker tracker, int days) async {
        await db.batch((batch) {
          for (var i = 1; i <= days; i++) {
            final d = now.subtract(Duration(days: i));
            batch.insert(
              db.logs,
              LogsCompanion.insert(
                trackerId: tracker.id,
                logDate: dateKey(d),
                createdAt: now,
                modifiedAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
          }
        });
      }

      // Daily run — 2319-day streak
      final run = await insertHabit(
          name: 'Daily Run', emoji: '🏃', period: 'daily', sortOrder: 100);
      await insertDailyLogs(run, 2399);
      await recomputeHabitStreak(db, run, today: now);

      // Meditate — 30-day streak
      final meditate = await insertHabit(
          name: 'Meditate', emoji: '🧘', period: 'daily', sortOrder: 101);
      await insertDailyLogs(meditate, 30);
      await recomputeHabitStreak(db, meditate, today: now);

      // Drink water — 7-day streak
      final water = await insertHabit(
          name: 'Drink Water', emoji: '💧', period: 'daily', sortOrder: 102);
      await insertDailyLogs(water, 7);
      await recomputeHabitStreak(db, water, today: now);

      // Mood — 30 days of random 1–5 values
      final rng = Random();
      final moodId = await db.into(db.trackers).insert(TrackersCompanion.insert(
            name: 'Mood',
            emoji: const Value('🌡️'),
            type: 'habit',
            sortOrder: 103,
            createdAt: now,
            modifiedAt: now,
            habitPeriod: const Value('daily'),
            habitValueOptions: Value(jsonEncode(['1', '2', '3', '4', '5'])),
            habitAllowMultiple: const Value(true),
          ));
      final mood = (db.select(db.trackers)..where((t) => t.id.equals(moodId)))
          .getSingle();
      await db.batch((batch) {
        for (var i = 1; i <= 30; i++) {
          final d = now.subtract(Duration(days: i));
          batch.insert(
            db.logs,
            LogsCompanion.insert(
              trackerId: moodId,
              logDate: dateKey(d),
              createdAt: now,
              modifiedAt: now,
              value: Value(rng.nextInt(5).toDouble()),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });
      await recomputeHabitStreak(db, await mood, today: now);

      // Goal: read 52 books
      final booksId =
          await db.into(db.trackers).insert(TrackersCompanion.insert(
                name: 'Read 52 Books',
                emoji: const Value('📚'),
                type: 'goal',
                sortOrder: 104,
                createdAt: now,
                modifiedAt: now,
                goalUnit: const Value('books'),
                goalTargetAmount: const Value(52),
                goalStartDate: Value(DateTime(now.year, 1, 1)),
                goalTargetDate: Value(DateTime(now.year, 12, 31)),
                goalStepSize: const Value(1),
              ));
      final books = (db.select(db.trackers)..where((t) => t.id.equals(booksId)))
          .getSingle();
      await db.batch((batch) {
        for (var i = 0; i < 17; i++) {
          final d = now.subtract(Duration(days: i * 11));
          batch.insert(
            db.logs,
            LogsCompanion.insert(
              trackerId: booksId,
              logDate: dateKey(d),
              createdAt: now,
              modifiedAt: now,
              value: const Value(1),
            ),
          );
        }
      });
      await recomputeGoalTotal(db, await books);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test data added!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colorEntries = [
      MapEntry('Primary', scheme.primary),
      MapEntry('On Primary', scheme.onPrimary),
      MapEntry('Primary Container', scheme.primaryContainer),
      MapEntry('On Primary Container', scheme.onPrimaryContainer),
      MapEntry('Secondary', scheme.secondary),
      MapEntry('On Secondary', scheme.onSecondary),
      MapEntry('Secondary Container', scheme.secondaryContainer),
      MapEntry('Tertiary', scheme.tertiary),
      MapEntry('On Tertiary', scheme.onTertiary),
      MapEntry('Surface', scheme.surface),
      MapEntry('On Surface', scheme.onSurface),
      MapEntry('Surface Container', scheme.surfaceContainer),
      MapEntry('Error', scheme.error),
      MapEntry('On Error', scheme.onError),
      MapEntry('Outline', scheme.outline),
      MapEntry('Outline Variant', scheme.outlineVariant),
      MapEntry('Shadow', scheme.shadow),
      MapEntry('Scrim', scheme.scrim),
      MapEntry('Inverse Surface', scheme.inverseSurface),
      MapEntry('Inverse Primary', scheme.inversePrimary),
    ];

    String colorHex(Color c) {
      final v = c.toARGB32();
      return '#${(v & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug'),
        leading: BackButton(onPressed: () => context.go('/settings')),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _loading ? null : _addTestData,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.science),
              label: Text(
                  _loading ? 'Adding test data…' : 'Add test habits & goals'),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => showMilestoneExplosion(context, '25%'),
              icon: const Icon(Icons.celebration),
              label: const Text('Milestone explosion demo'),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Theme Colors',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ...colorEntries.map((entry) {
            final luminance = entry.value.computeLuminance();
            final textColor = luminance > 0.35 ? Colors.black : Colors.white;
            return Container(
              color: entry.value,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key,
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.bold)),
                  Text(colorHex(entry.value),
                      style: TextStyle(color: textColor, fontSize: 12)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
