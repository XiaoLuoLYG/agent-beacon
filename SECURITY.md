# Security

Agent Beacon is a local macOS utility. Security reports are welcome, especially around local file handling, helper scripts, shell profile updates, and task status parsing.

## Reporting

Please open a private GitHub security advisory for the repository if available. If that is not available, open a minimal issue that says you have a security report to share without posting exploit details publicly.

## Scope

Useful reports include:

- a way to make Agent Beacon execute an unexpected command,
- unsafe handling of local status files,
- unsafe shell profile modification,
- privacy leaks from conversation bodies, terminal output, logs, or source files,
- package or installer behavior that weakens macOS safety expectations.

## Non-Scope

Agent Beacon cannot control how third-party agent tools store their own sessions or logs. Reports should focus on Agent Beacon's code, package, helpers, or documented installation flow.
