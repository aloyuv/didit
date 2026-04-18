# Tech Stack

- Flutter
- Android, iOS, Web apps
- SQLite db
- Lots of tests (for functionality and celebrations)

## Libraries

- **riverpod** — state management; reactively updates the home screen when a streak is logged
- **go_router** — Flutter team's recommended router for multi-screen navigation
- **confetti** — particle effects for milestone celebrations
- **flutter_animate** — smooth transitions and milestone animations
- **share_plus** — share the export file from the Settings screen
- **file_picker** — import a file from device storage

## Data storage

Data will be stored in a sqlite database with migration and schema management.
JSON files were considered but would be slow to edit as the file grows (full
read/write on each append) and schema management would be manual.

### Web platform caveat

SQLite doesn't run natively in browsers. The chosen SQLite library must support
a WASM/IndexedDB backend for web. This is worth verifying before committing to
any specific package.

## Schema

See [data-model.md](data-model.md) for the full data model.
