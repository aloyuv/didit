// Trackers put away without deleting their history.
// Design doc: docs/design/screens.md

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../db/database.dart';
import '../../router.dart';
import '../../theme.dart';
import '../app_bottom_nav.dart';

final _archivedTrackersProvider = StreamProvider<List<Tracker>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.trackers)
        ..where((t) => t.archived.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();
});

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(_archivedTrackersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.archive),
      body: archivedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (trackers) => trackers.isEmpty
            ? const _EmptyArchive()
            : ListView.builder(
                itemCount: trackers.length,
                itemBuilder: (ctx, i) =>
                    _ArchivedTrackerTile(tracker: trackers[i]),
              ),
      ),
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.archive_outlined, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('Nothing archived', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Archive a tracker from its card menu to take it off the home '
              'screen without losing its history.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedTrackerTile extends ConsumerWidget {
  final Tracker tracker;

  const _ArchivedTrackerTile({required this.tracker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emoji = tracker.emoji?.trim();

    return ListTile(
      onTap: () => context.navigate('/tracker/${tracker.id}'),
      leading: emoji != null && emoji.isNotEmpty
          ? Text(emoji, style: kEmojiStyle)
          : Icon(tracker.type == 'habit' ? Icons.repeat : Icons.flag_outlined),
      title: Text(tracker.name),
      subtitle: Text(_summary()),
      trailing: TextButton.icon(
        onPressed: () =>
            ref.read(dbProvider).setTrackerArchived(tracker.id, false),
        icon: const Icon(Icons.unarchive_outlined),
        label: const Text('Restore'),
      ),
    );
  }

  /// Enough to recognise the tracker without opening it. Reads the stored
  /// denormalized fields, so no per-tile query.
  String _summary() {
    if (tracker.type == 'habit') {
      final longest = tracker.habitLongestStreak ?? 0;
      return longest > 0 ? 'Habit · best streak $longest' : 'Habit';
    }
    final total = tracker.goalRunningTotal ?? 0;
    final unit = tracker.goalUnit != null ? ' ${tracker.goalUnit}' : '';
    final formatted = total == total.truncate()
        ? total.toInt().toString()
        : total.toStringAsFixed(1);
    return 'Goal · $formatted$unit';
  }
}
