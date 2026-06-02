# Support

If Agent Beacon is not showing a task you expect, start with:

```bash
AgentBeaconStatus doctor
AgentBeaconStatus detect
```

For CLI-launched agents, also check:

```bash
which codex
which claude
which cursor
which gemini
```

The path should begin with:

```text
~/.agent-beacon/shims
```

If it does not, restart your terminal or run:

```bash
source "$HOME/.zshrc"
```

Open an issue with:

- macOS version,
- Agent Beacon version,
- the command you ran,
- output from `AgentBeaconStatus doctor`,
- whether the task was launched from CLI, Codex, Cursor, or a custom status file.

Please do not include private chat transcripts, source code, API keys, or terminal logs unless you have reviewed and redacted them.
