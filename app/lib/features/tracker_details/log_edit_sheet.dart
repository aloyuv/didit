// Design docs:
// - docs/design/data-model.md
// - docs/design/screens.md

import 'dart:async';
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
  // The sheet writes while it is open and once more as it closes, so it holds
  // the app-scoped database directly rather than a ref that dies with it.
  final db = ref.read(dbProvider);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _LogEditSheet(log: log, tracker: tracker, db: db),
  );
}

class _LogEditSheet extends StatefulWidget {
  final Log log;
  final Tracker tracker;
  final AppDatabase db;

  const _LogEditSheet({
    required this.log,
    required this.tracker,
    required this.db,
  });

  @override
  State<_LogEditSheet> createState() => _LogEditSheetState();
}

class _LogEditSheetState extends State<_LogEditSheet> {
  /// How long after the last keystroke edits are written. The sheet has no
  /// Save button, so typing has to persist on its own — but not once per
  /// letter.
  static const _autoSaveDelay = Duration(milliseconds: 400);

  late final TextEditingController _noteCtrl;
  late final TextEditingController _valueCtrl;
  late DateTime _createdAt;
  late DateTime _modifiedAt;
  // False once the user picks a modified timestamp by hand; until then every
  // save stamps it with the current time.
  bool _autoUpdateModifiedAt = true;
  int? _selectedOptionIdx;

  Timer? _autoSave;
  // True while an edit is waiting to be written; cleared as a write starts.
  bool _dirty = false;
  bool _deleted = false;
  // The value currently in the database, so note-only edits can skip the
  // streak/total recompute.
  double? _savedValue;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.log.note ?? '');
    _valueCtrl = TextEditingController(
      text: widget.log.value != null ? _fmtNum(widget.log.value!) : '',
    );
    _createdAt = widget.log.createdAt;
    _modifiedAt = widget.log.modifiedAt;
    _savedValue = widget.log.value;
    if (widget.tracker.habitValueOptions != null && widget.log.value != null) {
      _selectedOptionIdx = widget.log.value!.toInt();
    }
    _noteCtrl.addListener(_onEdited);
    _valueCtrl.addListener(_onEdited);
  }

  @override
  void dispose() {
    _autoSave?.cancel();
    _noteCtrl.removeListener(_onEdited);
    _valueCtrl.removeListener(_onEdited);
    // A swipe-down dismissal disposes the sheet mid-edit. _persist reads the
    // controllers before its first await, so the write outlives them.
    if (_dirty && !_deleted) unawaited(_persist());
    _noteCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  void _onEdited() {
    _dirty = true;
    _autoSave?.cancel();
    _autoSave = Timer(_autoSaveDelay, _persist);
  }

  /// Writes the current edits to the log row.
  ///
  /// Every control is read synchronously, before the first await, so
  /// [dispose] can flush a pending edit even though it disposes the
  /// controllers right afterwards.
  Future<void> _persist() async {
    _autoSave?.cancel();
    if (_deleted) return;
    final db = widget.db;
    final note = _noteCtrl.text.trim();
    final valueUpdate = _valueUpdate();
    final modifiedAt = _autoUpdateModifiedAt ? DateTime.now() : _modifiedAt;
    _dirty = false;

    await (db.update(db.logs)..where((l) => l.id.equals(widget.log.id))).write(
      LogsCompanion(
        note: Value(note.isEmpty ? null : note),
        value: valueUpdate,
        createdAt: Value(_createdAt),
        modifiedAt: Value(modifiedAt),
      ),
    );

    if (valueUpdate.present && valueUpdate.value != _savedValue) {
      _savedValue = valueUpdate.value;
      await recomputeTrackerDenormalized(db, widget.tracker);
    }
  }

  /// The value to write, or [Value.absent] when this tracker has no editable
  /// value, or when the typed amount is not a number yet (mid-typing "1." or
  /// "-") and the stored one should stand.
  Value<double?> _valueUpdate() {
    final tracker = widget.tracker;
    if (tracker.type == 'goal') {
      final raw = _valueCtrl.text.trim();
      if (raw.isEmpty) return const Value(null);
      final parsed = double.tryParse(raw);
      return parsed == null ? const Value.absent() : Value(parsed);
    }
    if (tracker.habitValueOptions != null) {
      return Value(_selectedOptionIdx?.toDouble());
    }
    return const Value.absent();
  }

  /// For edits that are one deliberate choice — a chip, a picked timestamp —
  /// which should not sit in the debounce window.
  void _saveNow() {
    _dirty = true;
    unawaited(_persist());
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

    // Keeps a pending auto-save from writing the row back out from under the
    // delete.
    _deleted = true;
    _autoSave?.cancel();

    final db = widget.db;
    await (db.delete(db.logs)..where((l) => l.id.equals(widget.log.id))).go();
    await recomputeTrackerDenormalized(db, widget.tracker);
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
    final valueOptions = habitValueOptions(tracker);

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
          Text('Log — ${log.logDate}', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _MetaRow(
            label: 'Created',
            value: _fmtDateTime(_createdAt),
            theme: theme,
            cs: cs,
            onEdit: () async {
              final dt = await _pickDateTime(_createdAt);
              if (dt == null) return;
              setState(() => _createdAt = dt);
              _saveNow();
            },
          ),
          _MetaRow(
            label: 'Modified',
            value: _fmtDateTime(_modifiedAt),
            theme: theme,
            cs: cs,
            onEdit: () async {
              final dt = await _pickDateTime(_modifiedAt);
              if (dt == null) return;
              setState(() {
                _modifiedAt = dt;
                _autoUpdateModifiedAt = false;
              });
              _saveNow();
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
                  onSelected: (_) {
                    setState(() => _selectedOptionIdx = e.key);
                    _saveNow();
                  },
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
                onPressed: _delete,
                icon: Icon(Icons.delete_outline, color: cs.error),
                label: Text('Delete', style: TextStyle(color: cs.error)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.error),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
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
