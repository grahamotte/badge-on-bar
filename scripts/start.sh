#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-Debug}"

if [[ "$CONFIGURATION" != "Debug" && "$CONFIGURATION" != "Release" ]]; then
  echo "Usage: $0 [Debug|Release]"
  exit 1
fi

echo "Stopping running Scamp Micro Deck app (if any)..."
osascript -e 'tell application "Scamp Micro Deck" to quit' >/dev/null 2>&1 || true
killall "Scamp Micro Deck" >/dev/null 2>&1 || true

echo "Cleaning previous app bundles..."
rm -rf "$ROOT_DIR/Scamp Micro Deck.app" "$ROOT_DIR/Sampt.app" "$ROOT_DIR/dist/.build/xcode" "$ROOT_DIR/dist/Scamp Micro Deck.app"

echo "Cleaning derived build output..."
rm -rf "$ROOT_DIR/dist/.build/xcode"

echo "Building fresh app..."
"$ROOT_DIR/scripts/build.sh" "$CONFIGURATION"

echo "Launching app..."
open "$ROOT_DIR/dist/Scamp Micro Deck.app"
