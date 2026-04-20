import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../db/database.dart';
import 'tracker_delete_button.dart';

class GoalEditScreen extends ConsumerStatefulWidget {
  final int? trackerId;
  const GoalEditScreen({super.key, this.trackerId});

  @override
  ConsumerState<GoalEditScreen> createState() => _GoalEditScreenState();
}

class _GoalEditScreenState extends ConsumerState<GoalEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emojiController = TextEditingController();
  final _unitController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _stepSizeController = TextEditingController();
  DateTime? _targetDate;
  bool _loading = false;

  bool get _isEditing => widget.trackerId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadTracker();
  }

  Future<void> _loadTracker() async {
    setState(() => _loading = true);
    final db = ref.read(dbProvider);
    final tracker = await (db.select(db.trackers)
          ..where((t) => t.id.equals(widget.trackerId!)))
        .getSingle();
    setState(() {
      _nameController.text = tracker.name;
      _emojiController.text = tracker.emoji ?? '';
      _unitController.text = tracker.goalUnit ?? '';
      _targetAmountController.text = tracker.goalTargetAmount?.toString() ?? '';
      _stepSizeController.text = tracker.goalStepSize?.toString() ?? '';
      _targetDate = tracker.goalTargetDate;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _unitController.dispose();
    _targetAmountController.dispose();
    _stepSizeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final db = ref.read(dbProvider);
    final now = DateTime.now();
    final targetAmount = double.tryParse(_targetAmountController.text.trim());
    final stepSize = double.tryParse(_stepSizeController.text.trim());
    final unit = _unitController.text.trim().isEmpty
        ? null
        : _unitController.text.trim();
    final emoji = _optionalText(_emojiController);

    if (_isEditing) {
      await (db.update(db.trackers)
            ..where((t) => t.id.equals(widget.trackerId!)))
          .write(TrackersCompanion(
        name: Value(_nameController.text.trim()),
        emoji: Value(emoji),
        goalUnit: Value(unit),
        goalTargetAmount: Value(targetAmount),
        goalTargetDate: Value(_targetDate),
        goalStepSize: Value(stepSize),
        modifiedAt: Value(now),
      ));
    } else {
      final maxRow = await db
          .customSelect(
              'SELECT COALESCE(MAX(sort_order), 0) AS m FROM trackers')
          .getSingle();
      final sortOrder = maxRow.read<int>('m') + 1;

      await db.into(db.trackers).insert(TrackersCompanion.insert(
            name: _nameController.text.trim(),
            emoji: Value(emoji),
            type: 'goal',
            sortOrder: sortOrder,
            goalUnit: Value(unit),
            goalTargetAmount: Value(targetAmount),
            goalTargetDate: Value(_targetDate),
            goalStepSize: Value(stepSize),
            createdAt: now,
            modifiedAt: now,
          ));
    }

    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final dateLabel = _targetDate == null
        ? 'Not set'
        : '${_targetDate!.year}-'
            '${_targetDate!.month.toString().padLeft(2, '0')}-'
            '${_targetDate!.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
            onPressed: () => context.go(
                _isEditing ? '/tracker/${widget.trackerId}' : '/tracker-type')),
        title: Text(_isEditing ? 'Edit Goal' : 'New Goal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emojiController,
              decoration: const InputDecoration(
                labelText: 'Emoji (optional)',
                hintText: 'e.g. 📚',
                border: OutlineInputBorder(),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'Unit (optional)',
                hintText: 'e.g. km, books, pages',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _targetAmountController,
              decoration: const InputDecoration(
                labelText: 'Target amount (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Target date (optional)'),
              subtitle: Text(dateLabel),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_targetDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _targetDate = null),
                    ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stepSizeController,
              decoration: const InputDecoration(
                labelText: 'Step size (optional)',
                hintText: 'e.g. 1 for books, 0.5 for half-miles',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: _save, child: const Text('Save')),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              TrackerDeleteButton(trackerId: widget.trackerId!),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

String? _optionalText(TextEditingController controller) {
  final text = controller.text.trim();
  return text.isEmpty ? null : text;
}
