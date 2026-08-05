DateTime startOfDay(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime endOfYearFor(DateTime date) {
  return DateTime(date.year, 12, 31);
}

double targetForDailyGoalThroughEndOfYear({
  required DateTime today,
  required int dailyAmount,
}) {
  final startDate = startOfDay(today);
  final targetDate = endOfYearFor(today);
  final inclusiveDays = targetDate.difference(startDate).inDays + 1;

  return (inclusiveDays * dailyAmount).toDouble();
}
