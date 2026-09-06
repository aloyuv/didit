// How often each value option was logged — "how many runs vs cycles",
// "how many 5-mood days".
// Design docs:
// - docs/design/data-model.md
// - docs/design/screens.md

import 'package:flutter/material.dart';
import '../../db/database.dart';

/// Shown for logs whose value is missing or outside the option list. A habit
/// that gained value options after it was already being logged has such logs,
/// and hiding them would make the breakdown disagree with the total.
const String unspecifiedValueLabel = 'No value';

/// [optionIndex] is null for the [unspecifiedValueLabel] row, which belongs to
/// no option — labels alone cannot identify an option, since two options may
/// carry the same text.
typedef ValueTally = ({String label, int count, int? optionIndex});

/// Counts [logs] per value option, in option order, dropping options that were
/// never logged. A trailing [unspecifiedValueLabel] row appears only when some
/// log carries no usable value.
List<ValueTally> tallyLogsByValue({
  required List<String> options,
  required List<Log> logs,
}) {
  final counts = List<int>.filled(options.length, 0);
  var unspecified = 0;

  for (final log in logs) {
    final idx = log.value?.toInt();
    if (idx != null && idx >= 0 && idx < options.length) {
      counts[idx]++;
    } else {
      unspecified++;
    }
  }

  return [
    for (var i = 0; i < options.length; i++)
      if (counts[i] > 0) (label: options[i], count: counts[i], optionIndex: i),
    if (unspecified > 0)
      (label: unspecifiedValueLabel, count: unspecified, optionIndex: null),
  ];
}

/// The shade a value option gets everywhere it is drawn: calendar days, log
/// tiles, and the bars below. Later options are more saturated, so a heatmap
/// of a rated habit reads low-to-high without a separate legend.
Color habitValueColor(ColorScheme cs, int index, int optionCount) {
  if (optionCount <= 1) return cs.primary;
  final t = index.clamp(0, optionCount - 1) / (optionCount - 1);
  return cs.primary.withValues(alpha: 0.4 + 0.6 * t);
}

/// The "Logged values" card on the tracker details screen.
class HabitValueBreakdown extends StatelessWidget {
  final List<String> options;
  final List<Log> logs;

  const HabitValueBreakdown({
    super.key,
    required this.options,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tallies = tallyLogsByValue(options: options, logs: logs);
    if (tallies.isEmpty) return const SizedBox.shrink();

    final total = tallies.fold<int>(0, (sum, t) => sum + t.count);
    final busiest =
        tallies.fold<int>(0, (max, t) => t.count > max ? t.count : max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Logged values', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final tally in tallies)
              _TallyRow(
                label: tally.label,
                count: tally.count,
                // Bars are scaled against the most-logged value so the
                // difference between the options is visible even when one
                // dominates.
                fraction: busiest == 0 ? 0 : tally.count / busiest,
                percent: total == 0 ? 0 : tally.count / total,
                color: tally.optionIndex == null
                    ? cs.outlineVariant
                    : habitValueColor(cs, tally.optionIndex!, options.length),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TallyRow extends StatelessWidget {
  final String label;
  final int count;
  final double fraction;
  final double percent;
  final Color color;

  const _TallyRow({
    required this.label,
    required this.count,
    required this.fraction,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Container(
                height: 10,
                color: cs.surfaceContainerHighest,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(color: color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${(percent * 100).round()}%',
              textAlign: TextAlign.right,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
