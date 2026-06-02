# Architecture

Agent Beacon is a local macOS app with five main pieces:

```text
local agent metadata + status files
        |
        v
adapter loaders
        |
        v
unified task store
        |
        v
menu bar panel
        |
        v
window/app activation
```

## Modules

### AgentBeaconCore

Owns the shared model and local data loading.

- `AgentTask` defines the task shape used by every source.
- `GenericStatusLoader` reads explicit JSON status records.
- `GenericStatusFileStore` writes status records used by helper commands.
- `CodexSessionLoader` reads Codex local session metadata and recent state markers.
- `CursorComposerLoader` reads Cursor local composer header metadata.
- `TaskAggregator` calculates counts and display order.
- `TaskReadStateStore` remembers completed tasks the user has already dismissed.
- `AgentDetector`, `AgentShimInstaller`, and `ShellProfileInstaller` connect supported local CLI tools.

### AgentBeaconUI

Owns reusable SwiftUI views.

- `AggregateBarView` renders the four-light count row.
- `BeaconTopSurfaceView` renders the compact and expanded menu panel.
- `TaskListView` renders the minimal task list.
- `MenuBarTemplateIconFactory` creates the menu bar icon mask.

### AgentBeaconApp

Owns the macOS app shell.

- `MenuBarController` manages the status item and context menu.
- `TopPanelController` manages the default menu bar panel.
- `FloatingPanelController` manages the optional desktop strip.
- `AgentBeaconAppDelegate` loads status snapshots and wires actions.
- `WindowFocusService` activates apps, windows, or URLs.

### AgentBeaconStatus

Command-line helper for status updates, diagnostics, detection, and connection.

### AgentBeaconSnapshot

Build-time helper for generating screenshots used in release packages.

## State Flow

1. The app resolves the configured status file.
2. It loads explicit JSON tasks.
3. If local agent history is enabled, it also loads Codex and Cursor local metadata.
4. Tasks are merged by stable id.
5. Completed tasks that were read or are too old are filtered.
6. Counts and rows update in the menu bar panel.

The app polls on a short interval instead of running a background service.

## CLI Shim Flow

`AgentBeaconStatus connect` writes shims to:

```text
~/.agent-beacon/shims
```

For example, a generated `codex` shim:

1. creates a task id,
2. writes status `running`,
3. runs the real Codex executable,
4. writes `completed` or `failed`,
5. exits with the original command's exit code.

The real CLI executable is not modified.

## Privacy Boundaries

Adapters should read the smallest useful status signal.

Agent Beacon should not display:

- conversation bodies,
- source code,
- terminal logs,
- prompts,
- model responses,
- command output.

When a platform does not expose stable task status, the adapter should provide only the states it can prove.
