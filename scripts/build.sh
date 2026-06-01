#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-Debug}"
DERIVED_DATA_PATH="$ROOT_DIR/dist/.build/xcode"
ROOT_APP_PATH="$ROOT_DIR/dist/BadgeOnBar.app"

if [[ "$CONFIGURATION" != "Debug" && "$CONFIGURATION" != "Release" ]]; then
  echo "Usage: $0 [Debug|Release]"
  exit 1
fi

PROJECT_PATH="$ROOT_DIR/BadgeOnBar/BadgeOnBar.xcodeproj"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Could not find $PROJECT_PATH"
  exit 1
fi

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/BadgeOnBar.app"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild is unavailable. Install Xcode and select it:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

echo "Building Badge on Bar ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme BadgeOnBar \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "platform=macOS" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app not found at: $APP_PATH"
  exit 1
fi

mkdir -p "$ROOT_APP_PATH"
rsync -a --delete "$APP_PATH/" "$ROOT_APP_PATH/"

echo "Built app: $APP_PATH"
echo "Published app: $ROOT_APP_PATH"
