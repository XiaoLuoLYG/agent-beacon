# Product Notes

Agent Beacon is a small local companion for people who run several coding agents at once.

The product has one job: show which tasks are done, waiting, failed, or still running.

## Product Shape

Agent Beacon lives in the macOS menu bar. Clicking the icon opens a compact four-light panel. Hovering the panel shows a minimal task list.

The default experience should feel quiet enough to leave running all day.

## What It Is

- A local menu bar status utility.
- A compact attention layer for agent work.
- A bridge between local agent tools and one shared status model.
- A fast way to jump back to the app that needs attention.

## What It Is Not

- Not a task manager.
- Not a chat client.
- Not a log viewer.
- Not an orchestration dashboard.
- Not a replacement for Codex, Claude Code, Cursor, Gemini CLI, or custom agent tools.

## Core States

Agent Beacon only shows four states:

```text
completed
needs_review
failed
running
```

Every integration must map into those states before reaching the UI.

## Default UI

The default UI is a macOS menu bar icon. Clicking it opens:

```text
[green count] [yellow count] [red count] [running count]
```

The order is fixed:

1. completed,
2. needs review,
3. failed,
4. running.

The expanded list shows only:

```text
[platform icon] [task name] [status indicator]
```

No logs, timestamps, file paths, token counts, or long explanations are shown in the main surface.

## Privacy Principle

Agent Beacon should prefer explicit status signals and local metadata. It should not read or display private conversation bodies, terminal output, source files, or logs.

If a tool does not expose a stable status signal, Agent Beacon should say less instead of guessing.
