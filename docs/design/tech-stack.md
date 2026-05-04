# Tech Stack

- Flutter
- Android, iOS, Web apps
- SQLite db
- Lots of tests (for functionality and celebrations)

## Libraries

- **riverpod** - state management; reactively updates the home screen when a
  streak is logged
- **go_router** - Flutter team's recommended router for multi-screen navigation
- **confetti** - particle effects for milestone celebrations
- **flutter_animate** - smooth transitions and milestone animations
- **share_plus** - share the export file from the Settings screen
- **file_picker** - import a file from device storage

## Data storage

Data will be stored in a SQLite database using **drift** (formerly moor), a
type-safe Flutter ORM that handles schema migrations and query generation. JSON
files were considered but would be slow to edit as the file grows (full
read/write on each append) and schema management would be manual.

### Web platform

SQLite doesn't run natively in browsers. Drift supports a WASM/IndexedDB backend
(`drift_flutter` with `WasmDatabase`), which is the chosen path for web. This is
the main reason drift was selected over simpler packages like sqflite, which has
no web support.

## Schema

See [data-model.md](data-model.md) for the full data model.

## Implementation files

- [main.dart](../../app/lib/main.dart)
- [router.dart](../../app/lib/router.dart)
- [database.dart](../../app/lib/db/database.dart)
- [tables.dart](../../app/lib/db/tables.dart)
- [settings_screen.dart](../../app/lib/features/settings/settings_screen.dart)
