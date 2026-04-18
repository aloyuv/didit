# Tech Stack

- Flutter
- Android, iOS, Web apps
- SQLite db
- Lots of tests (for functionality and celebrations)

## Data storage

Data will be stored in a sqlite database, preferably with a migration and schema
management system like Prisma. JSON files were considered but it would be slow
to edit as the file grows (have to read the whole thing and write the whole
thing on each append) and managing the schema will be manual.

## Schema

See [data-model.md](data-model.md) for the full data model.
