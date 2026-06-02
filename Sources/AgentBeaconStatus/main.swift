import AgentBeaconCore
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.contains("--help") || arguments.contains("-h") {
    printUsage()
    exit(0)
}

do {
    let command = try GenericStatusCommandParser.parse(arguments)

    switch command.action {
    case .doctor:
        runDoctor(fileURL: command.fileURL)
    case .detect:
        runDetect(fileURL: command.fileURL)
    case .connect(let platform):
        try runConnect(platform: platform, fileURL: command.fileURL)
    case .upsert(let task):
        let store = GenericStatusFileStore(fileURL: command.fileURL)
        try store.upsert(
            id: task.id,
            platform: task.platform,
            threadName: task.threadName,
            status: task.status,
            jumpTarget: task.jumpTarget
        )
        print("Updated \(task.platform.rawValue):\(task.id) at \(command.fileURL.path)")
    case .remove(let id, let platform):
        let store = GenericStatusFileStore(fileURL: command.fileURL)
        try store.remove(id: id, platform: platform)
        print("Removed \(platform.rawValue):\(id) from \(command.fileURL.path)")
    }
} catch {
    fputs("AgentBeaconStatus: \(error.localizedDescription)\n\n", stderr)
    printUsage(to: stderr)
    exit(2)
}

private func printUsage(to file: UnsafeMutablePointer<FILE> = stdout) {
    let text = """
    Usage:
      AgentBeaconStatus doctor [--file <path>]
      AgentBeaconStatus detect [--file <path>]
      AgentBeaconStatus connect [--platform <platform>] [--file <path>]
      AgentBeaconStatus upsert --id <id> --name <thread> --status <needs_review|failed|running|completed> [--platform <platform>] [--app <AppName>] [--file <path>]
      AgentBeaconStatus remove --id <id> [--platform <platform>] [--file <path>]

    Defaults:
      --platform generic-cli
      --file ~/.agent-beacon/status.json

    Examples:
      AgentBeaconStatus doctor
      AgentBeaconStatus detect
      AgentBeaconStatus connect
      AgentBeaconStatus connect --platform codex
      AgentBeaconStatus --id build --name "Run tests" --status running --app Terminal
      AgentBeaconStatus --id codex-review --platform codex --name "Codex review" --status needs_review --app Codex
      AgentBeaconStatus remove --id build
    """

    fputs(text + "\n", file)
}

private func runDoctor(fileURL: URL) {
    let statusFileExists = FileManager.default.fileExists(atPath: fileURL.path)
    let runnerURL = findRunnerURL()
    let detector = AgentDetector()
    let results = detector.detect()

    print("Agent Beacon Doctor")
    print("")
    print("Status file:")
    print("  \(fileURL.path) \(statusFileExists ? "exists" : "missing")")
    if !statusFileExists {
        print("  Create it with: make install")
    }
    print("")
    print("Helpers:")
    print("  AgentBeaconStatus: \(CommandLine.arguments.first ?? "AgentBeaconStatus")")
    print("  agent-beacon-run: \(runnerURL?.path ?? "not found")")
    print("  Shims: \(AgentBeaconIntegrationPaths.defaultShimDirectoryURL().path)")
    print("  Shell profile: \(AgentBeaconIntegrationPaths.defaultShellProfileURL().path)")
    print("")

    printDetectionResults(results)

    print("")
    print("Manual trigger:")
    print("  AgentBeaconStatus detect")
    print("  AgentBeaconStatus connect")
    print("")
    print("After connect:")
    print("  Restart your terminal or run: source \(AgentBeaconIntegrationPaths.defaultShellProfileURL().path)")
    print("  Then launch agents normally, for example: codex or claude")
}

private func runDetect(fileURL: URL) {
    print("Agent Beacon Detect")
    print("")
    print("Status file: \(fileURL.path)")
    print("Shims: \(AgentBeaconIntegrationPaths.defaultShimDirectoryURL().path)")
    print("Shell profile: \(AgentBeaconIntegrationPaths.defaultShellProfileURL().path)")
    print("")
    printDetectionResults(AgentDetector().detect())
}

private func runConnect(platform: AgentPlatform?, fileURL: URL) throws {
    guard let runnerURL = findRunnerURL() else {
        throw StatusCLIError.missingRunner
    }

    try GenericStatusFileStore(fileURL: fileURL).ensureDocumentExists()

    let detector = AgentDetector()
    var results = detector.detect()
    if let platform {
        results = results.filter { $0.definition.platform == platform }
    }
    let connectable = results.filter { $0.canAutoConnect }

    let shimInstaller = AgentShimInstaller(
        shimDirectoryURL: AgentBeaconIntegrationPaths.defaultShimDirectoryURL(),
        runnerURL: runnerURL
    )
    let installedShims = try shimInstaller.installShims(for: connectable)

    let profileInstaller = ShellProfileInstaller(
        shimDirectoryURL: AgentBeaconIntegrationPaths.defaultShimDirectoryURL(),
        shellProfileURL: AgentBeaconIntegrationPaths.defaultShellProfileURL()
    )
    let profileChanged = try profileInstaller.ensureShimDirectoryIsFirstInPath()

    print("Agent Beacon Connect")
    print("")
    if installedShims.isEmpty {
        print("No CLI agents were connected.")
    } else {
        print("Installed shims:")
        for shim in installedShims {
            print("  \(shim.platform.rawValue): \(shim.shimPath)")
            print("    real executable: \(shim.realExecutablePath)")
        }
    }

    let skipped = results.filter { $0.isInstalled && !$0.canAutoConnect }
    if !skipped.isEmpty {
        print("")
        print("Detected but not auto-connectable yet:")
        for result in skipped {
            print("  \(result.definition.displayName): app detected, no CLI/API hook found")
        }
    }

    print("")
    print("Shell profile: \(AgentBeaconIntegrationPaths.defaultShellProfileURL().path)")
    print(profileChanged ? "  PATH block added." : "  PATH block already present.")
    print("")
    print("Next step:")
    print("  Restart your terminal or run: source \(AgentBeaconIntegrationPaths.defaultShellProfileURL().path)")
    print("  Then launch supported agents normally. Agent Beacon will track CLI-launched tasks.")
}

private func printDetectionResults(_ results: [AgentDetectionResult]) {
    print("Supported agents:")
    for result in results {
        let state: String
        if result.isAutoConnected {
            state = "connected"
        } else if result.canAutoConnect {
            state = "ready to connect"
        } else if result.isInstalled {
            state = "detected app only"
        } else {
            state = "not installed"
        }

        print("  \(result.definition.displayName) [\(result.definition.platform.rawValue)] - \(state)")
        print("    CLI: \(result.cliPath ?? "not found")")
        print("    App: \(result.appPath ?? "not found")")
        print("    Shim: \(result.shimPath ?? "not applicable")")
    }
}

private func findRunnerURL() -> URL? {
    if let explicit = ProcessInfo.processInfo.environment["AGENT_BEACON_RUN"], !explicit.isEmpty {
        let url = URL(fileURLWithPath: explicit).standardizedFileURL
        if FileManager.default.isExecutableFile(atPath: url.path) {
            return url
        }
    }

    if let executable = CommandLine.arguments.first {
        let besideStatus = URL(fileURLWithPath: executable)
            .deletingLastPathComponent()
            .appendingPathComponent("agent-beacon-run")
            .standardizedFileURL
        if FileManager.default.isExecutableFile(atPath: besideStatus.path) {
            return besideStatus
        }
    }

    for directory in AgentBeaconIntegrationPaths.defaultExecutableSearchPaths() {
        let candidate = URL(fileURLWithPath: directory)
            .appendingPathComponent("agent-beacon-run")
            .standardizedFileURL
        if FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate
        }
    }

    let projectCandidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("scripts/agent-beacon-run")
        .standardizedFileURL
    if FileManager.default.isExecutableFile(atPath: projectCandidate.path) {
        return projectCandidate
    }

    return nil
}

private enum StatusCLIError: LocalizedError {
    case missingRunner

    var errorDescription: String? {
        switch self {
        case .missingRunner:
            "agent-beacon-run was not found. Run make install or set AGENT_BEACON_RUN=/path/to/agent-beacon-run."
        }
    }
}
