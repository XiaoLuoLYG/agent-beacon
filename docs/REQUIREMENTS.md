# Behavior Guide

This guide describes the behavior Agent Beacon should preserve as it evolves.

## Menu Bar Surface

- The app starts as a macOS menu bar utility.
- The menu bar icon is monochrome and template-style.
- Clicking the icon opens a compact top panel.
- The compact panel shows one row with four status lights.
- Count `0` remains visible.
- The default panel does not show labels, logs, file paths, or task details.

## Expanded Task List

- Hovering the opened panel expands the task list.
- Moving away closes the panel after a short delay.
- Each task row shows platform icon, task name, and a single status indicator.
- Long task names truncate cleanly.
- Clicking a row activates the configured app, window, or URL target.
- Clicking a completed row marks it read so it can disappear from the list.

## Optional Desktop Strip

Agent Beacon still includes an optional desktop floating strip.

- It is off by default.
- It can be toggled from the menu bar context menu.
- It is draggable.
- It remembers position.
- It stays within the visible screen.

## Local Agent History

Codex and Cursor local history can be shown or hidden from the menu bar.

When enabled:

- Codex records come from local session metadata.
- Cursor records come from local composer header metadata.
- Agent Beacon does not display conversation bodies.
- Subagent helper sessions are hidden.
- Old read completions are filtered out.

## CLI Connection

`AgentBeaconStatus connect` installs local shims under:

```text
~/.agent-beacon/shims
```

The shim directory is added to the front of the shell PATH. When the user launches a supported CLI command, the shim records status and delegates to the real executable.

## Diagnostics

`AgentBeaconStatus doctor` should explain:

- where the status file is,
- where helpers are installed,
- where shims are installed,
- which supported agents were detected,
- whether shell profile configuration is present.

Diagnostics should be useful without exposing private task content.
