// Design docs:
// - docs/design/data-model.md
// - docs/design/tech-stack.md

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tables.dart';

part 'database.g.dart';

const dbFileName = 'didit';

@DriftDatabase(tables: [Trackers, Logs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(trackers, trackers.emoji);
          }
          if (from < 3) {
            await m.addColumn(
                trackers, trackers.goalStartDate as GeneratedColumn<Object>);
          }
          if (from < 4) {
            // Deleting a tracker used to leave its logs behind. Those rows are
            // unreachable from every screen, but a tracker created later can be
            // handed the same id after an import and inherit them — which is
            // how a brand-new goal ends up showing months-old logs.
            await deleteOrphanLogs();
          }
        },
        // Enforce logs.trackerId → trackers.id from here on, so no code path
        // can orphan a log again. Off by default in SQLite, and it must stay
        // off while migrations run.
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Removes logs whose tracker no longer exists. Runs once on upgrade to
  /// schema 4; nothing should be able to create such a row afterwards.
  Future<void> deleteOrphanLogs() async {
    await customStatement(
        'DELETE FROM logs WHERE tracker_id NOT IN (SELECT id FROM trackers)');
  }

  /// Takes a tracker off the home screen, or puts it back. Logs are left
  /// alone — that is the whole point of archiving instead of deleting.
  Future<void> setTrackerArchived(int trackerId, bool archived) async {
    await (update(trackers)..where((t) => t.id.equals(trackerId))).write(
      TrackersCompanion(
        archived: Value(archived),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Deletes a tracker and the logs belonging to it, as one transaction.
  Future<void> deleteTrackerWithLogs(int trackerId) async {
    await transaction(() async {
      await (delete(logs)..where((l) => l.trackerId.equals(trackerId))).go();
      await (delete(trackers)..where((t) => t.id.equals(trackerId))).go();
    });
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: dbFileName,
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  Future<Map<String, dynamic>> exportData() async {
    final allTrackers = await select(trackers).get();
    final allLogs = await select(logs).get();
    return {
      'version': 1,
      'exportedAt': DateTime.now().millisecondsSinceEpoch,
      'trackers': allTrackers.map((t) => t.toJson()).toList(),
      'logs': allLogs.map((l) => l.toJson()).toList(),
    };
  }

  Future<void> swapTrackerOrder(Tracker a, Tracker b) async {
    await transaction(() async {
      await (update(trackers)..where((t) => t.id.equals(a.id)))
          .write(TrackersCompanion(sortOrder: Value(b.sortOrder)));
      await (update(trackers)..where((t) => t.id.equals(b.id)))
          .write(TrackersCompanion(sortOrder: Value(a.sortOrder)));
    });
  }

  /// Replaces everything with [data].
  ///
  /// Logs whose tracker is missing from the backup are dropped rather than
  /// restored: importing re-seeds the tracker id sequence from the ids it
  /// inserts, so a log pointing past the highest imported tracker would be
  /// silently adopted by the next tracker the user creates.
  Future<void> importData(Map<String, dynamic> data) async {
    await transaction(() async {
      await delete(logs).go();
      await delete(trackers).go();

      final trackerIds = <int>{};
      for (final t in (data['trackers'] as List)) {
        final tracker = Tracker.fromJson(t as Map<String, dynamic>);
        await into(trackers).insert(tracker.toCompanion(true));
        trackerIds.add(tracker.id);
      }

      for (final l in (data['logs'] as List)) {
        final log = Log.fromJson(l as Map<String, dynamic>);
        if (!trackerIds.contains(log.trackerId)) continue;
        await into(logs).insert(log.toCompanion(true));
      }
    });
  }
}

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
