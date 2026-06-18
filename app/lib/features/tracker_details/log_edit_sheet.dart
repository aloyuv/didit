// Design docs:
// - docs/design/data-model.md
// - docs/design/screens.md

import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../db/database.dart';
import '../tracker_denormalized.dart';

Future<void> showLogEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required Log log,
  required Tracker tracker,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _LogEditSheet(log: log, tracker: tracker, ref: ref),
  );
}

class _LogEditSheet extends ConsumerStatefulWidget {
  final Log log;
  final Tracker tracker;
  final WidgetRef ref;

  const _LogEditSheet({
    required this.log,
    required this.tracker,
    required this.ref,
  });

  @override
  ConsumerState<_LogEditSheet> createState() => _LogEditSheetState();
}

class _LogEditSheetState extends ConsumerState<_LogEditSheet> {
  late final TextEditingController _noteCtrl;
  late final TextEditingController _valueCtrl;
  late DateTime _createdAt;
  late DateTime _modifiedAt;
  // _autoUpdateModifiedAt is false when the user manually overrides modifiedAt
  // so save use DateTime.now() if it's true
  bool _autoUpdateModifiedAt = true;
  int? _selectedOptionIdx;
  bool _saving = false;

  bool get _hasChanges {
    if (_noteCtrl.text != (widget.log.note ?? '')) return true;
    final tracker = widget.tracker;
    if (tracker.type == 'goal') {
      final original =
          widget.log.value != null ? _fmtNum(widget.log.value!) : '';
      if (_valueCtrl.text.trim() != original) return true;
    } else if (tracker.habitValueOptions != null) {
      if (_selectedOptionIdx != widget.log.value?.toInt()) return true;
    }
    if (_createdAt != widget.log.createdAt) return true;
    if (!_autoUpdateModifiedAt && _modifiedAt != widget.log.modifiedAt) {
      return true;
    }
    return false;
  }

  Future<void> _tryPop() async {
    if (!_hasChanges) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.log.note ?? '');
    _valueCtrl = TextEditingController(
      text: widget.log.value != null ? _fmtNum(widget.log.value!) : '',
    );
    _createdAt = widget.log.createdAt;
    _modifiedAt = widget.log.modifiedAt;
    if (widget.tracker.habitValueOptions != null && widget.log.value != null) {
      _selectedOptionIdx = widget.log.value!.toInt();
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  String _fmtNum(double v) =>
      v == v.truncate() ? v.toInt().toString() : v.toStringAsFixed(1);

  String _fmtDateTime(DateTime dt) {
    final d = dt.toLocal();
    final date =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  List<String> _getValueOptions() {
    try {
      return (jsonDecode(widget.tracker.habitValueOptions!) as List)
          .cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final local = initial.toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute)
        .toUtc();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final db = ref.read(dbProvider);
    final tracker = widget.tracker;
    final hasValueOptions = tracker.habitValueOptions != null;

    Value<double?> valueUpdate = const Value.absent();
    if (tracker.type == 'goal') {
      final raw = _valueCtrl.text.trim();
      if (raw.isEmpty) {
        valueUpdate = const Value(null);
      } else {
        final parsed = double.tryParse(raw);
        if (parsed == null) {
          setState(() => _saving = false);
          return;
        }
        valueUpdate = Value(parsed);
      }
    } else if (hasValueOptions) {
      valueUpdate = Value(_selectedOptionIdx?.toDouble());
    }

    final note = _noteCtrl.text.trim();
    final modifiedAt = _autoUpdateModifiedAt ? DateTime.now() : _modifiedAt;
    await (db.update(db.logs)..where((l) => l.id.equals(widget.log.id))).write(
      LogsCompanion(
        note: Value(note.isEmpty ? null : note),
        value: valueUpdate,
        createdAt: Value(_createdAt),
        modifiedAt: Value(modifiedAt),
      ),
    );

    if (tracker.type == 'goal') await recomputeGoalTotal(db, tracker);
    if (tracker.type == 'habit') await recomputeHabitStreak(db, tracker);

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete log?'),
        content: Text('Remove the log entry for ${widget.log.logDate}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final db = ref.read(dbProvider);
    await (db.delete(db.logs)..where((l) => l.id.equals(widget.log.id))).go();
    if (widget.tracker.type == 'habit') {
      await recomputeHabitStreak(db, widget.tracker);
    } else {
      await recomputeGoalTotal(db, widget.tracker);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tracker = widget.tracker;
    final log = widget.log;
    final isGoal = tracker.type == 'goal';
    final hasValueOptions = tracker.habitValueOptions != null;
    final valueOptions = hasValueOptions ? _getValueOptions() : <String>[];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _tryPop();
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(logDate: log.logDate, theme: theme, onClose: _tryPop),
            const SizedBox(height: 12),
            _MetaRow(
              label: 'Created',
              value: _fmtDateTime(_createdAt),
              theme: theme,
              cs: cs,
              onEdit: () async {
                final dt = await _pickDateTime(_createdAt);
                if (dt != null) setState(() => _createdAt = dt);
              },
            ),
            _MetaRow(
              label: 'Modified',
              value: _fmtDateTime(
                _autoUpdateModifiedAt ? widget.log.modifiedAt : _modifiedAt,
              ),
              theme: theme,
              cs: cs,
              onEdit: () async {
                final dt = await _pickDateTime(_modifiedAt);
                if (dt != null) {
                  setState(() {
                    _modifiedAt = dt;
                    _autoUpdateModifiedAt = false;
                  });
                }
              },
            ),
            if (log.isFreeze == true)
              _MetaRow(
                label: 'Type',
                value: 'Freeze day',
                theme: theme,
                cs: cs,
              ),
            if (hasValueOptions && valueOptions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: valueOptions.asMap().entries.map((e) {
                  return ChoiceChip(
                    label: Text(e.value),
                    selected: _selectedOptionIdx == e.key,
                    onSelected: (_) =>
                        setState(() => _selectedOptionIdx = e.key),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            if (isGoal) ...[
              TextField(
                controller: _valueCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: tracker.goalUnit ?? 'Amount',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _saving ? null : _save(),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Add a note…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: Icon(Icons.delete_outline, color: cs.error),
                  label: Text('Delete', style: TextStyle(color: cs.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.error),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _saving ? null : _tryPop,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String logDate;
  final ThemeData theme;
  final VoidCallback onClose;

  const _SheetHeader(
      {required this.logDate, required this.theme, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Log — $logDate', style: theme.textTheme.titleLarge),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  final ColorScheme cs;
  final VoidCallback? onEdit;

  const _MetaRow({
    required this.label,
    required this.value,
    required this.theme,
    required this.cs,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Text(value, style: theme.textTheme.bodyMedium),
          if (onEdit != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.edit, size: 14, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
