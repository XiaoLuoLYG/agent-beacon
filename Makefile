.PHONY: run demo status test build snapshot package install open-app clean

run:
	swift run AgentBeacon

demo:
	swift run AgentBeacon --status-file examples/generic-agent-status.json

status:
	swift run AgentBeaconStatus --id demo --name "Demo running task" --status running --app Terminal

test:
	swift test

build:
	swift build

snapshot:
	swift run AgentBeaconSnapshot --output dist/snapshots

package:
	bash scripts/package-app.sh

install:
	bash scripts/install-local.sh

open-app: package
	open "dist/Agent Beacon.app"

clean:
	rm -rf .build dist
