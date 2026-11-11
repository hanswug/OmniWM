#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$ROOT_DIR/Info.plist")"
ZIP="$ROOT_DIR/dist/OmniWM-$VERSION.zip"

if [ -e "$ZIP" ]; then
  echo "fork-release: $ZIP already exists; move it away first" >&2
  exit 1
fi

OMNIWM_APP_NAME="OmniWM" \
OMNIWM_BUNDLE_ID="com.hanswug.OmniWM" \
OMNIWM_SIGNING_IDENTITY="${OMNIWM_SIGNING_IDENTITY:-OmniWM Extension Self-Signed}" \
  "$ROOT_DIR/Scripts/package-app.sh" release dev

ditto -c -k --sequesterRsrc --keepParent "$ROOT_DIR/dist/OmniWM.app" "$ZIP"
echo "fork-release: $ZIP"
shasum -a 256 "$ZIP"
