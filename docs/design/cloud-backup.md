# Cloud Backup

Users can sign in with Google and back up their data to Google Drive. The backup
is a single JSON file (`didit_backup.json`) stored in the user's Drive, visible
and portable. Restore replaces all local data with the Drive copy.

## Scope

`drive.file` — the app can only see files it created, not the rest of the user's
Drive. This is the least-invasive scope that still allows reading back the
backup.

## Trigger

Automatic and manual.

- **Auto**: on app launch and every time the app resumes from background, a
  silent backup runs if the user is signed in and at least 1 hour has passed
  since the last backup. Failures are silently ignored — auto backup must never
  interrupt the user.
- **Manual**: the user can tap "Back up to Google Drive" or "Restore from Google
  Drive" in Settings at any time.

The timestamp of the last successful backup is stored as `last_drive_backup_ms`
(epoch milliseconds) via `SharedPreferencesAsync`. It is read on Settings screen
open to show "Last backup: YYYY-MM-DD" under the backup button.

## Format

Same JSON as the local export/restore. One file, overwritten on each backup. No
versioning or history; Drive's own version history covers that if needed.

## Platform support

Android and iOS only. Web uses a fundamentally different OAuth flow
(popup-based) and the Drive REST calls hit CORS restrictions in a browser. The
existing local export via share sheet still works on web (using a browser
download instead of a temp file).

`DriveBackupService` enforces this with a `static const isSupported = !kIsWeb`
flag. UI controls and side-effect call sites (`main.dart` auto-backup, settings
`initState`) all check this flag, and every public method short-circuits when
unsupported. See [platform-strategy.md](platform-strategy.md) for the general
pattern.

## Why not iCloud / other providers

Google Drive works on both Android and iOS with a single implementation. iCloud
would require separate native code and only helps iOS users. A Google account is
something most users already have on both platforms.

## Testing

The auto-backup interval logic in `shouldAutoBackup()` is unit-testable by
injecting a fake timestamp. The Drive upload/restore round-trip requires a real
device or emulator with a Google account — no practical way to mock it without
significantly more test infrastructure.

Manual test checklist:

1. Sign in → backup button appears, "Last backup" subtitle is absent
2. Tap "Back up" → snackbar confirms, "Last backup: today" appears
3. Open Google Drive on another device → `didit_backup.json` is visible
4. On a fresh install, sign in → tap "Restore" → all data returns
5. Tap "Back up" again within 1 hour → auto-backup skips (check via logs),
   manual backup still works
6. On web → Drive section is not shown

## OAuth setup

The clients are configured at
https://console.cloud.google.com/auth/clients?project=ubershmekel

The Android app does not use the downloaded `client_secret_*.json` file; Android
apps are public clients, and bundled secrets can be extracted from an APK. Do
not commit that file or add it to Flutter assets.

Package `com.andluck.didit` is registered on GCP with every SHA-1 certificate
fingerprint that can sign an installed build:

- Android Debug builds: the debug keystore SHA-1 from `keytool`.
- Android Direct APK installs: the release/APK signing keystore SHA-1 from
  `keytool`.
- Android Google Play installs: the Play Console app signing certificate SHA-1
  from `Play Console > Setup > App integrity > App signing key certificate`.
- iOS uses just one id and a "REVERSED_CLIENT_ID" stored in
  GoogleService-Info.plist.

Google Play App Signing re-signs delivered builds, so the Play-installed app
does not present the local upload/release keystore fingerprint. If Google
Sign-In fails only for Play installs with
`PlatformException(sign_in_failed, ...:10:, null, null)`, check that the Play
app signing SHA-1 is registered on an Android OAuth client.

## Implementation files

- [drive_backup_service.dart](../../app/lib/features/settings/drive_backup_service.dart)
- [settings_screen.dart](../../app/lib/features/settings/settings_screen.dart)
- [main.dart](../../app/lib/main.dart) — auto-backup trigger on launch/resume
