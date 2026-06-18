// Updates the Flutter version in pubspec.yaml without relying on platform-
// specific shell tools like sed. Flutter maps the version parts to App Store
// fields this way:
//
//   format: major.minor.patch+build
//   version: 1.0.1+4
//            ^^^^^ ^ build number / CFBundleVersion
//            |
//            marketing version / CFBundleShortVersionString
//
// Use the default "build" bump for another build on the same release train,
// such as 1.0.1+4 -> 1.0.1+5. This is enough when App Store Connect still
// accepts new builds for that marketing version.
//
// Use the "patch" bump when App Store Connect rejects a submission with
// "Invalid Pre-Release Train" or says CFBundleShortVersionString must be
// higher. That means the old marketing version is closed, so the patch version
// must advance too: 1.0.1+4 -> 1.0.2+5.

import 'dart:io';

const pubspecPath = 'pubspec.yaml';

void main(List<String> args) {
  final options = BumpOptions.parse(args);
  final pubspec = File(pubspecPath);

  if (!pubspec.existsSync()) {
    fail('Run this from the app directory so $pubspecPath is available.');
  }

  final content = pubspec.readAsStringSync();
  final match =
      RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$', multiLine: true)
          .firstMatch(content);

  if (match == null) {
    fail('Could not find a version like "version: 1.0.0+1" in $pubspecPath.');
  }

  final current = AppVersion.fromMatch(match);
  final next = switch (options.bump) {
    Bump.build => current.bumpBuild(),
    Bump.patch => current.bumpPatch(),
  };

  if (!options.dryRun) {
    pubspec.writeAsStringSync(
      content.replaceRange(match.start, match.end, 'version: $next'),
    );
  }

  stdout.writeln('Bumped to $next');
}

Never fail(String message) {
  stderr.writeln(message);
  exitCode = 1;
  exit(exitCode);
}

enum Bump { build, patch }

class BumpOptions {
  const BumpOptions({
    required this.bump,
    required this.dryRun,
  });

  final Bump bump;
  final bool dryRun;

  static BumpOptions parse(List<String> args) {
    var bump = Bump.build;
    var dryRun = false;

    for (final arg in args) {
      switch (arg) {
        case 'build':
        case '--build':
          bump = Bump.build;
        case 'patch':
        case '--patch':
          bump = Bump.patch;
        case '--dry-run':
          dryRun = true;
        default:
          fail('Unknown option "$arg". Use: dart run tool/bump_version.dart '
              '[build|patch] [--dry-run]');
      }
    }

    return BumpOptions(bump: bump, dryRun: dryRun);
  }
}

class AppVersion {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
  });

  final int major;
  final int minor;
  final int patch;
  final int build;

  factory AppVersion.fromMatch(RegExpMatch match) {
    return AppVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      build: int.parse(match.group(4)!),
    );
  }

  AppVersion bumpBuild() {
    return AppVersion(
      major: major,
      minor: minor,
      patch: patch,
      build: build + 1,
    );
  }

  AppVersion bumpPatch() {
    return AppVersion(
      major: major,
      minor: minor,
      patch: patch + 1,
      build: build + 1,
    );
  }

  @override
  String toString() => '$major.$minor.$patch+$build';
}
