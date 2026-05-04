// Design doc: docs/design/screens.md § "Tap & Long-Press Behavior"

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import '../db/database.dart';
import 'tracker_denormalized.dart';

/// What a single tap on a habit entry should do.
/// Resolved by [resolveHabitTapIntent] — pure function, no Flutter dependency.
///
/// The first group executes directly against the DB with no UI.
/// The second group requires showing a dialog first.
enum HabitTapIntent {
  // Direct DB actions — no dialog needed.

  /// Binary habit, unlogged: insert a valueless log.
  insertBinary,

  /// Binary habit, logged: delete the log (toggle off).
  deleteBinary,

  /// Toggle habit (≤[habitValueOptionsCycleMax] options), not at end of cycle:
  /// advance to the next value inline.
  cycleNext,

  // Dialog-gated actions.

  /// Periodic habit, logged — Toggle at end of cycle or any Pick state:
  /// open a value picker with a Delete option.
  showUpdatePicker,

  /// Unlogged habit with value options: open a value picker to create a new log.
  showInsertPicker,

  /// Anytime habit, already logged: ask whether to add a new entry or update
  /// the most recent one.
  showAnytimeChoice,
}

/// Pure decision function: maps tracker state → [HabitTapIntent].
/// No Flutter, no DB — safe to unit-test directly.
HabitTapIntent resolveHabitTapIntent({
  required bool isAllowMultiple,
  required List<String> valueOptions,
  required Log? existing,
}) {
  final isLogged = existing != null;
  final isToggle =
      valueOptions.isNotEmpty && valueOptions.length <= habitValueOptionsCycleMax;

  if (isAllowMultiple) {
    if (isLogged) return HabitTapIntent.showAnytimeChoice;
    return valueOptions.isEmpty
        ? HabitTapIntent.insertBinary
        : HabitTapIntent.showInsertPicker;
  }

  if (valueOptions.isEmpty) {
    return isLogged ? HabitTapIntent.deleteBinary : HabitTapIntent.insertBinary;
  }

  if (isToggle) {
    if (isLogged) {
      final atEnd = (existing.value ?? -1).toInt() + 1 >= valueOptions.length;
      return atEnd ? HabitTapIntent.showUpdatePicker : HabitTapIntent.cycleNext;
    }
    return HabitTapIntent.cycleNext;
  }

  return isLogged ? HabitTapIntent.showUpdatePicker : HabitTapIntent.showInsertPicker;
}

/// Shared handler used by both the home screen card and the calendar day cell.
///
/// Returns the new streak when a new log was created — the home screen uses
/// this to trigger the celebration animation.  Returns null for updates,
/// deletes, and dismissed dialogs (all of which skip celebration).
Future<int?> handleHabitDayTap({
  required BuildContext context,
  required AppDatabase db,
  required Tracker tracker,
  required Log? existing,
  required String dateStr,
}) async {
  final valueOptions = tracker.habitValueOptions != null
      ? (jsonDecode(tracker.habitValueOptions!) as List).cast<String>()
      : <String>[];
  final intent = resolveHabitTapIntent(
    isAllowMultiple: tracker.habitAllowMultiple == true,
    valueOptions: valueOptions,
    existing: existing,
  );

  switch (intent) {
    case HabitTapIntent.deleteBinary:
      if (existing == null) return null;
      await (db.delete(db.logs)..where((l) => l.id.equals(existing.id))).go();
      await recomputeHabitStreak(db, tracker);
      return null;

    case HabitTapIntent.insertBinary:
      await _insertLog(db, tracker, dateStr);
      return recomputeHabitStreak(db, tracker);

    case HabitTapIntent.cycleNext:
      await cycleHabitValueOption(db, tracker, dateStr, existing, valueOptions);
      return recomputeHabitStreak(db, tracker);

    case HabitTapIntent.showInsertPicker:
      if (!context.mounted) return null;
      return _pickValueAndInsert(context, db, tracker, valueOptions, dateStr);

    case HabitTapIntent.showUpdatePicker:
      if (existing == null || !context.mounted) return null;
      await _showEditOrDeleteDialog(context, db, tracker, valueOptions, existing);
      return null;

    case HabitTapIntent.showAnytimeChoice:
      if (existing == null || !context.mounted) return null;
      final choice = await _showAddOrUpdateDialog(context, tracker.name);
      if (choice == _AnytimeChoice.add) {
        if (valueOptions.isEmpty) {
          await _insertLog(db, tracker, dateStr);
          return recomputeHabitStreak(db, tracker);
        }
        if (!context.mounted) return null;
        return _pickValueAndInsert(context, db, tracker, valueOptions, dateStr);
      }
      if (choice == _AnytimeChoice.update) {
        if (!context.mounted) return null;
        await _showEditOrDeleteDialog(context, db, tracker, valueOptions, existing);
      }
      return null;
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

Future<void> _insertLog(
  AppDatabase db,
  Tracker tracker,
  String dateStr, {
  double? value,
}) async {
  final ts = DateTime.now();
  await db.into(db.logs).insert(LogsCompanion.insert(
        trackerId: tracker.id,
        logDate: dateStr,
        createdAt: ts,
        modifiedAt: ts,
        value: value == null ? const Value.absent() : Value(value),
      ));
}

Future<int?> _pickValueAndInsert(
  BuildContext context,
  AppDatabase db,
  Tracker tracker,
  List<String> options,
  String dateStr,
) async {
  final picked = await _showValuePickerDialog(context, tracker.name, options);
  if (picked == null) return null;
  await _insertLog(db, tracker, dateStr, value: picked.toDouble());
  return recomputeHabitStreak(db, tracker);
}

Future<int?> _showValuePickerDialog(
    BuildContext context, String trackerName, List<String> options) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text('Log $trackerName'),
      children: options
          .asMap()
          .entries
          .map((e) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, e.key),
                child: Text(e.value),
              ))
          .toList(),
    ),
  );
}

Future<void> _showEditOrDeleteDialog(
  BuildContext context,
  AppDatabase db,
  Tracker tracker,
  List<String> options,
  Log existing,
) async {
  const deleteKey = -1;
  final picked = await showDialog<int>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text('Update ${tracker.name}'),
      children: [
        ...options.asMap().entries.map((e) => SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e.key),
              child: Text(e.value),
            )),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, deleteKey),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (picked == null) return;
  if (picked == deleteKey) {
    await (db.delete(db.logs)..where((l) => l.id.equals(existing.id))).go();
  } else {
    await (db.update(db.logs)..where((l) => l.id.equals(existing.id))).write(
      LogsCompanion(
        value: Value(picked.toDouble()),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }
  await recomputeHabitStreak(db, tracker);
}

enum _AnytimeChoice { add, update }

Future<_AnytimeChoice?> _showAddOrUpdateDialog(
    BuildContext context, String trackerName) {
  return showDialog<_AnytimeChoice>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text('Log $trackerName'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, _AnytimeChoice.add),
          child: const Text('Add new entry'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, _AnytimeChoice.update),
          child: const Text('Update recent entry'),
        ),
      ],
    ),
  );
}
