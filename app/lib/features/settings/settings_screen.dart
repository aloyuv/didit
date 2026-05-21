// Design docs:
// - docs/design/goals.md
// - docs/design/screens.md
// - docs/design/tech-stack.md
// - docs/design/cloud-backup.md
// - docs/design/platform-strategy.md

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'web_download.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../db/database.dart';
import 'drive_backup_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionTapCount = 0;
  final _drive = DriveBackupService();
  GoogleSignInAccount? _googleUser;
  bool _driveLoading = false;
  DateTime? _lastBackupTime;

  @override
  void initState() {
    super.initState();
    _drive.onCurrentUserChanged.listen((account) {
      if (mounted) setState(() => _googleUser = account);
    });
    setState(() => _driveLoading = true);
    _drive.awaitCurrentUser().then((account) {
      if (mounted) setState(() { _googleUser = account; _driveLoading = false; });
    }).catchError((e) {
      log('silent sign-in error: $e', name: 'Settings');
      if (mounted) setState(() => _driveLoading = false);
    });
    _loadLastBackupTime();
  }

  Future<void> _loadLastBackupTime() async {
    final ms = await SharedPreferencesAsync().getInt(lastBackupKey);
    if (ms != null && mounted) {
      setState(() => _lastBackupTime =
          DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
    }
  }

  void _onVersionTap() {
    _versionTapCount++;
    if (_versionTapCount >= 5) {
      _versionTapCount = 0;
      context.navigate('/debug');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) context.go('/');
          if (i == 2) context.navigate('/tracker-type');
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add'),
        ],
      ),
      body: ListView(
        children: [
          if (DriveBackupService.isSupported) ...[
            if (_googleUser == null)
              ListTile(
                leading: const Icon(Icons.cloud),
                title: const Text('Automatic Google Drive Backup'),
                subtitle: const Text('Sign in with Google to enable'),
                onTap: _driveLoading ? null : () => _signInToGoogle(context),
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.cloud_done),
                title: const Text('Google Drive Signed in'),
                subtitle: Text(_googleUser!.email),
                trailing: TextButton(
                  onPressed: _driveLoading
                      ? null
                      : () async {
                          await _drive.signOut();
                          if (mounted) setState(() => _googleUser = null);
                        },
                  child: const Text('Sign out'),
                ),
              ),
              ListTile(
                leading: _driveLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.backup),
                title: const Text('Back up to Google Drive'),
                subtitle: _lastBackupTime != null
                    ? Text('Last backup: ${_formatDate(_lastBackupTime!)}')
                    : null,
                onTap: _driveLoading ? null : () => _backupToDrive(context),
              ),
              ListTile(
                leading: _driveLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download),
                title: const Text('Restore from Google Drive'),
                onTap: _driveLoading ? null : () => _restoreFromDrive(context),
              ),
            ],
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Create a backup file'),
            onTap: () => _backUpData(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore from a backup file'),
            onTap: () => _restoreFromBackup(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('See source on GitHub'),
            subtitle: const Text('github.com/aloyuv/didit'),
            onTap: () => launchUrl(
              Uri.parse('https://github.com/aloyuv/didit/'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            trailing: const Text(
              String.fromEnvironment('APP_VERSION', defaultValue: 'dev'),
            ),
            onTap: _onVersionTap,
          ),
        ],
      ),
    );
  }

  Future<void> _signInToGoogle(BuildContext context) async {
    try {
      await _drive.awaitCurrentUser();
      final account = await _drive.signIn();
      if (!context.mounted) return;
      if (account == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Google sign-in failed or was cancelled')),
        );
        return;
      }
      setState(() => _googleUser = account);
      await _backupToDrive(context);
    } catch (e) {
      log('sign-in error: $e', name: 'Settings');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e')),
        );
      }
    }
  }

  Future<void> _backupToDrive(BuildContext context) async {
    setState(() => _driveLoading = true);
    try {
      final db = ref.read(dbProvider);
      final data = await db.exportData();
      await _drive.backup(data);
      if (mounted) setState(() => _lastBackupTime = DateTime.timestamp());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backed up to Google Drive')),
        );
      }
    } catch (e) {
      log('backup error: $e', name: 'Settings');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _driveLoading = false);
    }
  }

  Future<void> _restoreFromDrive(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Google Drive?'),
        content: const Text(
            'This will replace all your current data with the Drive backup. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _driveLoading = true);
    try {
      final backup = await _drive.getLatestBackup();
      if (backup == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No backup found in Google Drive')),
          );
        }
        return;
      }

      final db = ref.read(dbProvider);
      await db.importData(backup.data);

      if (context.mounted) {
        final when = backup.modifiedTime != null
            ? ' (saved ${_formatDate(backup.modifiedTime!)})'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored from Google Drive$when')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _driveLoading = false);
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  Future<void> _backUpData(BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(dbProvider);
      final data = await db.exportData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = utf8.encode(json);
      final now = DateTime.now();
      final filename =
          'didone_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
      if (kIsWeb) {
        downloadBytesAsFile(bytes, filename);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  Future<void> _restoreFromBackup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
            'This will replace all your current data. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final db = ref.read(dbProvider);
      await db.importData(data);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }
}
