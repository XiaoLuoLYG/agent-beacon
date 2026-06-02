#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DEST="${AGENT_BEACON_APP_DIR:-$HOME/Applications}"
BIN_DEST="${AGENT_BEACON_BIN_DIR:-$HOME/.local/bin}"
STATUS_FILE="${AGENT_BEACON_STATUS_FILE:-$HOME/.agent-beacon/status.json}"
ASSET_DEST="$HOME/.agent-beacon/assets/platform-icons"

cd "$ROOT_DIR"
bash scripts/package-app.sh

mkdir -p "$APP_DEST" "$BIN_DEST" "$(dirname "$STATUS_FILE")"
rm -rf "$APP_DEST/Agent Beacon.app"
cp -R "$ROOT_DIR/dist/Agent Beacon.app" "$APP_DEST/Agent Beacon.app"
cp "$ROOT_DIR/dist/bin/AgentBeaconStatus" "$BIN_DEST/AgentBeaconStatus"
cp "$ROOT_DIR/scripts/agent-beacon-run" "$BIN_DEST/agent-beacon-run"
if [[ -d "$ROOT_DIR/Assets/PlatformIcons" ]]; then
  mkdir -p "$ASSET_DEST"
  cp "$ROOT_DIR/Assets/PlatformIcons/"*.png "$ASSET_DEST/" 2>/dev/null || true
fi
chmod +x "$BIN_DEST/AgentBeaconStatus" "$BIN_DEST/agent-beacon-run"

if [[ ! -f "$STATUS_FILE" ]]; then
  cat > "$STATUS_FILE" <<'JSON'
{
  "version": 1,
  "tasks": []
}
JSON
fi

echo "Detecting and connecting installed agents..."
"$BIN_DEST/AgentBeaconStatus" connect

cat <<EOF
Agent Beacon installed.

App:
  $APP_DEST/Agent Beacon.app

CLI:
  $BIN_DEST/AgentBeaconStatus
  $BIN_DEST/agent-beacon-run

Status file:
  $STATUS_FILE

Try:
  open "$APP_DEST/Agent Beacon.app"
  $BIN_DEST/AgentBeaconStatus doctor

Restart your terminal, or run:
  source "$HOME/.zshrc"
EOF
