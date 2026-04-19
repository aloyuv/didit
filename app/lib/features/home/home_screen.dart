import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../db/database.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackersAsync = ref.watch(trackersProvider);
    final todayAsync = ref.watch(todayLogsProvider);

    return Scaffold(
      body: trackersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (trackers) {
          if (trackers.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No trackers yet', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.push('/tracker-type'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create your first tracker'),
                  ),
                ],
              ),
            );
          }
          final todayLogs = todayAsync.valueOrNull ?? {};
          return _TrackerGrid(trackers: trackers, todayLogs: todayLogs);
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (i) {
          if (i == 0) context.go('/settings');
          if (i == 2) context.push('/tracker-type');
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add'),
        ],
      ),
    );
  }
}

class _TrackerGrid extends StatelessWidget {
  final List<Tracker> trackers;
  final Map<int, List<Log>> todayLogs;

  const _TrackerGrid({required this.trackers, required this.todayLogs});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      padding: const EdgeInsets.all(12),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: trackers
          .map((t) => _TrackerCard(tracker: t, logs: todayLogs[t.id] ?? []))
          .toList(),
    );
  }
}

typedef _EmojiParticle = ({String emoji, double dx, double dy, double spin});

class _TrackerCard extends ConsumerStatefulWidget {
  final Tracker tracker;
  final List<Log> logs;

  const _TrackerCard({required this.tracker, required this.logs});

  @override
  ConsumerState<_TrackerCard> createState() => _TrackerCardState();
}

// --- Celebration knobs ---
const _particleCount = 12;
const _spreadX = 240.0; // half-width of horizontal spread in pixels
const _offsetX = -70.0; // horizontal center bias (negative = shift left)
const _launchMin = 90.0; // minimum upward launch distance in pixels
const _launchMax = 270.0; // maximum upward launch distance in pixels
const _maxSpin = 2.0; // max rotations (in full turns, ± random)
const _animMs = 3400; // total animation duration in milliseconds
const _fadeStart = 0.6; // progress (0–1) when fade-out begins
const _gravity = 4.25; // parabola gravity coefficient (higher = falls faster)
const _emojiFontSize = 30.0;

class _TrackerCardState extends ConsumerState<_TrackerCard> {
  OverlayEntry? _overlayEntry;

  static const _emojis = ['🎉', '⭐', '✨', '🌟', '🎊', '💥', '🔥'];

  Tracker get tracker => widget.tracker;
  List<Log> get logs => widget.logs;
  bool get done => logs.isNotEmpty;

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  void _celebrate() {
    if (!mounted) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final center = renderBox.localToGlobal(
      Offset(renderBox.size.width / 2, renderBox.size.height / 2),
    );

    final rng = Random();
    final particles = List.generate(
      _particleCount,
      (_) => (
        emoji: _emojis[rng.nextInt(_emojis.length)],
        dx: rng.nextDouble() * _spreadX * 2 + _offsetX,
        dy: -(rng.nextDouble() * _launchMax + _launchMin),
        spin: (rng.nextDouble() * 2 - 1) * _maxSpin * 2 * 3.14159,
      ),
    );

    _overlayEntry?.remove();
    _overlayEntry = null;
    final entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          for (final p in particles)
            Positioned(
              left: center.dx,
              top: center.dy,
              child: _EmojiParticleWidget(particle: p),
            ),
        ],
      ),
    );
    _overlayEntry = entry;
    Overlay.of(context).insert(entry);

    Future.delayed(const Duration(milliseconds: _animMs), () {
      if (entry.mounted) entry.remove();
      if (_overlayEntry == entry) _overlayEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: done ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child:
                        Text(tracker.name, style: theme.textTheme.titleMedium),
                  ),
                  if (done) const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const Spacer(),
              _statusWidget(theme),
              const SizedBox(height: 8),
              _actionButton(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusWidget(ThemeData theme) {
    if (tracker.type == 'habit') {
      final streak = tracker.habitStreak ?? 0;
      return Text(
        '$streak day streak',
        style: theme.textTheme.titleLarge,
      );
    } else {
      final total = tracker.goalRunningTotal ?? 0;
      final unit = tracker.goalUnit != null ? ' ${tracker.goalUnit}' : '';
      final target = tracker.goalTargetAmount;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_fmt(total)}$unit',
            style: theme.textTheme.titleLarge,
          ),
          if (target != null) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(value: (total / target).clamp(0, 1)),
            Text('of ${_fmt(target)}$unit', style: theme.textTheme.bodySmall),
          ],
        ],
      );
    }
  }

  String _fmt(double v) =>
      v == v.truncate() ? v.toInt().toString() : v.toStringAsFixed(1);

  Widget _actionButton(BuildContext context, WidgetRef ref) {
    if (tracker.type == 'habit') {
      final valueOptions = tracker.habitValueOptions != null
          ? (jsonDecode(tracker.habitValueOptions!) as List).cast<String>()
          : <String>[];
      if (done) {
        return OutlinedButton.icon(
          onPressed: () => _undoLog(ref),
          icon: const Icon(Icons.undo, size: 16),
          label: const Text('Undo'),
        );
      }
      if (valueOptions.isEmpty) {
        return FilledButton(
            onPressed: () => _logBinary(ref), child: const Text('Mark done'));
      }
      return FilledButton(
        onPressed: () => _showValuePicker(context, ref, valueOptions),
        child: const Text('Log'),
      );
    } else {
      final step = tracker.goalStepSize;
      if (step != null) {
        return FilledButton(
          onPressed: () => _logGoalStep(ref, step),
          child: Text(
              '+${_fmt(step)}${tracker.goalUnit != null ? ' ${tracker.goalUnit}' : ''}'),
        );
      }
      return FilledButton(
        onPressed: () => _showGoalEntry(context, ref),
        child: const Text('Log'),
      );
    }
  }

  Future<void> _logBinary(WidgetRef ref) async {
    final db = ref.read(dbProvider);
    final now = DateTime.now();
    await db.into(db.logs).insert(LogsCompanion.insert(
          trackerId: tracker.id,
          logDate: todayDate(),
          createdAt: now,
          modifiedAt: now,
        ));
    await _updateHabitStreak(db);
    _celebrate();
  }

  Future<void> _logValue(WidgetRef ref, double value) async {
    final db = ref.read(dbProvider);
    final now = DateTime.now();
    await db.into(db.logs).insert(LogsCompanion.insert(
          trackerId: tracker.id,
          logDate: todayDate(),
          createdAt: now,
          modifiedAt: now,
          value: Value(value),
        ));
    if (tracker.type == 'habit') {
      await _updateHabitStreak(db);
      _celebrate();
    } else {
      await _updateGoalTotal(db);
    }
  }

  Future<void> _logGoalStep(WidgetRef ref, double step) => _logValue(ref, step);

  Future<void> _undoLog(WidgetRef ref) async {
    if (logs.isEmpty) return;
    final db = ref.read(dbProvider);
    await (db.delete(db.logs)..where((l) => l.id.equals(logs.last.id))).go();
    if (tracker.type == 'habit') {
      await _updateHabitStreak(db);
    } else {
      await _updateGoalTotal(db);
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

  Future<void> _showValuePicker(
      BuildContext context, WidgetRef ref, List<String> options) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Log ${tracker.name}'),
        children: options
            .asMap()
            .entries
            .map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, e.key),
                  child: Text(e.value),
                ))
            .toList(),
      ),
    );
    if (picked != null) await _logValue(ref, picked.toDouble());
  }

  Future<void> _showGoalEntry(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Log ${tracker.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: tracker.goalUnit ?? 'Amount',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
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
    if (value != null) await _logValue(ref, value);
  }
}

class _EmojiParticleWidget extends StatelessWidget {
  final _EmojiParticle particle;
  const _EmojiParticleWidget({required this.particle});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child:
          Text(particle.emoji, style: const TextStyle(fontSize: _emojiFontSize))
              .animate()
              .custom(
                duration: const Duration(milliseconds: _animMs),
                builder: (_, t, child) {
                  final opacity = t < _fadeStart
                      ? 1.0
                      : ((1.0 - t) / (1.0 - _fadeStart)).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(
                        particle.dx * t,
                        particle.dy * (t - _gravity * t * t),
                      ),
                      child: Transform.rotate(
                        angle: particle.spin * t,
                        child: child,
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
