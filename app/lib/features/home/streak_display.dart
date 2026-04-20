class HabitStreakDisplay {
  final int value;
  final String suffix;

  const HabitStreakDisplay({required this.value, required this.suffix});

  String get label => '$value $suffix';
}

HabitStreakDisplay habitStreakDisplay({
  required bool doneToday,
  required Set<String> logDates,
  required DateTime today,
  int? cachedStreak,
}) {
  if (cachedStreak != null && cachedStreak > 0) {
    return HabitStreakDisplay(
      value: cachedStreak,
      suffix: doneToday ? 'day streak' : _daysSuffix(cachedStreak, 'yesterday'),
    );
  }

  if (doneToday) {
    final currentStreak = _consecutiveLoggedDaysEndingOn(today, logDates);
    return HabitStreakDisplay(
      value: currentStreak,
      suffix: 'day streak',
    );
  }

  final yesterday = today.subtract(const Duration(days: 1));
  final yesterdayStreak = _consecutiveLoggedDaysEndingOn(yesterday, logDates);
  if (yesterdayStreak > 0) {
    return HabitStreakDisplay(
      value: yesterdayStreak,
      suffix: _daysSuffix(yesterdayStreak, 'yesterday'),
    );
  }

  return const HabitStreakDisplay(value: 0, suffix: 'day streak');
}

int _consecutiveLoggedDaysEndingOn(DateTime day, Set<String> logDates) {
  var streak = 0;
  var cursor = day;
  while (logDates.contains(dateKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

String _daysSuffix(int value, String trailingText) {
  final unit = value == 1 ? 'day' : 'days';
  return '$unit $trailingText';
}

String dateKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
