// Design docs:
// - docs/design/data-model.md
// - docs/design/screens.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../db/database.dart';

/// Sits beside [TrackerDeleteButton] on the edit screens: the way to put a
/// tracker away when deleting it — and its history — is too much.
class TrackerArchiveButton extends ConsumerWidget {
  final int trackerId;
  final bool archived;

  const TrackerArchiveButton({
    super.key,
    required this.trackerId,
    required this.archived,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () async {
        await ref.read(dbProvider).setTrackerArchived(trackerId, !archived);
        if (!context.mounted) return;
        // Archiving takes the tracker off the home screen; unarchiving puts it
        // back. Either way the interesting result is the list it moved to.
        context.go(archived ? '/' : '/archive');
      },
      icon: Icon(archived ? Icons.unarchive_outlined : Icons.archive_outlined),
      label: Text(archived ? 'Restore from archive' : 'Archive'),
    );
  }
}
