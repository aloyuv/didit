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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.log.note ?? '');
    _valueCtrl = TextEditingController(
      text: widget.log.value != null ? _fmtNum(widget.log.value!) : '',
    );
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

  String? _habitValueLabel(double value) {
    try {
      final options = (jsonDecode(widget.tracker.habitValueOptions!) as List)
          .cast<String>();
      final idx = value.toInt();
      if (idx >= 0 && idx < options.length) return options[idx];
    } catch (_) {}
    return null;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final db = ref.read(dbProvider);
    final tracker = widget.tracker;

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
    }

    final note = _noteCtrl.text.trim();
    await (db.update(db.logs)..where((l) => l.id.equals(widget.log.id))).write(
      LogsCompanion(
        note: Value(note.isEmpty ? null : note),
        value: valueUpdate,
        modifiedAt: Value(DateTime.now()),
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

    return Padding(
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
          _SheetHeader(logDate: log.logDate, theme: theme),
          const SizedBox(height: 12),
          _MetaRow(
            label: 'Created',
            value: _fmtDateTime(log.createdAt),
            theme: theme,
            cs: cs,
          ),
          _MetaRow(
            label: 'Modified',
            value: _fmtDateTime(log.modifiedAt),
            theme: theme,
            cs: cs,
          ),
          if (log.isFreeze == true)
            _MetaRow(
              label: 'Type',
              value: 'Freeze day',
              theme: theme,
              cs: cs,
            ),
          if (hasValueOptions && log.value != null) ...[
            _MetaRow(
              label: 'Value',
              value: _habitValueLabel(log.value!) ?? _fmtNum(log.value!),
              theme: theme,
              cs: cs,
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
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
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
                onPressed: _saving ? null : () => Navigator.pop(context),
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
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String logDate;
  final ThemeData theme;

  const _SheetHeader({required this.logDate, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Log — $logDate', style: theme.textTheme.titleLarge),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
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

  const _MetaRow({
    required this.label,
    required this.value,
    required this.theme,
    required this.cs,
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
        ],
      ),
    );
  }
}
