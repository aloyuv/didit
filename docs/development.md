# Development Process

## Dev and test commands

```sh
task run
task test
task format
```

Run `flutter analyze` from `app/` when checking lints locally. Markdown files
are formatted by Prettier, both from `task format` and on save in VS Code via the
recommended Prettier extension.

## Release Process

### iOS builds (Xcode Cloud)

iOS releases are built and distributed via Xcode Cloud. The workflow triggers
automatically on pushes to `main` and archives the app for App Store submission.

**CI scripts** live in `app/ios/ci_scripts/` and run in this order:

1. `ci_post_clone.sh` — installs Flutter, fetches Dart packages, regenerates
   `Generated.xcconfig` with the correct version from `pubspec.yaml`, and runs
   `pod install`.

**Versioning:** the in-app version string (`APP_VERSION`) is the git short hash

- build date, matching the `build-ios` task in `Taskfile.yml`. `ci_post_clone.sh`
  runs `flutter build ios --release --no-codesign --dart-define="APP_VERSION=..."`
  which compiles Dart and writes `DART_DEFINES` into `Generated.xcconfig`. Xcode
  Cloud then archives the already-built artifacts via xcodebuild.

### Generating art

Source files are in `app/assets/logo/`. After updating them, regenerate all
platform assets:

```sh
task gen-art
```

Config for these lives in
[app/flutter_launcher_icons.yaml](../app/flutter_launcher_icons.yaml) and
[app/flutter_native_splash.yaml](../app/flutter_native_splash.yaml).
