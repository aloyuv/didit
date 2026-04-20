import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../db/database.dart';

class TrackerDeleteButton extends ConsumerWidget {
  final int trackerId;
  const TrackerDeleteButton({super.key, required this.trackerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton(
      onPressed: () => _delete(context, ref),
      style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
      child: const Text('Delete'),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tracker?'),
        content: const Text('This will permanently delete the tracker and all its data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final db = ref.read(dbProvider);
    await (db.delete(db.trackers)..where((t) => t.id.equals(trackerId))).go();
    if (context.mounted) context.go('/');
  }
}
