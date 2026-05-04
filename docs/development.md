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

### Generating art

Source files are in `app/assets/logo/`. After updating them, regenerate all
platform assets:

```sh
task gen-art
```

Config for these lives in
[app/flutter_launcher_icons.yaml](../app/flutter_launcher_icons.yaml) and
[app/flutter_native_splash.yaml](../app/flutter_native_splash.yaml).
