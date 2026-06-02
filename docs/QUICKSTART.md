# Quickstart

## Start

Download `AgentBeacon-macOS.dmg`, open it, and drag `Agent Beacon.app` to Applications.

Open the app from Applications. If macOS blocks the first launch, right-click the app and choose `Open`.

Look for the Agent Beacon icon in the macOS menu bar. Full-screen apps can hide the menu bar until you move the pointer to the top edge of the screen.

## Connect Agents

Right-click the menu bar icon and choose:

```text
Connect Installed Agents
```

Agent Beacon installs local shims for supported CLI tools it finds:

```text
codex
claude
cursor
gemini
```

Restart your terminal. Then launch agents normally.

## Read The Panel

Click the menu bar icon to open the four-light panel:

```text
green | yellow | red | blue
```

- Green: completed.
- Yellow: waiting for review, input, approval, or permission.
- Red: failed or blocked.
- Blue: running.

Hover the panel to show task rows. Click a row to jump back to the matching app.

## Custom Tasks

Source installs include helper commands for manual status updates:

```bash
AgentBeaconStatus --id build --name "Run tests" --status running --app Terminal
AgentBeaconStatus --id build --name "Run tests" --status completed --app Terminal
```

Supported status values:

```text
needs_review
failed
running
completed
```

## Local Data

Agent Beacon stores local files under:

```text
~/.agent-beacon
```

The default status file is:

```text
~/.agent-beacon/status.json
```

No cloud account or server is required.
