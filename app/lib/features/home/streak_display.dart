// Design docs:
// - docs/design/data-model.md
// - docs/design/screens.md

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
  String? period,
}) {
  final unit = _periodUnit(period);
  final prevLabel = _prevPeriodLabel(period);
  final donePeriod = _donePeriod(doneToday, logDates, today, period);

  if (cachedStreak != null && cachedStreak > 0) {
    return HabitStreakDisplay(
      value: cachedStreak,
      suffix: donePeriod
          ? '$unit streak'
          : _pluralSuffix(cachedStreak, unit, prevLabel),
    );
  }

  if (donePeriod) {
    final current = _streakEndingThisPeriod(logDates, today, period);
    return HabitStreakDisplay(value: current, suffix: '$unit streak');
  }

  final prev = _streakEndingPrevPeriod(logDates, today, period);
  if (prev > 0) {
    return HabitStreakDisplay(
      value: prev,
      suffix: _pluralSuffix(prev, unit, prevLabel),
    );
  }

  return HabitStreakDisplay(value: 0, suffix: '$unit streak');
}

bool _donePeriod(
    bool doneToday, Set<String> logDates, DateTime today, String? period) {
  if (period == 'weekly') {
    final thisWeekKey = _weekKey(_mondayOf(today));
    return logDates
        .any((d) => _weekKey(_mondayOf(_parseDate(d))) == thisWeekKey);
  }
  if (period == 'monthly') {
    final thisMonthKey = _monthKey(today);
    return logDates.any((d) => _monthKey(_parseDate(d)) == thisMonthKey);
  }
  return doneToday;
}

int _streakEndingThisPeriod(
    Set<String> logDates, DateTime today, String? period) {
  if (period == 'weekly') {
    return _weeklyStreakEndingOn(_mondayOf(today), logDates);
  }
  if (period == 'monthly') {
    return _monthlyStreakEndingOn(DateTime(today.year, today.month), logDates);
  }
  return _dailyStreakEndingOn(today, logDates);
}

int _streakEndingPrevPeriod(
    Set<String> logDates, DateTime today, String? period) {
  if (period == 'weekly') {
    return _weeklyStreakEndingOn(
        _mondayOf(today).subtract(const Duration(days: 7)), logDates);
  }
  if (period == 'monthly') {
    return _monthlyStreakEndingOn(
        _prevMonth(DateTime(today.year, today.month)), logDates);
  }
  return _dailyStreakEndingOn(
      today.subtract(const Duration(days: 1)), logDates);
}

int _dailyStreakEndingOn(DateTime day, Set<String> logDates) {
  var streak = 0;
  var cursor = day;
  while (logDates.contains(dateKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

int _weeklyStreakEndingOn(DateTime monday, Set<String> logDates) {
  final weekKeys =
      logDates.map((d) => _weekKey(_mondayOf(_parseDate(d)))).toSet();
  var streak = 0;
  var cursor = monday;
  while (weekKeys.contains(_weekKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 7));
  }
  return streak;
}

int _monthlyStreakEndingOn(DateTime month, Set<String> logDates) {
  final monthKeys = logDates.map((d) => _monthKey(_parseDate(d))).toSet();
  var streak = 0;
  var cursor = month;
  while (monthKeys.contains(_monthKey(cursor))) {
    streak++;
    cursor = _prevMonth(cursor);
  }
  return streak;
}

String _periodUnit(String? period) {
  if (period == 'weekly') return 'week';
  if (period == 'monthly') return 'month';
  return 'day';
}

String _prevPeriodLabel(String? period) {
  if (period == 'weekly') return 'last week';
  if (period == 'monthly') return 'last month';
  return 'yesterday';
}

String _pluralSuffix(int count, String unit, String prevLabel) {
  final pluralUnit = count == 1 ? unit : '${unit}s';
  return '$pluralUnit $prevLabel';
}

String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _weekKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _monthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

DateTime _mondayOf(DateTime date) =>
    date.subtract(Duration(days: date.weekday - 1));

DateTime _prevMonth(DateTime date) => date.month == 1
    ? DateTime(date.year - 1, 12)
    : DateTime(date.year, date.month - 1);

DateTime _parseDate(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}
