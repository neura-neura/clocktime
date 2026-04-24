#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/ClockTime.app"
DMG_PATH="$ROOT_DIR/.build/ClockTime.dmg"
ZIP_PATH="$ROOT_DIR/.build/ClockTime.zip"

if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
  echo "Set CODESIGN_IDENTITY to your Developer ID Application certificate name." >&2
  exit 1
fi

if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
  NOTARY_AUTH=(--keychain-profile "$NOTARYTOOL_PROFILE")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  NOTARY_AUTH=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD")
else
  echo "Set NOTARYTOOL_PROFILE, or APPLE_ID + APPLE_TEAM_ID + APPLE_APP_SPECIFIC_PASSWORD." >&2
  exit 1
fi

swift build -c release --package-path "$ROOT_DIR"
"$ROOT_DIR/scripts/package_app.sh"

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" "${NOTARY_AUTH[@]}" --wait
xcrun stapler staple "$APP_DIR"

"$ROOT_DIR/scripts/package_dmg.sh"
xcrun notarytool submit "$DMG_PATH" "${NOTARY_AUTH[@]}" --wait
xcrun stapler staple "$DMG_PATH"
spctl -a -vvv -t open "$DMG_PATH"

echo "Notarized $DMG_PATH"
