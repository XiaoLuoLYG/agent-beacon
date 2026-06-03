# Agent Beacon v0.1.0

Agent Beacon is ready for its first private preview.

This release is for people who run several coding agents at once and want one quiet macOS menu bar indicator for what needs attention.

## What's Included

- macOS menu bar app with the four-light status panel.
- Expanded task list with platform icon, task name, and status indicator.
- Local CLI shims for supported Codex, Claude Code, Cursor, and Gemini CLI commands.
- `AgentBeaconStatus` helper for diagnostics, connection, and manual status updates.
- `agent-beacon-run` helper for wrapping existing commands.
- Codex local session metadata support.
- Cursor local composer header metadata support.
- Optional desktop floating strip.
- Branded macOS app icon.
- Local release package with app, CLI helpers, screenshots, install guide, privacy notes, and license.

## Download

Download:

```text
AgentBeacon-macOS.dmg
AgentBeacon-macOS.zip
```

Open the DMG, drag `Agent Beacon.app` to Applications, open the app, then restart your terminal after connecting installed agents. Use the zip when you also want the CLI helpers, screenshots, docs, and install script in one folder.

## macOS Notice

This preview DMG is unsigned. On first launch, right-click the app, choose `Open`, and confirm the macOS prompt.

## Privacy

Agent Beacon is local-first. It reads local status records and small metadata needed to show task names and states. It does not display conversation bodies, source files, terminal output, or logs.
