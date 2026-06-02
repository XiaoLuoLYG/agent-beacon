# Roadmap

Agent Beacon should stay small: a local status light for agent work, not a full task system.

## v0.1

The first preview focuses on the daily loop:

- macOS menu bar app.
- Four-light status panel.
- Hover expansion into a compact task list.
- Generic JSON status file.
- `AgentBeaconStatus` helper command.
- `agent-beacon-run` command wrapper.
- Local shims for supported CLI tools.
- Codex local session metadata.
- Cursor local composer header metadata.
- Click-to-activate app targets.
- DMG release for local installation.

## v0.2

The next useful step is reliability and installation polish:

- Signed and notarized macOS package.
- Cleaner first-run connection flow.
- Better status diagnostics in the app menu.
- Launch-at-login option.
- Improved terminal/window matching.
- More precise `needs_review` support where tools expose stable events.

## Later

Longer-term work should only happen if it keeps the product quiet and local:

- Cursor Background Agent API support when stable.
- Claude Code hook-based status support.
- Gemini CLI status hooks when available.
- Optional notifications for yellow and red transitions.
- Plugin guidance for third-party status sources.
- Keyboard shortcut to focus the most urgent task.
