# Privacy

Agent Beacon is designed as a local status light, not a monitoring tool.

## What It Reads

Agent Beacon may read:

- task records from `~/.agent-beacon/status.json`,
- Codex session index metadata from `~/.codex/session_index.jsonl`,
- recent Codex session event markers from `~/.codex/sessions`,
- Cursor composer header metadata from Cursor's local `globalStorage/state.vscdb`,
- process names needed to detect active Cursor agent execution,
- local app and CLI paths needed for connection and jump targets.

These sources are used to show a task name, platform, status, and jump target.

## What It Does Not Display

Agent Beacon does not display:

- conversation bodies,
- source files,
- terminal output,
- command logs,
- prompts,
- tool-call arguments,
- model responses,
- API keys or credentials.

Codex session files are scanned for recent structured state markers. Message text is not used to infer status.

## Local Files Created

Agent Beacon creates local files under:

```text
~/.agent-beacon
```

Common files include:

```text
~/.agent-beacon/status.json
~/.agent-beacon/read-state.json
~/.agent-beacon/shims/*
~/.agent-beacon/assets/platform-icons/*
```

It may also add a PATH block to `~/.zshrc` or `~/.bash_profile` so shell commands resolve through the local shims.

## Network

Agent Beacon does not need a network service to run. The current app reads local files and local process/app state.

## Third-Party Tools

Agent Beacon does not control how Codex, Claude Code, Cursor, Gemini CLI, or other tools store their own data. It only reads the small local metadata needed for status display when that metadata is available.
