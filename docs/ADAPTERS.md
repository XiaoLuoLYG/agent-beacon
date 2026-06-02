# Agent Beacon Adapter Specification

## 1. Adapter Goal

Adapters connect external agent platforms to Agent Beacon without making the core app platform-specific. Each adapter converts its source into the unified task model.

The core app must be able to run with only the Generic CLI adapter enabled.

Current support:

- v0.1 ships the Generic CLI adapter, Codex local session adapter, `AgentBeaconStatus`, `agent-beacon-run`, `detect`, `connect`, and `doctor`.
- `connect` installs CLI shims into `~/.agent-beacon/shims` and adds that directory to the shell profile PATH.
- The shim path automatically connects future CLI-launched Codex, Claude Code, Cursor, Gemini CLI, and Generic CLI tasks without requiring the user to wrap every command manually.
- Agent Beacon reads Codex local session metadata from `~/.codex/session_index.jsonl` and tail status markers from files under `~/.codex/sessions` when available. It does not parse or display conversation bodies.
- Codex sessions whose metadata says `thread_source: "subagent"` are ignored so worker/reviewer helper sessions do not pollute the main task list.
- Completed Codex tasks are visible only while they are recently active, currently within 24 hours, unless future unread metadata support is added.
- Agent Beacon keeps its own read-state file at `~/.agent-beacon/read-state.json`; clicking a completed row marks it read and hides it from the menu panel list.
- Agent Beacon does not attach to other private app internals. GUI-only internal threads require a stable vendor API, hook, or explicit status export before per-thread status can be trusted.
- Deep native Claude Code, Cursor, and Gemini CLI adapters remain follow-up work for richer states such as `needs_review`.

## 2. Unified Output

Each adapter outputs task records with this shape:

```json
{
  "id": "stable-task-id",
  "platform": "codex | claude-code | cursor | gemini-cli | generic-cli",
  "threadName": "Fix login bug",
  "status": "needs_review | failed | running | completed",
  "jumpTarget": {
    "type": "app | window | url",
    "value": "Codex"
  },
  "updatedAt": "2026-05-31T12:00:00Z"
}
```

The UI uses only `platform`, `threadName`, and `status`. The other fields support identity, sorting, freshness, and click-to-jump.

## 3. Generic CLI Adapter

The Generic CLI adapter reads a local JSON file. This gives any CLI agent a simple integration path without a custom plugin.

### 3.1 CLI Shim Auto-Connect

The install flow runs:

```bash
AgentBeaconStatus connect
```

This command:

- Detects supported agent CLIs in `PATH`, common Homebrew locations, user-local bins, and known app-bundled CLI paths.
- Generates same-name shims such as `codex`, `claude`, and `cursor` under `~/.agent-beacon/shims`.
- Adds `~/.agent-beacon/shims` to the front of the shell profile PATH.
- Leaves the real agent executable untouched.
- Records `running` before delegation and `completed` or `failed` after the real process exits.

This is the first automatic integration layer. It is reliable because the user still launches the normal CLI command, but Agent Beacon owns the small process wrapper around it.

Expected file shape:

```json
{
  "version": 1,
  "tasks": [
    {
      "id": "local-build-agent",
      "platform": "generic-cli",
      "threadName": "Build release notes",
      "status": "running",
      "jumpTarget": {
        "type": "app",
        "value": "Terminal"
      },
      "updatedAt": "2026-05-31T12:00:00Z"
    }
  ]
}
```

Rules:

- Unknown statuses are ignored.
- Missing `id`, `platform`, `threadName`, `status`, or `updatedAt` makes the task invalid.
- Missing `jumpTarget` is allowed, but the row cannot jump to a specific target.
- The adapter should poll or file-watch the configured path.

## 4. Codex Adapter

Codex support starts with local session/thread evidence when available.

Current sources:

- `~/.codex/session_index.jsonl` for stable thread id, thread name, and update time.
- `~/.codex/sessions/**/*.jsonl` tail markers for completion and blocked status.
- Session metadata `thread_source` to filter out subagent helper threads.
- Session file modification time to identify recent activity.

Mapping:

- Events are read in order from the recent session tail; the latest effective state wins.
- `task_started`, `user_message`, and active response events -> `running`.
- Explicit user-intervention metadata such as `request_user_input`, `waiting_for_user`, `approval_required`, or permission/authorization requests -> `needs_review`.
- `thread_goal_updated` with `blocked` -> `failed` unless a later user turn starts.
- `task_complete` -> `completed` unless the same turn contains an unresolved blocked goal or user-intervention request.
- Natural-language questions in assistant message text are not parsed; without a structured marker, the adapter must not infer `needs_review` from conversation body content.

Jump target:

- Prefer a Codex thread or app target when available.
- Otherwise activate the Codex desktop app or relevant terminal.

Important constraint:

- Do not infer completion from a window still being open.
- Prefer explicit session evidence such as completion markers and recent activity timestamps.
- Keep the UI limited to platform icon, thread name, and one state light.
- Do not display subagent helper sessions as user-facing tasks.

## 5. Claude Code Adapter

Claude Code support should prefer explicit local integration points.

Likely sources:

- Hooks.
- Status line output.
- Session metadata.
- Local status files generated by a small companion hook script.

Mapping:

- Stop/completion hook -> `completed`.
- Running tool or active assistant turn -> `running`.
- Approval prompt, permission prompt, or user input wait -> `needs_review`.
- Error hook, failed command, stale session, or abnormal exit -> `failed`.

Jump target:

- Prefer the terminal app/window running the session.
- If precise terminal window matching is unavailable, activate the terminal app.

## 6. Cursor Adapter

Cursor support has two tracks.

Track A: Background Agent API

- Use Cursor's Background Agent status API when configured.
- Map remote agent status into unified task states.
- Use URL jump targets when the API provides a web or app target.

Track B: Local IDE fallback

- Read Cursor's local `composer.composerHeaders` metadata from `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`.
- Use composer id, name, workspace, update time, unread state, and blocking-action flags.
- Do not read `agent-transcripts` message bodies or editor buffer content.
- If a Cursor task exists only in remote Background Agent state and is not reflected in local composer headers, provide application-level jump only until Cursor exposes a stable API.

Mapping:

- `hasBlockingPendingActions`, `hasPendingPlan`, or unread composer output -> `needs_review`.
- Recently updated composer in a workspace with an active `agent-exec` helper -> `running`.
- Recent read composer with no active execution signal -> `completed`.
- Archived, draft, and stale read composers are hidden.

Jump target:

- Prefer Cursor app activation.
- Prefer URL target for background agent detail when available.

## 7. Gemini CLI Adapter

Gemini CLI support should begin with conservative local signals.

Likely sources:

- CLI process presence.
- Session/log metadata when available.
- Optional status file written by wrapper scripts.

Mapping:

- Process active and recently updated -> `running`.
- Explicit success marker -> `completed`.
- Prompt waiting for user input or approval -> `needs_review`.
- Error exit, stale process, or explicit failure marker -> `failed`.

Jump target:

- Prefer the terminal app/window running Gemini CLI.
- Fallback to the terminal app.

## 8. Adapter Health

Adapter health is separate from task status.

Examples:

- Cursor API token missing.
- Generic JSON file not found.
- Claude hook not installed.
- Codex session directory unavailable.

Adapter health should be visible in settings or diagnostics, not in the main task list unless it creates a real task-level failure.
