import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Trackers, Logs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

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
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'didit',
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

  Future<void> importData(Map<String, dynamic> data) async {
    await transaction(() async {
      await delete(logs).go();
      await delete(trackers).go();

      for (final t in (data['trackers'] as List)) {
        final tracker = Tracker.fromJson(t as Map<String, dynamic>);
        await into(trackers).insert(tracker.toCompanion(true));
      }

      for (final l in (data['logs'] as List)) {
        final log = Log.fromJson(l as Map<String, dynamic>);
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
