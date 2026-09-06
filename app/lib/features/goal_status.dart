// Whether a goal is still running, was reached, or ran out of time.
// Design docs:
// - docs/design/data-model.md
// - docs/design/goals.md

import '../db/database.dart';

enum GoalStatus {
  /// Still running: the target has not been reached and the deadline, if any,
  /// has not passed.
  active,

  /// The running total reached the target amount.
  completed,

  /// The target date passed without the target being reached.
  outOfTime,
}

/// Where [tracker] stands as of [now].
///
/// A goal with neither a target amount nor a target date is open-ended and is
/// always [GoalStatus.active] — there is nothing to reach and nothing to miss.
/// Reaching the target wins over a passed deadline: a goal finished late is
/// still finished.
GoalStatus goalStatus(Tracker tracker, {required DateTime now}) {
  if (tracker.type != 'goal') return GoalStatus.active;

  final target = tracker.goalTargetAmount;
  if (target != null &&
      target > 0 &&
      (tracker.goalRunningTotal ?? 0) >= target) {
    return GoalStatus.completed;
  }

  final deadline = tracker.goalTargetDate;
  if (deadline != null && !now.isBefore(_dayAfter(deadline))) {
    return GoalStatus.outOfTime;
  }
  return GoalStatus.active;
}

/// Short label for a finished goal; null while it is still running.
String? goalStatusLabel(GoalStatus status) => switch (status) {
      GoalStatus.completed => 'Goal reached',
      GoalStatus.outOfTime => 'Out of time',
      GoalStatus.active => null,
    };

/// The target date counts in full, so a goal only runs out of time once the
/// day after it has begun. Built from the date parts rather than by adding a
/// Duration, which would land an hour off across a daylight saving change.
DateTime _dayAfter(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);
