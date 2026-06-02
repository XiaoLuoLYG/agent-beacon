# Install Agent Beacon

Agent Beacon can be used from the release zip or built from source.

## Install From Release Zip

1. Download `AgentBeacon-macOS.zip` from GitHub Releases.
2. Unzip it.
3. Run:

```bash
./install.sh
```

4. Open:

```bash
open "$HOME/Applications/Agent Beacon.app"
```

5. Restart your terminal.

The release also includes:

```text
bin/AgentBeaconStatus
bin/agent-beacon-run
```

The release installer copies those helpers into `~/.local/bin`. To do the same step manually:

```bash
mkdir -p "$HOME/.local/bin"
cp bin/AgentBeaconStatus "$HOME/.local/bin/"
cp bin/agent-beacon-run "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/AgentBeaconStatus" "$HOME/.local/bin/agent-beacon-run"
```

If `~/.local/bin` is not already on your `PATH`, add it in your shell profile.

## First Launch On macOS

The first preview release is unsigned. macOS may show a warning because the app was downloaded from the internet.

To open it:

1. Right-click `Agent Beacon.app`.
2. Choose `Open`.
3. Confirm the prompt.

You should only need to do this once.

## Connect CLI Agents

Agent Beacon connects supported CLI tools by installing small wrapper scripts into:

```text
~/.agent-beacon/shims
```

The wrappers keep the original command names, such as:

```text
codex
claude
cursor
gemini
```

They record status before and after the real command runs. The original agent executables are not modified.

Run:

```bash
AgentBeaconStatus connect
```

Then restart your terminal or run:

```bash
source "$HOME/.zshrc"
```

Check that the shim is first:

```bash
which codex
which claude
which cursor
which gemini
```

Connected commands should resolve under:

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

Install locally:

```bash
make install
```

## Uninstall

Quit Agent Beacon, then remove:

```bash
rm -rf "$HOME/Applications/Agent Beacon.app"
rm -f "$HOME/.local/bin/AgentBeaconStatus"
rm -f "$HOME/.local/bin/agent-beacon-run"
rm -rf "$HOME/.agent-beacon/shims"
```

You can also remove Agent Beacon's local data:

```bash
rm -rf "$HOME/.agent-beacon"
```

Finally, remove the Agent Beacon PATH block from `~/.zshrc` or `~/.bash_profile`:

```text
# >>> Agent Beacon shims >>>
export PATH="$HOME/.agent-beacon/shims:$PATH"
# <<< Agent Beacon shims <<<
```
