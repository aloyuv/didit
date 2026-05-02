// Design docs:
// - docs/design/goals.md
// - docs/design/screens.md

import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../db/database.dart';
import '../tracker_denormalized.dart';

class MassEditScreen extends ConsumerStatefulWidget {
  final int trackerId;
  const MassEditScreen({super.key, required this.trackerId});

  @override
  ConsumerState<MassEditScreen> createState() => _MassEditScreenState();
}

class _MassEditScreenState extends ConsumerState<MassEditScreen> {
  Tracker? _tracker;
  bool _loading = true;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  // null = clear logs; for habit binary = 0.0 means "logged"; for value options = index; for goal = numeric
  double? _value;
  bool _clearMode = false;

  List<String> get _valueOptions {
    final t = _tracker;
    if (t == null || t.habitValueOptions == null) return [];
    try {
      return (jsonDecode(t.habitValueOptions!) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  bool get _isGoal => _tracker?.type == 'goal';
  bool get _hasValueOptions => _valueOptions.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadTracker();
  }

  Future<void> _loadTracker() async {
    final db = ref.read(dbProvider);
    final tracker = await (db.select(db.trackers)
          ..where((t) => t.id.equals(widget.trackerId)))
        .getSingleOrNull();
    setState(() {
      _tracker = tracker;
      _loading = false;
      if (tracker != null && _hasValueOptions) {
        _value = 0;
      }
    });
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _save() async {
    final tracker = _tracker;
    if (tracker == null) return;

    final db = ref.read(dbProvider);
    final now = DateTime.now();

    var cursor = _startDate;
    while (!cursor.isAfter(_endDate)) {
      final dateStr = _dateStr(cursor);

      final existingQuery = db.select(db.logs)
        ..where((l) => l.trackerId.equals(tracker.id))
        ..where((l) => l.logDate.equals(dateStr));
      final existing = await existingQuery.get();

      if (_clearMode) {
        for (final log in existing) {
          await (db.delete(db.logs)..where((l) => l.id.equals(log.id))).go();
        }
      } else {
        if (existing.isEmpty) {
          await db.into(db.logs).insert(LogsCompanion.insert(
                trackerId: tracker.id,
                logDate: dateStr,
                createdAt: now,
                modifiedAt: now,
                value: _isGoal || _hasValueOptions
                    ? Value(_value ?? 0)
                    : const Value.absent(),
              ));
        } else {
          // Update the first log, delete extras
          await (db.update(db.logs)
                ..where((l) => l.id.equals(existing.first.id)))
              .write(LogsCompanion(
            value: _isGoal || _hasValueOptions
                ? Value(_value ?? 0)
                : const Value.absent(),
            modifiedAt: Value(now),
          ));
          for (final extra in existing.skip(1)) {
            await (db.delete(db.logs)..where((l) => l.id.equals(extra.id)))
                .go();
          }
        }
      }

      cursor = cursor.add(const Duration(days: 1));
    }

    await recomputeTrackerDenormalized(db, tracker);

    if (mounted) context.go('/tracker/${tracker.id}');
  }

  int get _dayCount {
    return _endDate.difference(_startDate).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_tracker == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Log Range')),
        body: const Center(child: Text('Tracker not found')),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
            onPressed: () => context.go('/tracker/${widget.trackerId}')),
        title: const Text('Log Range'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Date Range', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: 'Start',
                  date: _startDate,
                  onTap: _pickStartDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateButton(
                  label: 'End',
                  date: _endDate,
                  onTap: _pickEndDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$_dayCount ${_dayCount == 1 ? 'day' : 'days'} selected',
            style: theme.textTheme.bodySmall,
          ),
          const Divider(height: 32),
          Text('Action', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Clear logs in range'),
            subtitle: const Text('Removes all logs for the selected dates'),
            value: _clearMode,
            onChanged: (v) => setState(() => _clearMode = v),
          ),
          if (!_clearMode) ...[
            const SizedBox(height: 8),
            _ValueInput(
              tracker: _tracker!,
              valueOptions: _valueOptions,
              value: _value,
              onChanged: (v) => setState(() => _value = v),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _save,
            child: Text(_clearMode
                ? 'Clear $_dayCount days'
                : 'Save to $_dayCount days'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go('/tracker/${widget.trackerId}'),
            child: const Text('Cancel'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateButton(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        alignment: Alignment.centerLeft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(color: cs.primary)),
          const SizedBox(height: 2),
          Text(
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ValueInput extends StatefulWidget {
  final Tracker tracker;
  final List<String> valueOptions;
  final double? value;
  final ValueChanged<double?> onChanged;

  const _ValueInput({
    required this.tracker,
    required this.valueOptions,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_ValueInput> createState() => _ValueInputState();
}

class _ValueInputState extends State<_ValueInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final v = widget.value;
    _ctrl = TextEditingController(
      text: (widget.tracker.type == 'goal' && v != null)
          ? (v == v.truncate() ? v.toInt().toString() : v.toStringAsFixed(1))
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracker = widget.tracker;

    if (tracker.type == 'habit') {
      if (widget.valueOptions.isEmpty) {
        // Binary habit — no value needed
        return Text(
          'Marks each day as done',
          style: Theme.of(context).textTheme.bodyMedium,
        );
      }
      // Value-options habit
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Value', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.valueOptions.asMap().entries.map((e) {
              final selected = widget.value?.toInt() == e.key;
              return ChoiceChip(
                label: Text(e.value),
                selected: selected,
                onSelected: (_) => widget.onChanged(e.key.toDouble()),
              );
            }).toList(),
          ),
        ],
      );
    }

    // Goal — numeric entry
    return TextFormField(
      controller: _ctrl,
      decoration: InputDecoration(
        labelText: tracker.goalUnit ?? 'Amount',
        border: const OutlineInputBorder(),
        helperText: 'Applied to each day in the range',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (s) => widget.onChanged(double.tryParse(s.trim())),
    );
  }
}
