#!/usr/bin/env bash
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SOURCE="$PACKAGE_DIR/Agent Beacon.app"
STATUS_BIN_SOURCE="$PACKAGE_DIR/bin/AgentBeaconStatus"
RUNNER_SOURCE="$PACKAGE_DIR/bin/agent-beacon-run"

APP_DEST="${AGENT_BEACON_APP_DIR:-$HOME/Applications}"
BIN_DEST="${AGENT_BEACON_BIN_DIR:-$HOME/.local/bin}"
STATUS_FILE="${AGENT_BEACON_STATUS_FILE:-$HOME/.agent-beacon/status.json}"

if [[ ! -d "$APP_SOURCE" ]]; then
  echo "Agent Beacon.app was not found next to install.sh." >&2
  exit 1
fi

if [[ ! -x "$STATUS_BIN_SOURCE" || ! -x "$RUNNER_SOURCE" ]]; then
  echo "Agent Beacon helper commands were not found under bin/." >&2
  exit 1
fi

mkdir -p "$APP_DEST" "$BIN_DEST" "$(dirname "$STATUS_FILE")"

rm -rf "$APP_DEST/Agent Beacon.app"
cp -R "$APP_SOURCE" "$APP_DEST/Agent Beacon.app"
cp "$STATUS_BIN_SOURCE" "$BIN_DEST/AgentBeaconStatus"
cp "$RUNNER_SOURCE" "$BIN_DEST/agent-beacon-run"
chmod +x "$BIN_DEST/AgentBeaconStatus" "$BIN_DEST/agent-beacon-run"

if [[ ! -f "$STATUS_FILE" ]]; then
  cat > "$STATUS_FILE" <<'JSON'
{
  "version": 1,
  "tasks": []
}
JSON
fi

echo "Connecting installed agent CLIs when available..."
"$BIN_DEST/AgentBeaconStatus" connect || true

cat <<EOF
Agent Beacon installed.

App:
  $APP_DEST/Agent Beacon.app

Helpers:
  $BIN_DEST/AgentBeaconStatus
  $BIN_DEST/agent-beacon-run

Status file:
  $STATUS_FILE

Open:
  open "$APP_DEST/Agent Beacon.app"

Restart your terminal, or run:
  source "$HOME/.zshrc"
EOF
