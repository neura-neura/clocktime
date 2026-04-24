#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DMG_STAGING_DIR="$ROOT_DIR/.build/dmg-staging"
DMG_PATH="$ROOT_DIR/.build/ClockTime.dmg"
APP_DIR="$ROOT_DIR/.build/ClockTime.app"

"$ROOT_DIR/scripts/package_app.sh"

rm -rf "$DMG_STAGING_DIR" "$DMG_PATH"
mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_DIR" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
  -volname ClockTime \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign \
    --force \
    --timestamp \
    --sign "$CODESIGN_IDENTITY" \
    "$DMG_PATH"
fi

echo "Created $DMG_PATH"
