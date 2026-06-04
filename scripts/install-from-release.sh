#!/usr/bin/env bash
set -euo pipefail

REPO="${AGENT_BEACON_REPO:-XiaoLuoLYG/agent-beacon}"
VERSION="${AGENT_BEACON_VERSION:-latest}"
APP_DEST="${AGENT_BEACON_APP_DIR:-$HOME/Applications}"
OPEN_APP="${AGENT_BEACON_OPEN_APP:-1}"

if [[ "$VERSION" == "latest" ]]; then
  DOWNLOAD_URL="https://github.com/$REPO/releases/latest/download/AgentBeacon-macOS.zip"
else
  DOWNLOAD_URL="https://github.com/$REPO/releases/download/$VERSION/AgentBeacon-macOS.zip"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agent-beacon-install.XXXXXX")"
ZIP_PATH="$TMP_DIR/AgentBeacon-macOS.zip"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading Agent Beacon from $DOWNLOAD_URL"
curl --fail --location --retry 3 --output "$ZIP_PATH" "$DOWNLOAD_URL"

if [[ -n "${AGENT_BEACON_SHA256:-}" ]]; then
  ACTUAL_SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
  if [[ "$ACTUAL_SHA256" != "$AGENT_BEACON_SHA256" ]]; then
    echo "SHA256 mismatch for AgentBeacon-macOS.zip" >&2
    echo "Expected: $AGENT_BEACON_SHA256" >&2
    echo "Actual:   $ACTUAL_SHA256" >&2
    exit 65
  fi
fi

ditto -x -k "$ZIP_PATH" "$TMP_DIR"
PACKAGE_DIR="$TMP_DIR/AgentBeacon-macOS"

if [[ ! -x "$PACKAGE_DIR/install.sh" ]]; then
  echo "install.sh was not found in the Agent Beacon release package." >&2
  exit 1
fi

xattr -dr com.apple.quarantine "$PACKAGE_DIR/Agent Beacon.app" 2>/dev/null || true
bash "$PACKAGE_DIR/install.sh"
xattr -dr com.apple.quarantine "$APP_DEST/Agent Beacon.app" 2>/dev/null || true

if [[ "$OPEN_APP" != "0" ]]; then
  open "$APP_DEST/Agent Beacon.app"
fi

cat <<EOF

Agent Beacon is ready.

If your terminal was already open, restart it or run:
  source "$HOME/.zshrc"
EOF
