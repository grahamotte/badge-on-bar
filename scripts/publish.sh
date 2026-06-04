#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  if [[ -n "${KEY_FILE:-}" && -f "$KEY_FILE" ]]; then
    rm -f "$KEY_FILE"
  fi
}
trap cleanup EXIT

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/BadgeOnBar/BadgeOnBar.xcodeproj"
ASC_EXPORT_OPTIONS="$ROOT_DIR/scripts/ExportOptions-AppStoreConnect.plist"
DID_EXPORT_OPTIONS="$ROOT_DIR/scripts/ExportOptions-DeveloperID.plist"
ARCHIVE_PATH="$ROOT_DIR/dist/archives/BadgeOnBar.xcarchive"
ASC_EXPORT_DIR="$ROOT_DIR/dist/export/AppStore"
DID_EXPORT_DIR="$ROOT_DIR/dist/export/DeveloperID"
ZIP_PATH="$ROOT_DIR/dist/BadgeOnBar.zip"
CODEBERG_OWNER="grahamotte"
CODEBERG_REPO="badge-on-bar"
APP_STORE_SUCCEEDED=0

usage() {
  echo "Usage: $0"
  echo
  echo "Publishes to both App Store Connect and Codeberg from a single archive."
  echo
  echo "Required environment variables:"
  echo "  CODEBERG_TOKEN         Codeberg personal access token (repository scope)"
  echo "  APPLE_KEY_ID           App Store Connect API key ID"
  echo "  APPLE_KEY_P8_BASE64    Base64-encoded App Store Connect API key .p8 file"
  echo "  APPLE_ISSUER_ID        App Store Connect API issuer ID"
}

# --- Check prerequisites ---
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild is unavailable. Install Xcode and select it."
  exit 1
fi

missing=()
[[ -z "${CODEBERG_TOKEN:-}" ]] && missing+=("CODEBERG_TOKEN")
[[ -z "${APPLE_KEY_ID:-}" ]] && missing+=("APPLE_KEY_ID")
[[ -z "${APPLE_KEY_P8_BASE64:-}" ]] && missing+=("APPLE_KEY_P8_BASE64")
[[ -z "${APPLE_ISSUER_ID:-}" ]] && missing+=("APPLE_ISSUER_ID")

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Missing required environment variables:"
  for var in "${missing[@]}"; do
    echo "  $var"
  done
  echo
  usage
  exit 1
fi

# --- Decode API key to temp file ---
KEY_FILE="$(mktemp /tmp/badge-on-bar-key.XXXXXX.p8)"
echo "$APPLE_KEY_P8_BASE64" | base64 -d > "$KEY_FILE"
chmod 600 "$KEY_FILE"

# --- Read version ---
VERSION=$(xcodebuild -project "$PROJECT_PATH" -showBuildSettings 2>/dev/null | grep " MARKETING_VERSION" | head -1 | awk '{print $3}')
if [[ -z "$VERSION" ]]; then
  echo "Could not read MARKETING_VERSION from project"
  exit 1
fi
echo "Version: $VERSION"

# --- Archive (once, for both destinations) ---
mkdir -p "$(dirname "$ARCHIVE_PATH")" "$ASC_EXPORT_DIR" "$DID_EXPORT_DIR"

echo "Archiving Badge on Bar (Release)..."
rm -rf "$ARCHIVE_PATH"
xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme BadgeOnBar \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates

# --- 1. Upload to App Store Connect (best-effort) ---
echo
echo "=== Uploading to App Store Connect ==="
rm -rf "$ASC_EXPORT_DIR"
mkdir -p "$ASC_EXPORT_DIR"

if xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$ASC_EXPORT_DIR" \
  -exportOptionsPlist "$ASC_EXPORT_OPTIONS" \
  -allowProvisioningUpdates; then
  APP_STORE_SUCCEEDED=1
  echo "App Store Connect upload succeeded."
else
  echo "App Store Connect upload FAILED (continuing with Codeberg release)."
fi

# --- 2. Export Developer ID signed app ---
echo
echo "=== Exporting Developer ID signed app ==="
rm -rf "$DID_EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$DID_EXPORT_DIR" \
  -exportOptionsPlist "$DID_EXPORT_OPTIONS" \
  -allowProvisioningUpdates

APP_PATH="$DID_EXPORT_DIR/BadgeOnBar.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Export succeeded but app not found at: $APP_PATH"
  exit 1
fi

# --- Create ZIP ---
echo
echo "Creating ZIP for notarization..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "Created: $ZIP_PATH"

# --- Notarize ---
echo
echo "Submitting for notarization..."
xcrun notarytool submit "$ZIP_PATH" \
  --key "$KEY_FILE" \
  --key-id "$APPLE_KEY_ID" \
  --issuer "$APPLE_ISSUER_ID" \
  --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"
echo "Notarization complete."

# --- Push git tag ---
TAG="v$VERSION"
echo
echo "Creating and pushing tag $TAG..."
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag $TAG already exists — deleting and recreating"
  git tag -d "$TAG"
  git push origin ":refs/tags/$TAG" 2>/dev/null || true
fi
git tag "$TAG"
git push origin "$TAG"

# --- Create Codeberg release ---
echo
echo "=== Creating Codeberg release $TAG ==="

RELEASE_RESPONSE=$(curl -sS -X POST \
  "https://codeberg.org/api/v1/repos/$CODEBERG_OWNER/$CODEBERG_REPO/releases" \
  -H "Authorization: token $CODEBERG_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"tag_name\": \"$TAG\",
    \"name\": \"$TAG\",
    \"body\": \"Badge on Bar $VERSION\",
    \"draft\": false,
    \"prerelease\": false
  }")

RELEASE_ID=$(echo "$RELEASE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
if [[ -z "$RELEASE_ID" ]]; then
  echo "Failed to create release. Response:"
  echo "$RELEASE_RESPONSE"
  exit 1
fi
echo "Release $TAG created, ID: $RELEASE_ID"

# --- Upload asset ---
echo "Uploading BadgeOnBar.zip to release $RELEASE_ID..."
ASSET_RESPONSE=$(curl -sS -X POST \
  "https://codeberg.org/api/v1/repos/$CODEBERG_OWNER/$CODEBERG_REPO/releases/$RELEASE_ID/assets" \
  -H "Authorization: token $CODEBERG_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "attachment=@$ZIP_PATH")

ASSET_NAME=$(echo "$ASSET_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('name',''))" 2>/dev/null)
if [[ -z "$ASSET_NAME" ]]; then
  echo "Failed to upload asset. Response:"
  echo "$ASSET_RESPONSE"
  exit 1
fi
echo "Uploaded: $ASSET_NAME"

# --- Summary ---
echo
echo "=== Published v$VERSION ==="
echo "Codeberg release: https://codeberg.org/$CODEBERG_OWNER/$CODEBERG_REPO/releases/tag/$TAG"
if [[ "$APP_STORE_SUCCEEDED" -eq 1 ]]; then
  echo "App Store Connect: uploaded"
else
  echo "App Store Connect: upload FAILED (check manually)"
fi
