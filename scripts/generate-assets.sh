#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_IMAGE="${1:-$ROOT_DIR/assets/logo.png}"
ICONSET_DIR="$ROOT_DIR/ScampMicroDeck/Assets.xcassets/AppIcon.appiconset"

if ! command -v magick &>/dev/null && ! command -v convert &>/dev/null; then
  echo "ImageMagick is not installed. Install it with:"
  echo "  brew install imagemagick"
  exit 1
fi

IM_CMD="magick"
if ! command -v magick &>/dev/null; then
  IM_CMD="convert"
fi

if [[ ! -f "$SOURCE_IMAGE" ]]; then
  echo "Source image not found: $SOURCE_IMAGE"
  exit 1
fi

echo "Generating app icons from: $SOURCE_IMAGE"

generate() {
  "$IM_CMD" "$SOURCE_IMAGE" -resize "${1}x${1}" "PNG32:$ICONSET_DIR/$2"
  echo "  $2 ($1×$1)"
}

# Sizes from AppIcon.appiconset/Contents.json
# filename            logical@scale → pixel size
generate 16    "icon_16x16.png"       # 16×16 @1x
generate 32    "icon_16x16@2x.png"    # 16×16 @2x
generate 32    "icon_32x32.png"       # 32×32 @1x
generate 64    "icon_32x32@2x.png"    # 32×32 @2x
generate 128   "icon_128x128.png"     # 128×128 @1x
generate 256   "icon_128x128@2x.png"  # 128×128 @2x
generate 256   "icon_256x256.png"     # 256×256 @1x
generate 512   "icon_256x256@2x.png"  # 256×256 @2x
generate 512   "icon_512x512.png"     # 512×512 @1x
generate 1024  "icon_512x512@2x.png"  # 512×512 @2x

echo "Done. Icons written to: $ICONSET_DIR"
