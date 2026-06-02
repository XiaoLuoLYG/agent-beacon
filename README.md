# Agent Beacon

Agent Beacon is a small macOS menu bar app for people who run more than one coding agent at a time.

It gives you one quiet place to answer the practical question: which agent needs attention right now?

Click the menu bar icon to see four status lights:

```text
completed | needs review | failed | running
```

Hover the panel to see the matching tasks. Click a task to jump back to its app.

Agent Beacon stays local. It does not create agent tasks, manage chats, read source files, or show conversation logs.

## Download

The current macOS package is published on the GitHub Releases page as:

```text
AgentBeacon-macOS.zip
```

After downloading:

1. Unzip the package.
2. Run `./install.sh` from the unzipped folder.
3. Open `~/Applications/Agent Beacon.app`.
4. Restart your terminal.

After that, launch supported CLI agents normally. Agent Beacon records their status in the background and updates the menu bar panel.

> The first release is unsigned. If macOS blocks the app, right-click `Agent Beacon.app`, choose `Open`, then confirm once.

## Supported Sources

Agent Beacon currently reads:

- CLI-launched Codex, Claude Code, Cursor, Gemini CLI, and generic commands through local shims.
- Codex local session metadata from `~/.codex/session_index.jsonl` and `~/.codex/sessions`.
- Cursor composer header metadata from Cursor's local `globalStorage/state.vscdb`.
- Explicit status updates written to `~/.agent-beacon/status.json`.

For tools without a stable local API or hook, Agent Beacon only shows states it can verify. It will not guess task status from private UI or chat contents.

## Daily Use

The menu bar icon opens the top panel.

- Green: completed tasks.
- Yellow: tasks waiting for review, input, permission, or approval.
- Red: failed or blocked tasks.
- Running: active tasks.

The expanded list keeps each row simple: platform icon, task name, and one status indicator.

Right-click the menu bar icon to:

- connect installed agents,
- open the local status file,
- hide or show Codex/Cursor local history,
- show the optional desktop floating strip,
- quit Agent Beacon.

## CLI Helpers

The release package includes two helper commands:

```text
AgentBeaconStatus
agent-beacon-run
```

Install them into `~/.local/bin` if you want to update task status from scripts.

The release `install.sh` does this automatically.

Check your local setup:

```bash
AgentBeaconStatus doctor
```

Reconnect shims after installing a new agent:

```bash
AgentBeaconStatus connect
```

Wrap any long-running command:

```bash
agent-beacon-run --platform generic-cli --id tests --name "Project tests" -- npm test
```

The wrapper marks the task as `running`, runs the command, then marks it `completed` or `failed` based on the exit code.

## Build From Source

Requirements:

- macOS 13 or newer
- Xcode command line tools
- Swift 6 toolchain

Run the app:

```bash
make run
```

Run with sample data:

```bash
make demo
```

Run tests:

```bash
make test
```

Build the app and release zip:

```bash
make package
```

Install locally from source:

```bash
make install
```

## Privacy

Agent Beacon is local-first. It reads small status records and metadata needed to show task names and states. It does not display message bodies, terminal output, source files, or logs.

More detail is available in [Privacy](docs/PRIVACY.md).

## Documentation

- [Install Guide](docs/INSTALL.md)
- [Quickstart](docs/QUICKSTART.md)
- [Adapter Notes](docs/ADAPTERS.md)
- [Architecture](docs/ARCHITECTURE.md)
- [UI Notes](docs/UI_SPEC.md)
- [Roadmap](docs/ROADMAP.md)

## License

Agent Beacon is released under the [MIT License](LICENSE).
