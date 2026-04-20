import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../db/database.dart';

final trackersProvider = StreamProvider<List<Tracker>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.trackers)
        ..where((t) => t.archived.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();
});

final todayLogsProvider = StreamProvider<Map<int, List<Log>>>((ref) {
  final db = ref.watch(dbProvider);
  final today = todayDate();
  return (db.select(db.logs)..where((l) => l.logDate.equals(today)))
      .watch()
      .map((logs) {
    final map = <int, List<Log>>{};
    for (final log in logs) {
      map.putIfAbsent(log.trackerId, () => []).add(log);
    }
    return map;
  });
});

final habitLogDatesByTrackerProvider =
    StreamProvider.family<Set<String>, int>((ref, trackerId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.logs)
        ..where((l) => l.trackerId.equals(trackerId))
        ..where((l) => l.isFreeze.isNotValue(true)))
      .watch()
      .map((logs) => logs.map((log) => log.logDate).toSet());
});

String todayDate() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}
