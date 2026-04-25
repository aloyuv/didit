# Development Process

## Dev and test commands

```sh
  cd app
  flutter run
  flutter test
  flutter analyze
```

## Release Process

### Generating art

Source files are in `app/assets/logo/`. After updating them, regenerate all platform assets:

```sh
cd app

# App icons (Android, iOS, web favicon)
dart run flutter_launcher_icons

# Splash screens (Android, iOS)
dart run flutter_native_splash:create
```

Config for these lives in [app/flutter_launcher_icons.yaml](../app/flutter_launcher_icons.yaml) and [app/flutter_native_splash.yaml](../app/flutter_native_splash.yaml).
