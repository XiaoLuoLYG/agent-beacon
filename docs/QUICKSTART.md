# Quickstart

## Use The Release Package

Download `AgentBeacon-macOS.zip` from GitHub Releases, unzip it, then run:

```bash
./install.sh
```

Open:

```bash
open "$HOME/Applications/Agent Beacon.app"
```

The first preview release is unsigned. If macOS blocks it, right-click the app, choose `Open`, and confirm once.

## Connect Installed Agents

Open Agent Beacon, then right-click the menu bar icon and choose:

```text
Connect Installed Agents
```

This installs local shims for supported CLI tools when they are found on your Mac:

```text
codex
claude
cursor
gemini
```

Restart your terminal. Then launch agents normally. The menu bar panel will update as CLI-launched tasks run and finish.

## Check Setup

If you installed the helper commands into `~/.local/bin`, run:

```bash
AgentBeaconStatus doctor
AgentBeaconStatus detect
```

If a command is connected, `which` should point to Agent Beacon's shim directory:

```bash
which codex
```

Expected prefix:

```text
~/.agent-beacon/shims
```

## Read The Panel

Click the menu bar icon to open the four-light panel.

```text
green | yellow | red | running
```

- Green: completed.
- Yellow: waiting for review, input, approval, or permission.
- Red: failed or blocked.
- Running: active work.

Hover the panel to show task rows. Click a row to jump back to the matching app.

## Use A Custom Command

Wrap a long-running command:

```bash
agent-beacon-run --platform generic-cli --id tests --name "Project tests" -- npm test
```

The wrapper marks the task `running`, runs the command, then marks it `completed` or `failed`.

## Update Status Manually

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

## Build From Source

Run:

```bash
make test
make run
```

Run with sample data:

```bash
make demo
```

Build a release package:

```bash
make package
```

Install locally from source:

```bash
make install
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

The read-state file is:

```text
~/.agent-beacon/read-state.json
```

No cloud account or server is required.
