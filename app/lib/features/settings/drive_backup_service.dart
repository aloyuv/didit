import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' show GoogleSignInAccount;

import 'drive_backup_service_native.dart'
    if (dart.library.html) 'drive_backup_service_web.dart' as impl;

const lastBackupKey = 'last_drive_backup_ms';
const _backupInterval = Duration(hours: 1);

bool isBackupDue(int? lastBackupMs, DateTime now) {
  if (lastBackupMs == null) return true;
  return now.millisecondsSinceEpoch - lastBackupMs >=
      _backupInterval.inMilliseconds;
}

/// Drive backup is mobile-only. On web the conditional import above swaps the
/// real implementation for a stub, so the GoogleSignIn / googleapis code never
/// even reaches the web compiler. See docs/design/platform-strategy.md.
abstract class DriveBackupService {
  static const bool isSupported = !kIsWeb;

  factory DriveBackupService() => impl.createDriveBackupService();

  GoogleSignInAccount? get currentUser;
  Stream<GoogleSignInAccount?> get onCurrentUserChanged;
  Future<GoogleSignInAccount?> signIn();
  Future<void> signOut();
  Future<GoogleSignInAccount?> signInSilently();
  Future<GoogleSignInAccount?> awaitCurrentUser();
  Future<bool> shouldAutoBackup();
  Future<void> backup(Map<String, dynamic> data);
  Future<({Map<String, dynamic> data, DateTime? modifiedTime})?>
      getLatestBackup();
}
