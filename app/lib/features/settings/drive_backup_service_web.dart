import 'package:google_sign_in/google_sign_in.dart' show GoogleSignInAccount;

import 'drive_backup_service.dart';

DriveBackupService createDriveBackupService() =>
    _UnsupportedDriveBackupService();

class _UnsupportedDriveBackupService implements DriveBackupService {
  @override
  GoogleSignInAccount? get currentUser => null;

  @override
  Stream<GoogleSignInAccount?> get onCurrentUserChanged => const Stream.empty();

  @override
  Future<GoogleSignInAccount?> signIn() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<GoogleSignInAccount?> signInSilently() async => null;

  @override
  Future<GoogleSignInAccount?> awaitCurrentUser() async => null;

  @override
  Future<bool> shouldAutoBackup() async => false;

  @override
  Future<void> backup(Map<String, dynamic> data) async {}

  @override
  Future<({Map<String, dynamic> data, DateTime? modifiedTime})?>
      getLatestBackup() async => null;
}
