bool isMilestoneNumber(int streak) {
  if (streak < 10) return false;

  // 10, 20, 30...
  if (streak % 10 == 0) return true;

  if (streak < 100) return false;

  // 100, 200, 300...
  if (streak % 100 == 0) return true;

  // all the same digit: 111, 222, 333, 666, 999, etc.
  if (streak.toString().split('').toSet().length == 1) return true;

  // every year
  if (streak % 365 == 0) return true;

  return false;
}

/// Returns the label of the highest milestone crossed when moving from
/// [oldTotal] to [newTotal] toward [target], or null if none was crossed.
String? goalMilestoneCrossed(double oldTotal, double newTotal, double target) {
  const milestones = [1.0, 0.75, 0.5, 0.25];
  for (final m in milestones) {
    final milestoneValue = target * m;
    if (oldTotal < milestoneValue && milestoneValue <= newTotal) {
      return '${(m * 100).toInt()}%';
    }
  }
  return null;
}
