import 'package:drift/drift.dart';

import '../db/database.dart';

/// Trackers with this many or fewer value options use tap-to-cycle; more use a dialog.
const int habitValueOptionsCycleMax = 3;

/// Cycles a habit log's value through [options] for [dateStr].
/// Inserts at index 0 if no log exists; updates to next index; deletes when
/// the last option is passed (cycling back to none).
/// Returns the new value index, or null if the log was removed.
/// Caller is responsible for calling [recomputeHabitStreak] afterwards.
Future<int?> cycleHabitValueOption(
  AppDatabase db,
  Tracker tracker,
  String dateStr,
  Log? existing,
  List<String> options,
) async {
  if (existing == null) {
    final ts = DateTime.now();
    await db.into(db.logs).insert(LogsCompanion.insert(
          trackerId: tracker.id,
          logDate: dateStr,
          createdAt: ts,
          modifiedAt: ts,
          value: const Value(0),
        ));
    return 0;
  }
  final nextIdx = (existing.value ?? -1).toInt() + 1;
  if (nextIdx >= options.length) {
    await (db.delete(db.logs)..where((l) => l.id.equals(existing.id))).go();
    return null;
  }
  await (db.update(db.logs)..where((l) => l.id.equals(existing.id))).write(
    LogsCompanion(
      value: Value(nextIdx.toDouble()),
      modifiedAt: Value(DateTime.now()),
    ),
  );
  return nextIdx;
}

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
  final streak = calculateHabitStreak(
    logDates: allLogs.map((log) => log.logDate).toSet(),
    today: today ?? DateTime.now(),
    period: tracker.habitPeriod,
  );
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

int calculateHabitStreak({
  required Set<String> logDates,
  required DateTime today,
  String? period,
}) {
  if (period == 'weekly') return _weeklyHabitStreak(logDates, today);
  if (period == 'monthly') return _monthlyHabitStreak(logDates, today);
  return _dailyHabitStreak(logDates, today);
}

int _dailyHabitStreak(Set<String> logDates, DateTime today) {
  final anchor = logDates.contains(_dateKey(today))
      ? today
      : today.subtract(const Duration(days: 1));
  var streak = 0;
  var cursor = anchor;
  while (logDates.contains(_dateKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

int _weeklyHabitStreak(Set<String> logDates, DateTime today) {
  final weekKeys = logDates.map((d) => _weekKey(_mondayOf(_parseDate(d)))).toSet();
  final thisMonday = _mondayOf(today);
  final anchor = weekKeys.contains(_weekKey(thisMonday))
      ? thisMonday
      : thisMonday.subtract(const Duration(days: 7));
  var streak = 0;
  var cursor = anchor;
  while (weekKeys.contains(_weekKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 7));
  }
  return streak;
}

int _monthlyHabitStreak(Set<String> logDates, DateTime today) {
  final monthKeys = logDates.map((d) => _monthKey(_parseDate(d))).toSet();
  final thisMonth = DateTime(today.year, today.month);
  final anchor = monthKeys.contains(_monthKey(thisMonth))
      ? thisMonth
      : _prevMonth(thisMonth);
  var streak = 0;
  var cursor = anchor;
  while (monthKeys.contains(_monthKey(cursor))) {
    streak++;
    cursor = _prevMonth(cursor);
  }
  return streak;
}

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _weekKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _monthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

DateTime _mondayOf(DateTime date) =>
    date.subtract(Duration(days: date.weekday - 1));

DateTime _prevMonth(DateTime date) =>
    date.month == 1 ? DateTime(date.year - 1, 12) : DateTime(date.year, date.month - 1);

DateTime _parseDate(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}
