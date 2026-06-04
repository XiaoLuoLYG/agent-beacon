#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/Agent Beacon.app"
APP_CONTENTS="$APP_DIR/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
BIN_DIR="$DIST_DIR/bin"
SNAPSHOT_DIR="$DIST_DIR/snapshots"
PACKAGE_ROOT="$DIST_DIR/AgentBeacon-macOS"
ZIP_PATH="$DIST_DIR/AgentBeacon-macOS.zip"
DMG_STAGING_DIR="$DIST_DIR/dmg"
DMG_PATH="$DIST_DIR/AgentBeacon-macOS.dmg"
APP_NOTARY_ZIP="$DIST_DIR/AgentBeacon-app-notary.zip"
SIGN_IDENTITY="${AGENTBEACON_CODESIGN_IDENTITY:--}"
NOTARIZE="${AGENTBEACON_NOTARIZE:-0}"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "$name is required when AGENTBEACON_NOTARIZE=1" >&2
    exit 64
  fi
}

sign_code() {
  local target="$1"
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - --timestamp=none "$target"
  else
    codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$target"
  fi
}

notarize_file() {
  local path="$1"
  if [[ "$NOTARIZE" != "1" ]]; then
    return
  fi

  require_env AGENTBEACON_NOTARY_APPLE_ID
  require_env AGENTBEACON_NOTARY_TEAM_ID
  require_env AGENTBEACON_NOTARY_PASSWORD

  xcrun notarytool submit "$path" \
    --apple-id "$AGENTBEACON_NOTARY_APPLE_ID" \
    --team-id "$AGENTBEACON_NOTARY_TEAM_ID" \
    --password "$AGENTBEACON_NOTARY_PASSWORD" \
    --wait
}

if [[ "$NOTARIZE" == "1" ]]; then
  require_env AGENTBEACON_CODESIGN_IDENTITY
  require_env AGENTBEACON_NOTARY_APPLE_ID
  require_env AGENTBEACON_NOTARY_TEAM_ID
  require_env AGENTBEACON_NOTARY_PASSWORD
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "AGENTBEACON_CODESIGN_IDENTITY must be a Developer ID Application identity when AGENTBEACON_NOTARIZE=1" >&2
    exit 64
  fi
fi

cd "$ROOT_DIR"

swift build -c release --product AgentBeacon
swift build -c release --product AgentBeaconStatus
swift build -c release --product AgentBeaconSnapshot

rm -rf "$APP_DIR"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$BIN_DIR" "$SNAPSHOT_DIR"

cp "$ROOT_DIR/.build/release/AgentBeacon" "$APP_MACOS/AgentBeacon"
cp "$ROOT_DIR/.build/release/AgentBeaconStatus" "$APP_RESOURCES/AgentBeaconStatus"
cp "$ROOT_DIR/scripts/agent-beacon-run" "$APP_RESOURCES/agent-beacon-run"
if [[ -f "$ROOT_DIR/Assets/AppIcon/AgentBeacon.icns" ]]; then
  cp "$ROOT_DIR/Assets/AppIcon/AgentBeacon.icns" "$APP_RESOURCES/AgentBeacon.icns"
fi
if [[ -d "$ROOT_DIR/Assets/PlatformIcons" ]]; then
  mkdir -p "$APP_RESOURCES/PlatformIcons"
  cp "$ROOT_DIR/Assets/PlatformIcons/"*.png "$APP_RESOURCES/PlatformIcons/" 2>/dev/null || true
fi
cp "$ROOT_DIR/.build/release/AgentBeaconStatus" "$BIN_DIR/AgentBeaconStatus"
cp "$ROOT_DIR/scripts/agent-beacon-run" "$BIN_DIR/agent-beacon-run"
chmod +x "$APP_MACOS/AgentBeacon" "$APP_RESOURCES/AgentBeaconStatus" "$APP_RESOURCES/agent-beacon-run" "$BIN_DIR/AgentBeaconStatus" "$BIN_DIR/agent-beacon-run"

"$ROOT_DIR/.build/release/AgentBeaconSnapshot" --output "$SNAPSHOT_DIR"

cat > "$APP_CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>AgentBeacon</string>
  <key>CFBundleIdentifier</key>
  <string>dev.agentbeacon.app</string>
  <key>CFBundleName</key>
  <string>Agent Beacon</string>
  <key>CFBundleDisplayName</key>
  <string>Agent Beacon</string>
  <key>CFBundleIconFile</key>
  <string>AgentBeacon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Agent Beacon activates the matching app when you click a task row.</string>
</dict>
</plist>
PLIST

sign_code "$APP_RESOURCES/AgentBeaconStatus"
sign_code "$BIN_DIR/AgentBeaconStatus"
sign_code "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

if [[ "$NOTARIZE" == "1" ]]; then
  rm -f "$APP_NOTARY_ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$APP_NOTARY_ZIP"
  notarize_file "$APP_NOTARY_ZIP"
  xcrun stapler staple "$APP_DIR"
  xcrun stapler validate "$APP_DIR"
fi

echo "Packaged app: $APP_DIR"
echo "Packaged CLI: $BIN_DIR/AgentBeaconStatus"
echo "Packaged wrapper: $BIN_DIR/agent-beacon-run"

rm -rf "$DMG_STAGING_DIR" "$DMG_PATH"
mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_DIR" "$DMG_STAGING_DIR/Agent Beacon.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
cat > "$DMG_STAGING_DIR/README.txt" <<'README'
Agent Beacon

Install:
1. Drag Agent Beacon.app to Applications.
2. Open Agent Beacon from Applications.
README
if [[ "$NOTARIZE" == "1" ]]; then
  cat >> "$DMG_STAGING_DIR/README.txt" <<'README'
3. Agent Beacon is Developer ID signed and notarized for direct launch.
README
else
  cat >> "$DMG_STAGING_DIR/README.txt" <<'README'
3. If macOS blocks the first launch, right-click the app and choose Open.

Agent Beacon is unsigned in this preview release.
README
fi

hdiutil create \
  -volname "Agent Beacon" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"

notarize_file "$DMG_PATH"
if [[ "$NOTARIZE" == "1" ]]; then
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  hdiutil verify "$DMG_PATH"
fi

echo "Packaged DMG: $DMG_PATH"

rm -rf "$PACKAGE_ROOT" "$ZIP_PATH"
mkdir -p "$PACKAGE_ROOT/bin"
mkdir -p "$PACKAGE_ROOT/screenshots"
cp -R "$APP_DIR" "$PACKAGE_ROOT/Agent Beacon.app"
cp "$BIN_DIR/AgentBeaconStatus" "$PACKAGE_ROOT/bin/AgentBeaconStatus"
cp "$BIN_DIR/agent-beacon-run" "$PACKAGE_ROOT/bin/agent-beacon-run"
cp "$ROOT_DIR/scripts/install-release.sh" "$PACKAGE_ROOT/install.sh"
chmod +x "$PACKAGE_ROOT/install.sh"
cp "$SNAPSHOT_DIR"/*.png "$PACKAGE_ROOT/screenshots/"
cp "$ROOT_DIR/README.md" "$PACKAGE_ROOT/README.md"
cp "$ROOT_DIR/LICENSE" "$PACKAGE_ROOT/LICENSE"
cp "$ROOT_DIR/CHANGELOG.md" "$PACKAGE_ROOT/CHANGELOG.md"
cp "$ROOT_DIR/docs/QUICKSTART.md" "$PACKAGE_ROOT/QUICKSTART.md"
cp "$ROOT_DIR/docs/INSTALL.md" "$PACKAGE_ROOT/INSTALL.md"
cp "$ROOT_DIR/docs/PRIVACY.md" "$PACKAGE_ROOT/PRIVACY.md"

(
  cd "$DIST_DIR"
  /usr/bin/zip -qry -X "AgentBeacon-macOS.zip" "AgentBeacon-macOS"
)

echo "Packaged zip: $ZIP_PATH"
