# Install Agent Beacon

## One-Line Preview Install

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/XiaoLuoLYG/agent-beacon/main/scripts/install-from-release.sh | bash
```

The installer downloads the latest release ZIP, installs `Agent Beacon.app` under `~/Applications`, installs helper commands under `~/.local/bin`, connects supported agent CLIs, removes macOS quarantine from the installed app, and opens Agent Beacon.

Agent Beacon is a menu bar app. If you do not see the icon after launch, first check whether your current app is full screen or the macOS menu bar is hidden. Move the pointer to the top edge of the screen or leave full screen, then look near the right side of the menu bar.

## Install From DMG

1. Download `AgentBeacon-macOS.dmg` from GitHub Releases.
2. Open the DMG.
3. Drag `Agent Beacon.app` to `Applications`.
4. Open Agent Beacon from Applications.
5. Right-click the menu bar icon and choose `Connect Installed Agents`.
6. Restart your terminal.

The preview DMG is unsigned. If macOS blocks the first launch, right-click `Agent Beacon.app`, choose `Open`, then confirm the prompt. For the smoother preview path, use the one-line installer above.

## Connect CLI Agents

Agent Beacon connects supported CLI tools by installing local shims into:

```text
~/.agent-beacon/shims
```

The wrappers keep normal command names:

```text
codex
claude
cursor
gemini
```

They record status before and after the real command runs. The original agent executables are not modified.

After connecting, restart your terminal or run:

```bash
source "$HOME/.zshrc"
```

Check that a connected command resolves under Agent Beacon's shim directory:

```bash
which codex
```

Expected prefix:

```text
~/.agent-beacon/shims
```

## Build From Source

Requirements:

- macOS 13 or newer
- Xcode command line tools
- Swift 6 toolchain

Clone and test:

```bash
git clone https://github.com/XiaoLuoLYG/agent-beacon.git
cd agent-beacon
make test
```

Run:

```bash
make run
```

Package:

```bash
make package
```

Install locally from source, including helper commands:

```bash
make install
```

## Uninstall

Quit Agent Beacon, then remove:

```bash
rm -rf "$HOME/Applications/Agent Beacon.app"
rm -rf "/Applications/Agent Beacon.app"
rm -rf "$HOME/.agent-beacon/shims"
```

You can also remove Agent Beacon's local data:

```bash
rm -rf "$HOME/.agent-beacon"
```

If you installed from source, also remove:

```bash
rm -f "$HOME/.local/bin/AgentBeaconStatus"
rm -f "$HOME/.local/bin/agent-beacon-run"
```

Finally, remove the Agent Beacon PATH block from `~/.zshrc` or `~/.bash_profile`:

```text
# >>> Agent Beacon shims >>>
export PATH="$HOME/.agent-beacon/shims:$PATH"
# <<< Agent Beacon shims <<<
```
