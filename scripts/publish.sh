#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ScampMicroDeck.xcodeproj"
EXPORT_OPTIONS_PLIST="$ROOT_DIR/scripts/ExportOptions-AppStoreConnect.plist"
ARCHIVE_PATH="$ROOT_DIR/dist/archives/ScampMicroDeck.xcarchive"
EXPORT_DIR="$ROOT_DIR/dist/export/ScampMicroDeck"
USE_ASC_API_KEY=0

usage() {
  echo "Usage: $0"
  echo
  echo "Optional App Store Connect API key environment:"
  echo "  ASC_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8"
  echo "  ASC_KEY_ID=XXXXXXXXXX"
  echo "  ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}

configure_auth() {
  local has_any_auth=0

  if [[ -n "${ASC_KEY_PATH:-}" || -n "${ASC_KEY_ID:-}" || -n "${ASC_ISSUER_ID:-}" ]]; then
    has_any_auth=1
  fi

  if [[ "$has_any_auth" -eq 0 ]]; then
    return
  fi

  if [[ -z "${ASC_KEY_PATH:-}" || -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
    usage
    echo
    echo "Set ASC_KEY_PATH, ASC_KEY_ID, and ASC_ISSUER_ID, or leave all three unset to use Xcode's signed-in account."
    exit 1
  fi

  USE_ASC_API_KEY=1
}

xcodebuild_with_auth() {
  if [[ "$USE_ASC_API_KEY" -eq 1 ]]; then
    xcodebuild "$@" \
      -authenticationKeyPath "$ASC_KEY_PATH" \
      -authenticationKeyID "$ASC_KEY_ID" \
      -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  else
    xcodebuild "$@"
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
elif [[ -n "${1:-}" ]]; then
  usage
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild is unavailable. Install Xcode and select it."
  exit 1
fi

configure_auth
mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_DIR"

echo "Archiving Scamp Micro Deck..."
rm -rf "$ARCHIVE_PATH"
xcodebuild_with_auth archive \
  -project "$PROJECT_PATH" \
  -scheme ScampMicroDeck \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates

echo "Uploading Scamp Micro Deck archive to App Store Connect..."
rm -rf "$EXPORT_DIR"
xcodebuild_with_auth -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -allowProvisioningUpdates

echo "Uploaded Scamp Micro Deck archive: $ARCHIVE_PATH"
