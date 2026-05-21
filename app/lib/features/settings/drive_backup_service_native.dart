import 'dart:convert';
import 'dart:developer';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

import 'drive_backup_service.dart';

const _backupFileName = 'didit_backup.json';
const _hasGoogleAccountKey = 'has_google_account';
const _tag = 'DriveBackup';

DriveBackupService createDriveBackupService() => _GoogleDriveBackupService();

final _googleSignIn = GoogleSignIn(
  scopes: [drive.DriveApi.driveFileScope],
);

Future<GoogleSignInAccount?>? _silentSignInFuture;

class _GoogleDriveBackupService implements DriveBackupService {
  @override
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  @override
  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      _googleSignIn.onCurrentUserChanged;

  @override
  Future<GoogleSignInAccount?> signIn() async {
    log('signing in', name: _tag);
    final account = await _googleSignIn.signIn();
    if (account != null) {
      log('signed in as ${account.email}', name: _tag);
      await SharedPreferencesAsync().setBool(_hasGoogleAccountKey, true);
    } else {
      log('sign-in cancelled', name: _tag);
    }
    return account;
  }

  @override
  Future<void> signOut() async {
    log('signing out', name: _tag);
    await _googleSignIn.signOut();
    await SharedPreferencesAsync().remove(_hasGoogleAccountKey);
    log('signed out', name: _tag);
  }

  @override
  Future<GoogleSignInAccount?> signInSilently() async {
    final prefs = SharedPreferencesAsync();
    final hasAccount = await prefs.getBool(_hasGoogleAccountKey) ?? false;
    if (!hasAccount) {
      log('silent sign-in skipped: no previous account', name: _tag);
      return null;
    }
    log('attempting silent sign-in', name: _tag);
    _silentSignInFuture ??= _googleSignIn.signInSilently().then((account) {
      log(account != null ? 'silent sign-in: ${account.email}' : 'silent sign-in: no cached account', name: _tag);
      return account;
    }).catchError((e) {
      log('silent sign-in failed: $e', name: _tag);
      return null;
    }).whenComplete(() => _silentSignInFuture = null);
    return _silentSignInFuture!;
  }

  /// Waits for any in-flight silent sign-in to complete, then returns currentUser.
  /// Use this instead of calling signInSilently() a second time.
  @override
  Future<GoogleSignInAccount?> awaitCurrentUser() {
    if (_silentSignInFuture != null) return _silentSignInFuture!;
    return Future.value(_googleSignIn.currentUser);
  }

  @override
  Future<bool> shouldAutoBackup() async {
    if (_googleSignIn.currentUser == null) {
      log('auto-backup skipped: not signed in', name: _tag);
      return false;
    }
    final lastMs = await SharedPreferencesAsync().getInt(lastBackupKey);
    final due = isBackupDue(lastMs, DateTime.timestamp());
    if (due) {
      log('auto-backup due (last: ${lastMs == null ? 'never' : DateTime.fromMillisecondsSinceEpoch(lastMs, isUtc: true)})', name: _tag);
    } else {
      final lastDt = DateTime.fromMillisecondsSinceEpoch(lastMs!, isUtc: true);
      final elapsed = DateTime.timestamp().difference(lastDt);
      log('auto-backup skipped: last backup ${elapsed.inMinutes}m ago', name: _tag);
    }
    return due;
  }

  Future<drive.DriveApi> _getDriveApi() async {
    final account = _googleSignIn.currentUser;
    if (account == null) throw Exception('Not signed in to Google');

    log('getting auth client for ${account.email}', name: _tag);
    final authClient = await _googleSignIn.authenticatedClient();
    if (authClient == null) {
      throw Exception('Could not authenticate with Google');
    }
    log('auth client ready', name: _tag);

    return drive.DriveApi(authClient);
  }

  @override
  Future<void> backup(Map<String, dynamic> data) async {
    log('backup started', name: _tag);
    final api = await _getDriveApi();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = utf8.encode(json);
    log('payload: ${bytes.length} bytes', name: _tag);

    final existing = await api.files.list(
      q: "name='$_backupFileName' and trashed=false",
      $fields: 'files(id)',
    );

    if (existing.files?.isNotEmpty == true) {
      final fileId = existing.files!.first.id!;
      log('updating existing file $fileId', name: _tag);
      await api.files.update(
        drive.File(),
        fileId,
        uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      );
    } else {
      log('creating new file', name: _tag);
      await api.files.create(
        drive.File()..name = _backupFileName,
        uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      );
    }

    await SharedPreferencesAsync()
        .setInt(lastBackupKey, DateTime.timestamp().millisecondsSinceEpoch);
    log('backup complete', name: _tag);
  }

  @override
  Future<({Map<String, dynamic> data, DateTime? modifiedTime})?>
      getLatestBackup() async {
    log('looking for backup file', name: _tag);
    final api = await _getDriveApi();

    final result = await api.files.list(
      q: "name='$_backupFileName' and trashed=false",
      $fields: 'files(id,modifiedTime)',
      orderBy: 'modifiedTime desc',
    );

    if (result.files?.isEmpty != false) {
      log('no backup file found', name: _tag);
      return null;
    }

    final file = result.files!.first;
    log('found backup file ${file.id} modified ${file.modifiedTime}', name: _tag);

    final media = await api.files.get(
      file.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = await media.stream.expand((x) => x).toList();
    log('downloaded ${bytes.length} bytes', name: _tag);
    final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return (data: data, modifiedTime: file.modifiedTime);
  }
}
