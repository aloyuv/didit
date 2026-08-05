# Platform Strategy

The app targets Android, iOS, and the web from a single codebase. Different
platforms support different capabilities and expose them through different
plugins. This doc explains how we keep platform-specific code out of the wrong
build and out of the wrong call sites.

## Three categories of feature

1. **Universally supported** — Drift, Riverpod, MaterialApp, go_router. These
   work the same everywhere. No special handling.
2. **Same logical operation, different implementation per platform** — for
   example, saving a backup file: native uses a temp file plus the system share
   sheet; web triggers a browser download via a Blob anchor click.
3. **Feature unavailable on some platform** — for example, Google Drive backup
   only runs on native. Web has no equivalent.

For categories 2 and 3 we use the **same mechanism**: split the
platform-specific code into separate files and select between them with a
conditional import. The only difference is what the unsupported side contains —
a real different implementation (category 2) or a no-op stub (category 3).

## Pattern: conditional imports

```dart
import 'feature_native.dart' if (dart.library.html) 'feature_web.dart';
```

This says: default to `feature_native.dart`, but if `dart.library.html` exists
(i.e. we're on web), import `feature_web.dart` instead. The non-selected file is
**never even parsed** by the compiler for that platform. That's the whole point
— `dart:html`, `package:web`, `google_sign_in`, etc. don't have to resolve on
the wrong platform.

### Naming convention

Always **platform-suffix** the impl files: `_native.dart` and `_web.dart`.

- `_native` means: loaded on everything that isn't web (Android, iOS, Windows,
  macOS, Linux). This matches what `!dart.library.html` actually selects.
- `_web` means: loaded only on web.

Do **not** use role-based names like `_impl.dart` and `_stub.dart`. The role
varies per feature — for `web_download` the web file is the real impl; for
`drive_backup_service` the native file is the real impl. A platform suffix tells
you _when the file loads_ without having to read the conditional import.

Every multi-platform feature follows the same shape: one entry file plus two
platform impl files. The entry file is what other code imports; the impl files
are loaded conditionally and never reach the wrong platform.

```
lib/feature/feature.dart           // entry — selects between the two below
lib/feature/feature_native.dart    // native impl
lib/feature/feature_web.dart       // web impl
```

The difference between Variant A and Variant B is just what the entry file
contains.

### Variant A: simple helper (one or two functions)

Use this when the feature is just one function and doesn't need an abstract
type. The entry file re-exports whichever platform file applies:

```dart
// web_download.dart
export 'web_download_native.dart'
    if (dart.library.html) 'web_download_web.dart';
```

Both platform files expose the same top-level function signature:

```dart
void downloadBytesAsFile(List<int> bytes, String filename);
```

Callers import the entry file and don't know about the split:

```dart
import 'web_download.dart';
```

Call site uses `kIsWeb` to route around the unsupported side:

```dart
if (kIsWeb) {
  downloadBytesAsFile(bytes, filename);
} else {
  // ...native share flow
}
```

The native file throws because it's never supposed to be invoked — anything that
calls `downloadBytesAsFile` is in a `if (kIsWeb)` branch.

Current example:
[web_download.dart](../../app/lib/features/settings/web_download.dart),
[web_download_native.dart](../../app/lib/features/settings/web_download_native.dart),
[web_download_web.dart](../../app/lib/features/settings/web_download_web.dart),
used from
[settings_screen.dart](../../app/lib/features/settings/settings_screen.dart).

### Variant B: service with multiple methods

Use this when the feature is a service with several methods that all need to
behave consistently on the unsupported platform. The abstract class enforces
that both implementations stay in sync — if you add a method to the interface,
both files must implement it or the compiler will complain.

The entry file holds the abstract class and a factory that picks the right
implementation via the conditional import:

```dart
import 'drive_backup_service_native.dart'
    if (dart.library.html) 'drive_backup_service_web.dart' as impl;

abstract class DriveBackupService {
  static const bool isSupported = !kIsWeb;
  factory DriveBackupService() => impl.createDriveBackupService();

  GoogleSignInAccount? get currentUser;
  Future<void> backup(Map<String, dynamic> data);
  // ...interface methods
}
```

Each impl file exposes a top-level factory function returning a
`DriveBackupService`:

```dart
// drive_backup_service_native.dart
DriveBackupService createDriveBackupService() => _GoogleDriveBackupService();
class _GoogleDriveBackupService implements DriveBackupService { /* real */ }

// drive_backup_service_web.dart
DriveBackupService createDriveBackupService() => _UnsupportedDriveBackupService();
class _UnsupportedDriveBackupService implements DriveBackupService { /* no-op */ }
```

Call sites just construct and use the service — no `kIsWeb` checks needed:

```dart
final _drive = DriveBackupService();
_drive.signInSilently().then((_) => _maybeAutoBackup());
```

On web that returns the no-op stub; `signInSilently()` resolves to `null`,
`shouldAutoBackup()` returns `false`, the auto-backup early-exits. No crash, no
spurious work that does anything observable.

Current example:
[drive_backup_service.dart](../../app/lib/features/settings/drive_backup_service.dart),
[drive_backup_service_native.dart](../../app/lib/features/settings/drive_backup_service_native.dart),
[drive_backup_service_web.dart](../../app/lib/features/settings/drive_backup_service_web.dart).

### `isSupported` is for UI, not for guarding calls

The abstract class exposes `static const bool isSupported = !kIsWeb`. Use it
**only to hide UI controls** that have no meaning on the unsupported platform:

```dart
if (DriveBackupService.isSupported) ...[
  ListTile(title: const Text('Back up to Google Drive'), ...),
]
```

Do **not** sprinkle `if (DriveBackupService.isSupported)` around call sites in
`main.dart` or `initState`. The stub handles those correctly already — adding
the check duplicates a constraint that's already encoded in the type system.

## Initialization gotchas

Some plugins assert or throw on first access when not configured for the
platform. `google_sign_in_web` is the canonical example — it asserts
`appClientId != null` on first construction of `GoogleSignIn`, and we don't
configure a web client ID.

- **Top-level `final` is lazy in Dart.** `final _googleSignIn = GoogleSignIn();`
  at module scope does _not_ run the constructor at import time — it runs on
  first read. Conditional imports prevent the read entirely on the wrong
  platform.
- **Class field initializers are eager.** `final _drive = DriveBackupService();`
  inside a widget runs when the widget is constructed. Make sure the constructor
  (or the factory it delegates to) is safe to run on every platform. With the
  Variant B pattern this is automatic — the factory just returns the right impl.

## Anti-patterns

- **Scattering `kIsWeb` at every call site.** Push the platform decision into
  the conditional import. Multiple `kIsWeb` checks for the same feature drift
  apart over time.
- **`try/catch` around the platform error.** Swallowing `MissingPluginException`
  or assertion failures hides real bugs and fills logs with noise.
- **Role-based file suffixes (`_impl`/`_stub`).** Use platform suffixes instead
  — see the naming section above.
- **Trusting UI guards alone.** Hiding a button does not stop `initState`,
  `main.dart`, or a stream subscription from constructing the underlying
  service. The conditional import is what actually ensures the right code loads.

## Testing

Tests run on the host (treated as native), so they exercise the `_native`
implementations. Web-specific code (`_web.dart` files) is not exercised by
`flutter test` — only by `flutter test --platform chrome` or by actually running
the web build.

Keep platform plugin calls behind small services so the rest of the feature can
be unit tested with a fake on the host.

## Implementation files

- [web_download.dart](../../app/lib/features/settings/web_download.dart)
- [web_download_native.dart](../../app/lib/features/settings/web_download_native.dart)
- [web_download_web.dart](../../app/lib/features/settings/web_download_web.dart)
- [drive_backup_service.dart](../../app/lib/features/settings/drive_backup_service.dart)
- [drive_backup_service_native.dart](../../app/lib/features/settings/drive_backup_service_native.dart)
- [drive_backup_service_web.dart](../../app/lib/features/settings/drive_backup_service_web.dart)
- [settings_screen.dart](../../app/lib/features/settings/settings_screen.dart)
- [main.dart](../../app/lib/main.dart)
