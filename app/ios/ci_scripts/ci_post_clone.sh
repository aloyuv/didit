#!/bin/zsh
# Xcode Cloud CI hook — runs automatically after the repo is cloned.
# Xcode Cloud docs: https://developer.apple.com/documentation/xcode/writing-custom-build-scripts
#
# Responsibilities:
#   1. Install Flutter (clones stable if not already on PATH)
#   2. Run flutter build ios --no-codesign to compile Dart and write
#      Generated.xcconfig with DART_DEFINES (including APP_VERSION).
#      Xcode Cloud then archives the already-built artifacts via xcodebuild.
#   3. Run pod install (with one retry) to install CocoaPods dependencies
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$(cd "$IOS_DIR/.." && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_DIR="$HOME/flutter"

  if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  fi

  export PATH="$FLUTTER_DIR/bin:$PATH"
fi

# Disable analytics to avoid network noise during CI builds.
flutter config --no-analytics
# file_picker 11+ pulls in DKImagePickerController via SPM. Xcode Cloud has
# automatic dependency resolution disabled, so it requires a Package.resolved
# that doesn't exist. Disabling SPM makes Flutter fall back to CocoaPods.
flutter config --no-enable-swift-package-manager
flutter precache --ios

if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi

APP_VERSION="$(git -C "$APP_DIR" rev-parse --short HEAD) ($(git -C "$APP_DIR" log -1 --format=%cd --date=format:'%Y-%m-%d'))"

cd "$APP_DIR"
flutter pub get
flutter build ios --release --no-codesign --dart-define="APP_VERSION=$APP_VERSION"

# pod install can fail intermittently when sqlite.org DNS is unreachable in
# Xcode Cloud. Retry once after a delay to let the network settle.
cd "$IOS_DIR"
pod install || {
  echo "pod install failed, retrying in 30 seconds..."
  sleep 30
  pod install
}
