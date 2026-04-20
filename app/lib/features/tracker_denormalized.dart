import 'package:drift/drift.dart';

import '../db/database.dart';

Future<int> recomputeHabitStreak(
  AppDatabase db,
  Tracker tracker, {
  DateTime? today,
}) async {
  final allLogs = await (db.select(db.logs)
        ..where((l) => l.trackerId.equals(tracker.id))
        ..where((l) => l.isFreeze.isNotValue(true))
        ..orderBy([(l) => OrderingTerm.desc(l.logDate)]))
      .get();
  final dates = allLogs.map((log) => log.logDate).toSet();

  var streak = 0;
  var cursor = today ?? DateTime.now();
  while (dates.contains(_dateKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  final longest = tracker.habitLongestStreak ?? 0;
  await (db.update(db.trackers)..where((t) => t.id.equals(tracker.id))).write(
    TrackersCompanion(
      habitStreak: Value(streak),
      habitLongestStreak: Value(streak > longest ? streak : longest),
      modifiedAt: Value(DateTime.now()),
    ),
  );
  return streak;
}

Future<double> recomputeGoalTotal(AppDatabase db, Tracker tracker) async {
  final allLogs = await (db.select(db.logs)
        ..where((l) => l.trackerId.equals(tracker.id)))
      .get();
  final total = allLogs.fold<double>(0, (sum, log) => sum + (log.value ?? 0));
  await (db.update(db.trackers)..where((t) => t.id.equals(tracker.id))).write(
    TrackersCompanion(
      goalRunningTotal: Value(total),
      modifiedAt: Value(DateTime.now()),
    ),
  );
  return total;
}

Future<void> recomputeTrackerDenormalized(
  AppDatabase db,
  Tracker tracker,
) async {
  if (tracker.type == 'habit') {
    await recomputeHabitStreak(db, tracker);
  } else {
    await recomputeGoalTotal(db, tracker);
  }
}

String _dateKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
