#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/ClockTime.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BINARY="$ROOT_DIR/.build/release/ClockTime"
INFO_PLIST="$ROOT_DIR/Resources/Info.plist"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"

if [[ ! -x "$BINARY" ]]; then
  swift build -c release --package-path "$ROOT_DIR"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BINARY" "$MACOS_DIR/ClockTime"
cp "$INFO_PLIST" "$CONTENTS_DIR/Info.plist"
if [[ ! -f "$APP_ICON" ]]; then
  swift "$ROOT_DIR/scripts/generate_app_icon.swift" "$APP_ICON"
fi
cp "$APP_ICON" "$RESOURCES_DIR/AppIcon.icns"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$CODESIGN_IDENTITY" \
    "$APP_DIR"
else
  codesign --force --deep --sign - "$APP_DIR"
fi

echo "Created $APP_DIR"
