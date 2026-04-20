import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../db/database.dart';
import '../../theme.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackersAsync = ref.watch(trackersProvider);
    final todayAsync = ref.watch(todayLogsProvider);

    return Stack(
      children: [
        Scaffold(
          body: trackersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (trackers) {
              if (trackers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No trackers yet',
                          style: TextStyle(fontSize: 18)),
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
        ),
        Offstage(
          child: Text(
            _emojis.join(),
            style: const TextStyle(fontSize: _emojiFontSize),
          ),
        ),
      ],
    );
  }
}

class _TrackerGrid extends StatelessWidget {
  final List<Tracker> trackers;
  final Map<int, List<Log>> todayLogs;

  const _TrackerGrid({required this.trackers, required this.todayLogs});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cols = 2;
        const hPad = 12.0;
        const gap = 8.0;
        final cardWidth = (constraints.maxWidth - hPad * 2 - gap) / cols;
        // Show ~2.2 rows so it's clear the grid scrolls.
        final cardHeight = (constraints.maxHeight - hPad * 2) / 2.2;
        final ratio = cardWidth / cardHeight;
        return GridView.count(
          crossAxisCount: cols,
          childAspectRatio: ratio,
          padding: const EdgeInsets.all(hPad),
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          children: trackers
              .map((t) =>
                  _TrackerCard(tracker: t, logs: todayLogs[t.id] ?? []))
              .toList(),
        );
      },
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
const _vxMin = -440.0;
const _vxMax = 440.0;
const _vyMin = 190.0; // minimum upward launch distance in pixels
const _vyMax = 1870.0; // maximum upward launch distance in pixels
const _minSpin = 3.0; // max rotations (in full turns, ± random)
const _maxSpin = 6.0; // max rotations (in full turns, ± random)
const _animMs = 3400; // total animation duration in milliseconds
const _fadeStart = 0.6; // progress (0–1) when fade-out begins
const _gravity = 4.25; // parabola gravity coefficient (higher = falls faster)
const _emojiFontSize = 30.0;
const _emojis = ['🎉', '⭐', '✨', '🌟', '🎊', '💥', '🔥'];

class _TrackerCardState extends ConsumerState<_TrackerCard>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  late final AnimationController _fillAnim;

  Tracker get tracker => widget.tracker;
  List<Log> get logs => widget.logs;
  bool get done => logs.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _fillAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: widget.logs.isNotEmpty ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_TrackerCard old) {
    super.didUpdateWidget(old);
    final wasDone = old.logs.isNotEmpty;
    if (!wasDone && done) {
      _fillAnim.forward();
    } else if (wasDone && !done) {
      _fillAnim.reverse();
    }
  }

  @override
  void dispose() {
    _fillAnim.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _celebrate(int count) {
    if (!mounted) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final center = renderBox.localToGlobal(
      Offset(renderBox.size.width / 2, renderBox.size.height / 2),
    );

    final emoji = _emojis[count % _emojis.length];
    final rng = Random();
    final particles = List.generate(
      _particleCount,
      (_) => (
        emoji: emoji,
        dx: rng.nextDouble() * (_vxMax - _vxMin) + _vxMin,
        dy: -(rng.nextDouble() * _vyMax + _vyMin),
        spin:
            (_minSpin + rng.nextDouble() * (_maxSpin - _minSpin)) * 2 * 3.14159,
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
    final cs = theme.colorScheme;

    final pillStyle = OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: const StadiumBorder(),
      foregroundColor: cs.onPrimaryContainer,
      side: BorderSide(color: cs.onPrimaryContainer.withValues(alpha: 0.5)),
      textStyle: theme.textTheme.bodyLarge,
    );

    final pills = Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        OutlinedButton(
          style: pillStyle,
          onPressed: () => context.push('/tracker/${tracker.id}'),
          child: const Text('Details'),
        ),
        OutlinedButton(
          style: pillStyle,
          onPressed: () => _navigateToEdit(context),
          child: const Text('Edit'),
        ),
        if (done)
          OutlinedButton(
            style: pillStyle,
            onPressed: () => _undoLog(ref),
            child: const Text('Undo'),
          ),
      ],
    );

    final statStyle = theme.textTheme.displaySmall;

    Widget bottomSection;
    if (tracker.type == 'habit') {
      final streak = tracker.habitStreak ?? 0;
      bottomSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$streak day streak', style: statStyle),
          const SizedBox(height: 6),
          pills,
        ],
      );
    } else {
      final total = tracker.goalRunningTotal ?? 0;
      final unit = tracker.goalUnit != null ? ' ${tracker.goalUnit}' : '';
      final target = tracker.goalTargetAmount;
      bottomSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_fmt(total)}$unit', style: statStyle),
          if (target != null) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(value: (total / target).clamp(0, 1)),
            Text('of ${_fmt(target)}$unit', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 6),
          pills,
        ],
      );
    }

    return AnimatedBuilder(
      animation: _fillAnim,
      builder: (context, child) {
        final t = _fillAnim.value;
        return Card(
          clipBehavior: Clip.antiAlias,
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cardGradientTop(cs, t),
                  cardGradientBottom(cs, t),
                ],
              ),
            ),
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: () => _primaryAction(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                        tracker.name, style: theme.textTheme.titleMedium),
                  ),
                  if (done)
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const Spacer(),
              bottomSection,
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.truncate() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _primaryAction(BuildContext context, WidgetRef ref) async {
    if (tracker.type == 'habit') {
      final valueOptions = tracker.habitValueOptions != null
          ? (jsonDecode(tracker.habitValueOptions!) as List).cast<String>()
          : <String>[];
      if (done && tracker.habitAllowMultiple != true) return;
      if (valueOptions.isEmpty) {
        await _logBinary(ref);
      } else {
        await _showValuePicker(context, ref, valueOptions);
      }
    } else {
      final step = tracker.goalStepSize;
      if (step != null) {
        await _logGoalStep(ref, step);
      } else {
        await _showGoalEntry(context, ref);
      }
    }
  }

  void _navigateToEdit(BuildContext context) {
    if (tracker.type == 'habit') {
      context.push('/habit-edit/${tracker.id}');
    } else {
      context.push('/goal-edit/${tracker.id}');
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
    final streak = await _updateHabitStreak(db);
    _celebrate(streak);
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
      final streak = await _updateHabitStreak(db);
      _celebrate(streak);
    } else {
      await _updateGoalTotal(db);
      _celebrate(logs.length + 1);
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

  Future<int> _updateHabitStreak(AppDatabase db) async {
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
    return streak;
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

class _EmojiParticleWidget extends StatefulWidget {
  final _EmojiParticle particle;
  const _EmojiParticleWidget({required this.particle});

  @override
  State<_EmojiParticleWidget> createState() => _EmojiParticleWidgetState();
}

class _EmojiParticleWidgetState extends State<_EmojiParticleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: _animMs),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        child: Text(
          widget.particle.emoji,
          style: const TextStyle(fontSize: _emojiFontSize),
        ),
        builder: (_, child) {
          final t = _controller.value;
          final opacity = t < _fadeStart
              ? 1.0
              : ((1.0 - t) / (1.0 - _fadeStart)).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(
                widget.particle.dx * t,
                widget.particle.dy * (t - _gravity * t * t),
              ),
              child: Transform.rotate(
                angle: widget.particle.spin * t,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
