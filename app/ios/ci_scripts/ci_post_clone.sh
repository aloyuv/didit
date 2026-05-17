#!/bin/zsh
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

flutter config --no-analytics
flutter precache --ios

if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi

cd "$APP_DIR"
flutter pub get

# pod install can fail intermittently when sqlite.org DNS is unreachable in
# Xcode Cloud. Retry once after a delay to let the network settle.
cd "$IOS_DIR"
pod install || {
  echo "pod install failed, retrying in 30 seconds..."
  sleep 30
  pod install
}
