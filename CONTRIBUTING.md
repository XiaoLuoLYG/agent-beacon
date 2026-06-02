# Contributing

Thanks for helping make Agent Beacon better.

The project is intentionally small. Contributions should protect that shape: a quiet local utility, not a dashboard or task manager.

## Local Setup

```bash
git clone https://github.com/XiaoLuoLYG/agent-beacon.git
cd agent-beacon
make test
make run
```

## Before Opening a Pull Request

Run:

```bash
make test
make package
```

Keep changes focused. A good pull request usually changes one behavior, one adapter, or one piece of documentation.

## Product Boundaries

Agent Beacon should:

- keep the default UI compact,
- avoid reading private conversation bodies or logs,
- prefer explicit status signals over guesses,
- keep integrations local-first where possible,
- stay useful without becoming another project-management surface.

## Code Style

- Use SwiftUI for visual composition.
- Use AppKit only where macOS window/menu behavior requires it.
- Keep adapter logic out of UI views.
- Keep user-facing copy plain and practical.
