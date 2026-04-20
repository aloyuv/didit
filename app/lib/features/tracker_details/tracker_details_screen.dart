import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../db/database.dart';
import '../../router.dart';

final _trackerByIdProvider = StreamProvider.family<Tracker?, int>((ref, id) {
  final db = ref.watch(dbProvider);
  return (db.select(db.trackers)..where((t) => t.id.equals(id)))
      .watchSingleOrNull();
});

final _logsByTrackerProvider =
    StreamProvider.family<List<Log>, int>((ref, trackerId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.logs)
        ..where((l) => l.trackerId.equals(trackerId))
        ..orderBy([
          (l) => OrderingTerm.desc(l.logDate),
          (l) => OrderingTerm.desc(l.createdAt),
        ]))
      .watch();
});

class TrackerDetailsScreen extends ConsumerWidget {
  final int trackerId;
  const TrackerDetailsScreen({super.key, required this.trackerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackerAsync = ref.watch(_trackerByIdProvider(trackerId));
    final logsAsync = ref.watch(_logsByTrackerProvider(trackerId));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: trackerAsync.maybeWhen(
          data: (t) => Text(t?.name ?? ''),
          orElse: () => const SizedBox.shrink(),
        ),
      ),
      body: trackerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tracker) {
          if (tracker == null) {
            return const Center(child: Text('Tracker not found'));
          }
          return logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (logs) => _DetailsBody(tracker: tracker, logs: logs),
          );
        },
      ),
    );
  }
}

class _DetailsBody extends ConsumerWidget {
  final Tracker tracker;
  final List<Log> logs;

  const _DetailsBody({required this.tracker, required this.logs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _StatsCard(tracker: tracker, logs: logs)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (tracker.type == 'habit') {
                        context.navigate('/habit-edit/${tracker.id}');
                      } else {
                        context.navigate('/goal-edit/${tracker.id}');
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit tracker'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.navigate('/mass-edit/${tracker.id}'),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Mass edit'),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _MonthCalendar(tracker: tracker, logs: logs),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Log History', style: theme.textTheme.titleMedium),
          ),
        ),
        logs.isEmpty
            ? const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No logs yet')),
                ),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _LogTile(log: logs[i], tracker: tracker),
                  childCount: logs.length,
                ),
              ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  final Tracker tracker;
  final List<Log> logs;

  const _StatsCard({required this.tracker, required this.logs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    List<_StatItem> stats;
    if (tracker.type == 'habit') {
      final streak = tracker.habitStreak ?? 0;
      final longest = tracker.habitLongestStreak ?? 0;
      stats = [
        (label: 'Current streak', value: '$streak days'),
        (label: 'Longest streak', value: '$longest days'),
        (label: 'Total logged', value: '${logs.length}×'),
      ];
    } else {
      final total = tracker.goalRunningTotal ?? 0;
      final unit = tracker.goalUnit ?? '';
      final target = tracker.goalTargetAmount;
      stats = [
        (label: 'Total', value: '${_fmt(total)} $unit'.trim()),
        if (target != null)
          (
            label: 'Progress',
            value:
                '${((total / target) * 100).clamp(0, 100).toStringAsFixed(0)}%',
          ),
        if (target != null)
          (label: 'Target', value: '${_fmt(target)} $unit'.trim()),
        (label: 'Entries', value: '${logs.length}'),
      ];
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: stats
            .map((s) => Expanded(
                  child: Card(
                    color: cs.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      child: Column(
                        children: [
                          Text(
                            s.value,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.truncate() ? v.toInt().toString() : v.toStringAsFixed(1);
}

typedef _StatItem = ({String label, String value});

class _MonthCalendar extends ConsumerStatefulWidget {
  final Tracker tracker;
  final List<Log> logs;

  const _MonthCalendar({required this.tracker, required this.logs});

  @override
  ConsumerState<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends ConsumerState<_MonthCalendar> {
  late DateTime _displayMonth;

  static const _weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month);
  }

  // First log per date (logs are ordered desc by logDate/createdAt from provider)
  Map<String, Log> get _logsByDate {
    final map = <String, Log>{};
    for (final l in widget.logs.reversed) {
      map[l.logDate] = l;
    }
    return map;
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtNum(double v) =>
      v == v.truncate() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _handleDayTap(String dateStr) async {
    final now = DateTime.now();
    if (dateStr.compareTo(_dateStr(now)) > 0) return; // no future logging

    final db = ref.read(dbProvider);
    final existing = _logsByDate[dateStr];
    final tracker = widget.tracker;

    if (tracker.type == 'habit') {
      final valueOptions = tracker.habitValueOptions != null
          ? (jsonDecode(tracker.habitValueOptions!) as List).cast<String>()
          : <String>[];

      if (valueOptions.isEmpty) {
        // Binary: toggle
        if (existing != null) {
          await (db.delete(db.logs)..where((l) => l.id.equals(existing.id))).go();
        } else {
          final ts = DateTime.now();
          await db.into(db.logs).insert(LogsCompanion.insert(
                trackerId: tracker.id,
                logDate: dateStr,
                createdAt: ts,
                modifiedAt: ts,
              ));
        }
      } else {
        // Cycle: none → 0 → 1 → … → last → none
        if (existing == null) {
          final ts = DateTime.now();
          await db.into(db.logs).insert(LogsCompanion.insert(
                trackerId: tracker.id,
                logDate: dateStr,
                createdAt: ts,
                modifiedAt: ts,
                value: const Value(0),
              ));
        } else {
          final nextIdx = (existing.value ?? -1).toInt() + 1;
          if (nextIdx >= valueOptions.length) {
            await (db.delete(db.logs)..where((l) => l.id.equals(existing.id))).go();
          } else {
            await (db.update(db.logs)..where((l) => l.id.equals(existing.id)))
                .write(LogsCompanion(
              value: Value(nextIdx.toDouble()),
              modifiedAt: Value(DateTime.now()),
            ));
          }
        }
      }
      await _updateHabitStreak(db, tracker);
    } else {
      if (!mounted) return;
      await _showGoalDialog(dateStr, existing);
    }
  }

  Future<void> _showGoalDialog(String dateStr, Log? existing) async {
    final tracker = widget.tracker;
    final ctrl = TextEditingController(
      text: existing?.value != null ? _fmtNum(existing!.value!) : '',
    );
    final db = ref.read(dbProvider);

    // sentinel: null = cancel, -double.infinity = delete, other = save
    final result = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(dateStr),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: tracker.goalUnit ?? 'Amount',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            final parsed = double.tryParse(v.trim());
            if (parsed != null) Navigator.pop(context, parsed);
          },
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.pop(context, double.negativeInfinity),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              if (v != null) Navigator.pop(context, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;
    if (result == double.negativeInfinity) {
      if (existing != null) {
        await (db.delete(db.logs)..where((l) => l.id.equals(existing.id))).go();
      }
    } else if (existing != null) {
      await (db.update(db.logs)..where((l) => l.id.equals(existing.id))).write(
        LogsCompanion(
          value: Value(result),
          modifiedAt: Value(DateTime.now()),
        ),
      );
    } else {
      final ts = DateTime.now();
      await db.into(db.logs).insert(LogsCompanion.insert(
            trackerId: tracker.id,
            logDate: dateStr,
            createdAt: ts,
            modifiedAt: ts,
            value: Value(result),
          ));
    }
    await _updateGoalTotal(db, tracker);
  }

  Future<void> _updateHabitStreak(AppDatabase db, Tracker tracker) async {
    final allLogs = await (db.select(db.logs)
          ..where((l) => l.trackerId.equals(tracker.id))
          ..where((l) => l.isFreeze.isNotValue(true))
          ..orderBy([(l) => OrderingTerm.desc(l.logDate)]))
        .get();
    final dates = allLogs.map((l) => l.logDate).toSet();
    int streak = 0;
    var cursor = DateTime.now();
    while (true) {
      final key = _dateStr(cursor);
      if (dates.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    final longest = tracker.habitLongestStreak ?? 0;
    await (db.update(db.trackers)..where((t) => t.id.equals(tracker.id))).write(
      TrackersCompanion(
        habitStreak: Value(streak),
        habitLongestStreak: Value(streak > longest ? streak : longest),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _updateGoalTotal(AppDatabase db, Tracker tracker) async {
    final allLogs = await (db.select(db.logs)
          ..where((l) => l.trackerId.equals(tracker.id)))
        .get();
    final total = allLogs.fold<double>(0, (s, l) => s + (l.value ?? 0));
    await (db.update(db.trackers)..where((t) => t.id.equals(tracker.id))).write(
      TrackersCompanion(
        goalRunningTotal: Value(total),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();
    final todayStr = _dateStr(now);
    final logsByDate = _logsByDate;

    final valueOptions = widget.tracker.habitValueOptions != null
        ? (jsonDecode(widget.tracker.habitValueOptions!) as List).cast<String>()
        : <String>[];

    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final startOffset = firstDay.weekday % 7; // Mon=1…Sun=7 → Sun=0…Sat=6
    final daysInMonth =
        DateUtils.getDaysInMonth(_displayMonth.year, _displayMonth.month);

    final canGoForward = _displayMonth.year < now.year ||
        (_displayMonth.year == now.year && _displayMonth.month < now.month);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() {
                    _displayMonth =
                        DateTime(_displayMonth.year, _displayMonth.month - 1);
                  }),
                ),
                Text(
                  '${_monthNames[_displayMonth.month - 1]} ${_displayMonth.year}',
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: canGoForward
                      ? () => setState(() {
                            _displayMonth = DateTime(
                                _displayMonth.year, _displayMonth.month + 1);
                          })
                      : null,
                ),
              ],
            ),
            Row(
              children: _weekdays
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: startOffset + daysInMonth,
              itemBuilder: (ctx, index) {
                if (index < startOffset) return const SizedBox.shrink();
                final day = index - startOffset + 1;
                final dateStr =
                    '${_displayMonth.year}-${_displayMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                final log = logsByDate[dateStr];
                final isLogged = log != null;
                final isToday = dateStr == todayStr;
                final isFuture = DateTime(_displayMonth.year,
                        _displayMonth.month, day)
                    .isAfter(now);

                // Label inside circle for value-options habits
                String? valueLabel;
                if (isLogged && valueOptions.isNotEmpty && log.value != null) {
                  final idx = log.value!.toInt();
                  if (idx >= 0 && idx < valueOptions.length) {
                    valueLabel = valueOptions[idx];
                  }
                }

                return _CalendarDay(
                  day: day,
                  isLogged: isLogged,
                  isToday: isToday,
                  isFuture: isFuture,
                  valueLabel: valueLabel,
                  onTap: isFuture ? null : () => _handleDayTap(dateStr),
                );
              },
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: cs.primary),
                const SizedBox(width: 4),
                Text('Logged', style: theme.textTheme.labelSmall),
                const SizedBox(width: 16),
                _LegendDot(color: cs.primaryContainer, border: cs.primary),
                const SizedBox(width: 4),
                Text('Today', style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final int day;
  final bool isLogged;
  final bool isToday;
  final bool isFuture;
  final String? valueLabel;
  final VoidCallback? onTap;

  const _CalendarDay({
    required this.day,
    required this.isLogged,
    required this.isToday,
    required this.isFuture,
    this.valueLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color? bgColor;
    Color? borderColor;
    Color textColor;

    if (isLogged) {
      bgColor = cs.primary;
      textColor = cs.onPrimary;
    } else if (isToday) {
      bgColor = cs.primaryContainer;
      borderColor = cs.primary;
      textColor = cs.onPrimaryContainer;
    } else if (isFuture) {
      textColor = cs.onSurface.withValues(alpha: 0.25);
    } else {
      bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.5);
      textColor = cs.onSurface;
    }

    final radius = BorderRadius.circular(8);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: radius,
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1.5)
                : null,
          ),
          child: Center(
            child: valueLabel != null
                ? Tooltip(
                    message: valueLabel!,
                    child: Text(
                      valueLabel![0].toUpperCase(),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : Text(
                    '$day',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: isToday || isLogged ? FontWeight.bold : null,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final Color? border;
  const _LegendDot({required this.color, this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: border != null ? Border.all(color: border!, width: 1) : null,
      ),
    );
  }
}

class _LogTile extends ConsumerWidget {
  final Log log;
  final Tracker tracker;

  const _LogTile({required this.log, required this.tracker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final dayNum = log.logDate.substring(8);
    final subtitle = _buildSubtitle();

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            dayNum,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
      ),
      title: Text(log.logDate, style: theme.textTheme.bodyMedium),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        iconSize: 20,
        color: cs.error,
        tooltip: 'Delete log',
        onPressed: () => _confirmDelete(context, ref),
      ),
    );
  }

  String? _buildSubtitle() {
    final parts = <String>[];
    if (log.isFreeze == true) {
      parts.add('❄️ Freeze');
    } else if (log.value != null) {
      final v = log.value!;
      final vStr = v == v.truncate() ? v.toInt().toString() : v.toStringAsFixed(1);
      if (tracker.type == 'goal' && tracker.goalUnit != null) {
        parts.add('$vStr ${tracker.goalUnit}');
      } else if (tracker.habitValueOptions != null) {
        final label = _habitValueLabel(v);
        parts.add(label ?? vStr);
      } else {
        parts.add(vStr);
      }
    }
    if (log.note != null && log.note!.isNotEmpty) parts.add(log.note!);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? _habitValueLabel(double value) {
    try {
      final options =
          (jsonDecode(tracker.habitValueOptions!) as List).cast<String>();
      final idx = value.toInt();
      if (idx >= 0 && idx < options.length) return options[idx];
    } catch (_) {}
    return null;
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete log?'),
        content: Text('Remove the log entry for ${log.logDate}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final db = ref.read(dbProvider);
      await (db.delete(db.logs)..where((l) => l.id.equals(log.id))).go();
      if (tracker.type == 'habit') {
        await _updateHabitStreak(db);
      } else {
        await _updateGoalTotal(db);
      }
    }
  }

  Future<void> _updateHabitStreak(AppDatabase db) async {
    final allLogs = await (db.select(db.logs)
          ..where((l) => l.trackerId.equals(tracker.id))
          ..where((l) => l.isFreeze.isNotValue(true))
          ..orderBy([(l) => OrderingTerm.desc(l.logDate)]))
        .get();
    final dates = allLogs.map((l) => l.logDate).toSet();
    int streak = 0;
    var cursor = DateTime.now();
    while (true) {
      final key =
          '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      if (dates.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    final longest = tracker.habitLongestStreak ?? 0;
    await (db.update(db.trackers)..where((t) => t.id.equals(tracker.id))).write(
      TrackersCompanion(
        habitStreak: Value(streak),
        habitLongestStreak: Value(streak > longest ? streak : longest),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _updateGoalTotal(AppDatabase db) async {
    final allLogs = await (db.select(db.logs)
          ..where((l) => l.trackerId.equals(tracker.id)))
        .get();
    final total = allLogs.fold<double>(0, (sum, l) => sum + (l.value ?? 0));
    await (db.update(db.trackers)..where((t) => t.id.equals(tracker.id))).write(
      TrackersCompanion(
        goalRunningTotal: Value(total),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }
}
