// Design docs:
// - docs/design/goals.md
// - docs/design/screens.md
// - docs/design/visual-effects.md

import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../db/database.dart';
import '../../router.dart';
import '../../theme.dart';
import '../tracker_denormalized.dart';
import '../tracker_details/log_edit_sheet.dart';
import 'home_providers.dart';
import 'streak_display.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackersAsync = ref.watch(trackersProvider);
    final todayAsync = ref.watch(todayLogsProvider);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: SvgPicture.asset(
              'assets/logo/didit-logo.svg',
              height: 32,
            ),
            centerTitle: false,
          ),
          body: trackersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (trackers) {
              if (trackers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/logo/didit-logo.svg',
                        height: 120,
                      ),
                      const SizedBox(height: 24),
                      const Text('No trackers yet',
                          style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.navigate('/tracker-type'),
                        icon: const Icon(Icons.add),
                        label: const Text('Create your first tracker'),
                      ),
                    ],
                  ),
                );
              }
              final todayLogs = todayAsync.value ?? {};
              return _TrackerGrid(
                trackers: trackers,
                todayLogs: todayLogs,
              );
            },
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: 1,
            onTap: (i) {
              if (i == 0) context.go('/settings');
              if (i == 2) context.navigate('/tracker-type');
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
            _emojis,
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

  const _TrackerGrid({
    required this.trackers,
    required this.todayLogs,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final cols = isLandscape ? 2 : 1;
        const hPad = 12.0;
        const gap = 8.0;
        final cardWidth =
            (constraints.maxWidth - hPad * 2 - (cols - 1) * gap) / cols;
        // Show ~4.5 rows so cards are compact and scrollability is clear.
        final cardHeight = ((constraints.maxHeight - hPad * 2) / 4.5)
            .clamp(110.0, double.infinity);
        final ratio = cardWidth / cardHeight;
        return GridView.count(
          crossAxisCount: cols,
          childAspectRatio: ratio,
          padding: const EdgeInsets.all(hPad),
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          children: trackers
              .map(
                (t) => _TrackerCard(
                  tracker: t,
                  todayLogs: todayLogs[t.id] ?? [],
                ),
              )
              .toList(),
        );
      },
    );
  }
}

typedef _EmojiParticle = ({String emoji, double dx, double dy, double spin});

class _TrackerCard extends ConsumerStatefulWidget {
  final Tracker tracker;
  final List<Log> todayLogs;

  const _TrackerCard({
    required this.tracker,
    required this.todayLogs,
  });

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
// All the emojis used in the app
// We need to put them in an invisible render object so they don't
// flicker as ☒ for a few moments before rendering.
const _emojis = '🎉⭐✨🌟🎊💥🔥🏃❤️🏊';
// Variation selectors (e.g. U+FE0F in ❤️) are not standalone emoji, so filter them out.
final _emojiList =
    _emojis.runes.where((r) => r != 0xFE0F).map(String.fromCharCode).toList();

class _TrackerCardState extends ConsumerState<_TrackerCard>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  late final AnimationController _fillAnim;

  Tracker get tracker => widget.tracker;
  List<Log> get todayLogs => widget.todayLogs;
  bool get done => todayLogs.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _fillAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: widget.todayLogs.isNotEmpty ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_TrackerCard old) {
    super.didUpdateWidget(old);
    final wasDone = old.todayLogs.isNotEmpty;
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

    final trackerEmoji = tracker.emoji?.trim();
    final emoji = trackerEmoji == null || trackerEmoji.isEmpty
        ? _emojiList[count % _emojiList.length]
        : trackerEmoji;
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
    final trackerNameStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: (theme.textTheme.titleMedium?.fontSize ?? 16) * 1.5,
      fontWeight: FontWeight.w700,
      height: 1.05,
      color: cs.onSurface.withValues(alpha: 0.8),
    );

    final pills = PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 28),
      tooltip: 'More options',
      onSelected: (value) {
        if (value == 'calendar') {
          context.navigate('/tracker/${tracker.id}');
        } else if (value == 'settings') {
          context.navigate(
            tracker.type == 'habit'
                ? '/habit-edit/${tracker.id}'
                : '/goal-edit/${tracker.id}',
          );
        } else if (value == 'note') {
          showLogEditSheet(context, ref, log: todayLogs.last, tracker: tracker);
        } else if (value == 'undo') {
          _undoLog(ref);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'calendar',
          child: ListTile(
            leading: Icon(Icons.calendar_today),
            title: Text('Calendar'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (done) ...[
          PopupMenuItem(
            value: 'note',
            child: ListTile(
              leading: const Icon(Icons.note_add),
              title: const Text('Note'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'undo',
            child: ListTile(
              leading: const Icon(Icons.undo),
              title: const Text('Undo'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ],
    );

    final statStyle =
        theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800);

    // Parse value options and compute streak up-front so both the top row
    // and bottom section can reference them.
    List<String> habitValueOptions = [];
    int? todayValueIdx;
    HabitStreakDisplay? streakDisplay;
    if (tracker.type == 'habit') {
      if (tracker.habitValueOptions != null) {
        habitValueOptions =
            (jsonDecode(tracker.habitValueOptions!) as List).cast<String>();
      }
      if (habitValueOptions.isNotEmpty && todayLogs.isNotEmpty) {
        final v = todayLogs.last.value;
        if (v != null) todayValueIdx = v.round();
      }
      final cachedStreak = tracker.habitStreak;
      final displayCachedStreak = _displayCachedHabitStreak(cachedStreak);
      final isPeriodicHabit =
          tracker.habitPeriod == 'weekly' || tracker.habitPeriod == 'monthly';
      final needsLogFallback =
          cachedStreak == null || cachedStreak <= 0 || isPeriodicHabit;
      final fallbackLogDates = needsLogFallback
          ? ref
              .watch(habitLogDatesByTrackerProvider(tracker.id))
              .maybeWhen(data: (dates) => dates, orElse: () => const <String>{})
          : const <String>{};
      streakDisplay = habitStreakDisplay(
        doneToday: done,
        logDates: {
          ...fallbackLogDates,
          for (final log in todayLogs) log.logDate,
        },
        today: DateTime.now(),
        cachedStreak: displayCachedStreak,
        period: tracker.habitPeriod,
      );
    }

    // Top-right: streak badge, goal total, or check circle.
    Widget? topRight;
    if (streakDisplay != null && streakDisplay.value > 0) {
      topRight = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${streakDisplay.value}',
            style: theme.textTheme.displayMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(streakDisplay.suffix, style: theme.textTheme.labelSmall),
        ],
      );
    } else if (tracker.type == 'goal') {
      final total = tracker.goalRunningTotal ?? 0;
      final unit = tracker.goalUnit != null ? ' ${tracker.goalUnit}' : '';
      topRight = Text('${_fmt(total)}$unit', style: statStyle);
    } else if (done) {
      topRight = const Icon(Icons.check_circle, color: kSeedColor);
    }

    Widget bottomSection;
    if (tracker.type == 'habit') {
      bottomSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (habitValueOptions.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: habitValueOptions.asMap().entries.map((e) {
                final isSelected = todayValueIdx == e.key;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primaryContainer
                        : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    e.value,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? cs.onPrimaryContainer
                          : cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
          ],
        ],
      );
    } else {
      final target = tracker.goalTargetAmount;
      final unit = tracker.goalUnit != null ? ' ${tracker.goalUnit}' : '';
      final ghost = _goalGhost(tracker);
      bottomSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (target != null) ...[
            _GoalProgressBar(
              progress: ((tracker.goalRunningTotal ?? 0) / target).clamp(0, 1),
              ghostFraction: ghost != null
                  ? (ghost.amount / target).clamp(0.0, 1.0)
                  : null,
            ),
            const SizedBox(height: 2),
            if (ghost != null)
              Text(
                  'expected ${_fmt(ghost.amount)}$unit · out of ${_fmt(target)}$unit',
                  style: theme.textTheme.bodySmall)
            else
              Text('out of ${_fmt(target)}$unit',
                  style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
          ],
        ],
      );
    }

    final ghost = tracker.type == 'goal' ? _goalGhost(tracker) : null;
    final isOnTrack =
        ghost != null && (tracker.goalRunningTotal ?? 0) >= ghost.amount;

    return AnimatedBuilder(
      animation: _fillAnim,
      builder: (context, child) {
        final t = ghost != null ? (isOnTrack ? 1.0 : 0.0) : _fillAnim.value;
        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          color: cardGradientTop(cs, t),
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
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (tracker.emoji != null &&
                          tracker.emoji!.trim().isNotEmpty) ...[
                        Text(
                          tracker.emoji!.trim(),
                          style: trackerNameStyle,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          tracker.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: trackerNameStyle,
                        ),
                      ),
                      if (topRight != null) topRight,
                    ],
                  ),
                  Expanded(
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.bottomLeft,
                        maxHeight: double.infinity,
                        child: bottomSection,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: pills,
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) =>
      v == v.truncate() ? v.toInt().toString() : v.toStringAsFixed(1);

  ({double amount, double fraction})? _goalGhost(Tracker t) {
    final start = t.goalStartDate;
    final end = t.goalTargetDate;
    final target = t.goalTargetAmount;
    if (start == null || end == null || target == null) return null;
    final totalMs = end.difference(start).inMilliseconds;
    if (totalMs <= 0) return null;
    final elapsedMs =
        DateTime.now().difference(start).inMilliseconds.clamp(0, totalMs);
    final fraction = elapsedMs / totalMs;
    return (amount: target * fraction, fraction: fraction);
  }

  int? _displayCachedHabitStreak(int? cachedStreak) {
    if (!done || cachedStreak == null || cachedStreak <= 0) {
      return cachedStreak;
    }

    final hasLogNewerThanTracker =
        todayLogs.any((log) => log.modifiedAt.isAfter(tracker.modifiedAt));
    return hasLogNewerThanTracker ? cachedStreak + 1 : cachedStreak;
  }

  Future<void> _cycleValueOption(WidgetRef ref, List<String> options) async {
    final db = ref.read(dbProvider);
    final existing = todayLogs.isEmpty ? null : todayLogs.last;
    final newIdx = await cycleHabitValueOption(
        db, tracker, todayDate(), existing, options);
    final streak = await recomputeHabitStreak(db, tracker);
    if (newIdx != null) _celebrate(streak);
  }

  Future<void> _primaryAction(BuildContext context, WidgetRef ref) async {
    if (tracker.type == 'habit') {
      await _habitPrimaryAction(context, ref);
    } else {
      await _goalPrimaryAction(context, ref);
    }
  }

  Future<void> _habitPrimaryAction(BuildContext context, WidgetRef ref) async {
    final valueOptions = tracker.habitValueOptions != null
        ? (jsonDecode(tracker.habitValueOptions!) as List).cast<String>()
        : <String>[];
    final isCycleHabit = valueOptions.isNotEmpty &&
        valueOptions.length <= habitValueOptionsCycleMax;
    if (isCycleHabit) {
      await _cycleValueOption(ref, valueOptions);
      return;
    }
    final newLog = !done || tracker.habitAllowMultiple == true;
    if (newLog) {
      if (valueOptions.isEmpty) {
        await _logBinary(ref);
      } else {
        await _showValuePicker(context, ref, valueOptions);
      }
    } else {
      await _showAlreadyLoggedDialog(context, ref, valueOptions);
    }
  }

  Future<void> _goalPrimaryAction(BuildContext context, WidgetRef ref) async {
    final step = tracker.goalStepSize;
    if (step != null) {
      await _logGoalStep(ref, step);
    } else {
      await _showGoalEntry(context, ref);
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
    final streak = await recomputeHabitStreak(db, tracker);
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
      final streak = await recomputeHabitStreak(db, tracker);
      _celebrate(streak);
    } else {
      await recomputeGoalTotal(db, tracker);
      _celebrate(todayLogs.length + 1);
    }
  }

  Future<void> _logGoalStep(WidgetRef ref, double step) => _logValue(ref, step);

  Future<void> _undoLog(WidgetRef ref) async {
    if (todayLogs.isEmpty) return;
    final db = ref.read(dbProvider);
    await (db.delete(db.logs)..where((l) => l.id.equals(todayLogs.last.id)))
        .go();
    if (tracker.type == 'habit') {
      await recomputeHabitStreak(db, tracker);
    } else {
      await recomputeGoalTotal(db, tracker);
    }
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

  Future<void> _showAlreadyLoggedDialog(
      BuildContext context, WidgetRef ref, List<String> options) async {
    const undoKey = -1;
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Update ${tracker.name}'),
        children: [
          ...options.asMap().entries.map((e) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, e.key),
                child: Text(e.value),
              )),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, undoKey),
            child: const Text('Undo recent log'),
          ),
        ],
      ),
    );
    if (picked == null) return;
    if (picked == undoKey) {
      await _undoLog(ref);
    } else {
      await _undoLog(ref);
      await _logValue(ref, picked.toDouble());
    }
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

class _GoalProgressBar extends StatelessWidget {
  final double progress;
  final double? ghostFraction;

  const _GoalProgressBar({required this.progress, this.ghostFraction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(6));
    if (ghostFraction == null) {
      return LinearProgressIndicator(
        value: progress,
        minHeight: 10,
        borderRadius: radius,
        color: cs.primary,
      );
    }
    const barH = 10.0;
    const circleD = 18.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final circleLeft =
            (ghostFraction! * width - circleD / 2).clamp(0.0, width - circleD);
        return SizedBox(
          height: circleD,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: (circleD - barH) / 2,
                height: barH,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: barH,
                  borderRadius: radius,
                  color: cs.primary,
                ),
              ),
              Positioned(
                left: circleLeft,
                top: 0,
                child: Container(
                  width: circleD,
                  height: circleD,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.onSurface.withValues(alpha: 0.35),
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
