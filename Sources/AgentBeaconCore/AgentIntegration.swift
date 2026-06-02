import Foundation

public struct SupportedAgentDefinition: Equatable, Sendable {
    public var platform: AgentPlatform
    public var displayName: String
    public var cliNames: [String]
    public var appBundleNames: [String]
    public var appRelativeExecutablePaths: [String]
    public var defaultJumpApp: String

    public init(
        platform: AgentPlatform,
        displayName: String,
        cliNames: [String],
        appBundleNames: [String],
        appRelativeExecutablePaths: [String] = [],
        defaultJumpApp: String
    ) {
        self.platform = platform
        self.displayName = displayName
        self.cliNames = cliNames
        self.appBundleNames = appBundleNames
        self.appRelativeExecutablePaths = appRelativeExecutablePaths
        self.defaultJumpApp = defaultJumpApp
    }

    public var primaryCLIName: String? {
        cliNames.first
    }
}

public enum SupportedAgentRegistry {
    public static let all: [SupportedAgentDefinition] = [
        SupportedAgentDefinition(
            platform: .codex,
            displayName: "Codex",
            cliNames: ["codex"],
            appBundleNames: ["Codex.app"],
            appRelativeExecutablePaths: ["Contents/Resources/codex"],
            defaultJumpApp: "Codex"
        ),
        SupportedAgentDefinition(
            platform: .claudeCode,
            displayName: "Claude Code",
            cliNames: ["claude"],
            appBundleNames: ["Claude.app"],
            defaultJumpApp: "Terminal"
        ),
        SupportedAgentDefinition(
            platform: .cursor,
            displayName: "Cursor",
            cliNames: ["cursor"],
            appBundleNames: ["Cursor.app"],
            appRelativeExecutablePaths: ["Contents/Resources/app/bin/cursor"],
            defaultJumpApp: "Cursor"
        ),
        SupportedAgentDefinition(
            platform: .geminiCLI,
            displayName: "Gemini CLI",
            cliNames: ["gemini"],
            appBundleNames: ["Gemini.app"],
            defaultJumpApp: "Terminal"
        )
    ]
}

public struct AgentDetectionResult: Equatable, Sendable {
    public var definition: SupportedAgentDefinition
    public var cliPath: String?
    public var appPath: String?
    public var shimPath: String?
    public var isShimInstalled: Bool
    public var isShellProfileConfigured: Bool

    public init(
        definition: SupportedAgentDefinition,
        cliPath: String?,
        appPath: String?,
        shimPath: String?,
        isShimInstalled: Bool,
        isShellProfileConfigured: Bool
    ) {
        self.definition = definition
        self.cliPath = cliPath
        self.appPath = appPath
        self.shimPath = shimPath
        self.isShimInstalled = isShimInstalled
        self.isShellProfileConfigured = isShellProfileConfigured
    }

    public var isInstalled: Bool {
        cliPath != nil || appPath != nil
    }

    public var canAutoConnect: Bool {
        cliPath != nil
    }

    public var isAutoConnected: Bool {
        isShimInstalled && isShellProfileConfigured
    }
}

public enum AgentBeaconIntegrationPaths {
    public static func defaultShimDirectoryURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        let home = environment["HOME"] ?? NSHomeDirectory()
        return URL(fileURLWithPath: home)
            .appendingPathComponent(".agent-beacon", isDirectory: true)
            .appendingPathComponent("shims", isDirectory: true)
            .standardizedFileURL
    }

    public static func defaultShellProfileURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        let home = environment["HOME"] ?? NSHomeDirectory()
        let shell = environment["SHELL"] ?? ""
        let filename: String
        filename = shell.hasSuffix("bash") ? ".bash_profile" : ".zshrc"
        return URL(fileURLWithPath: home).appendingPathComponent(filename).standardizedFileURL
    }

    public static func defaultExecutableSearchPaths(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String] {
        let home = environment["HOME"] ?? NSHomeDirectory()
        let pathEntries = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        return unique(pathEntries + [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ])
    }

    public static func defaultApplicationSearchPaths(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String] {
        let home = environment["HOME"] ?? NSHomeDirectory()
        return [
            "/Applications",
            "\(home)/Applications",
            "/System/Applications"
        ]
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values where !value.isEmpty {
            if seen.insert(value).inserted {
                result.append(value)
            }
        }
        return result
    }
}

public struct AgentDetector {
    public var definitions: [SupportedAgentDefinition]
    public var executableSearchPaths: [String]
    public var applicationSearchPaths: [String]
    public var shimDirectoryURL: URL
    public var shellProfileURL: URL

    public init(
        definitions: [SupportedAgentDefinition] = SupportedAgentRegistry.all,
        executableSearchPaths: [String] = AgentBeaconIntegrationPaths.defaultExecutableSearchPaths(),
        applicationSearchPaths: [String] = AgentBeaconIntegrationPaths.defaultApplicationSearchPaths(),
        shimDirectoryURL: URL = AgentBeaconIntegrationPaths.defaultShimDirectoryURL(),
        shellProfileURL: URL = AgentBeaconIntegrationPaths.defaultShellProfileURL()
    ) {
        self.definitions = definitions
        self.executableSearchPaths = executableSearchPaths
        self.applicationSearchPaths = applicationSearchPaths
        self.shimDirectoryURL = shimDirectoryURL
        self.shellProfileURL = shellProfileURL
    }

    public func detect() -> [AgentDetectionResult] {
        let profileInstaller = ShellProfileInstaller(
            shimDirectoryURL: shimDirectoryURL,
            shellProfileURL: shellProfileURL
        )
        let isShellConfigured = profileInstaller.isShimDirectoryConfigured()

        return definitions.map { definition in
            let appPath = findApplicationBundle(for: definition)
            let cliPath = findExecutable(named: definition.cliNames)
                ?? findBundledExecutable(for: definition, appPath: appPath)
            let shimPath = definition.primaryCLIName.map {
                shimDirectoryURL.appendingPathComponent($0).standardizedFileURL.path
            }
            let isShimInstalled = shimPath.map {
                FileManager.default.isExecutableFile(atPath: $0)
            } ?? false
            return AgentDetectionResult(
                definition: definition,
                cliPath: cliPath,
                appPath: appPath,
                shimPath: shimPath,
                isShimInstalled: isShimInstalled,
                isShellProfileConfigured: isShellConfigured
            )
        }
    }

    private func findExecutable(named names: [String]) -> String? {
        for name in names {
            if name.contains("/") {
                let url = URL(fileURLWithPath: expandHome(in: name)).standardizedFileURL
                if isRealExecutable(url.path) {
                    return url.path
                }
                continue
            }

            for directory in executableSearchPaths {
                let candidate = URL(fileURLWithPath: expandHome(in: directory))
                    .appendingPathComponent(name)
                    .standardizedFileURL
                if isRealExecutable(candidate.path) {
                    return candidate.path
                }
            }
        }

        return nil
    }

    private func findApplicationBundle(for definition: SupportedAgentDefinition) -> String? {
        for directory in applicationSearchPaths {
            for bundleName in definition.appBundleNames {
                let candidate = URL(fileURLWithPath: expandHome(in: directory))
                    .appendingPathComponent(bundleName)
                    .standardizedFileURL
                if FileManager.default.fileExists(atPath: candidate.path) {
                    return candidate.path
                }
            }
        }

        return nil
    }

    private func findBundledExecutable(for definition: SupportedAgentDefinition, appPath: String?) -> String? {
        guard let appPath else { return nil }
        let appURL = URL(fileURLWithPath: appPath)
        for relativePath in definition.appRelativeExecutablePaths {
            let candidate = appURL.appendingPathComponent(relativePath).standardizedFileURL.path
            if isRealExecutable(candidate) {
                return candidate
            }
        }
        return nil
    }

    private func isRealExecutable(_ path: String) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: path) else { return false }
        guard !isPath(path, inside: shimDirectoryURL.standardizedFileURL.path) else {
            return false
        }
        return !isAgentBeaconGeneratedShim(path)
    }

    private func isPath(_ path: String, inside directory: String) -> Bool {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let standardizedDirectory = URL(fileURLWithPath: directory).standardizedFileURL.path
        return standardizedPath == standardizedDirectory || standardizedPath.hasPrefix(standardizedDirectory + "/")
    }

    private func isAgentBeaconGeneratedShim(_ path: String) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else {
            return false
        }
        defer { try? handle.close() }

        let data = (try? handle.read(upToCount: 4096)) ?? Data()
        guard let prefix = String(data: data, encoding: .utf8) else {
            return false
        }

        return prefix.contains("# Generated by Agent Beacon.")
    }

    private func expandHome(in path: String) -> String {
        guard path == "~" || path.hasPrefix("~/") else { return path }
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        if path == "~" {
            return home
        }
        return home + path.dropFirst()
    }
}

public struct AgentShimInstallResult: Equatable, Sendable {
    public var platform: AgentPlatform
    public var shimPath: String
    public var realExecutablePath: String

    public init(platform: AgentPlatform, shimPath: String, realExecutablePath: String) {
        self.platform = platform
        self.shimPath = shimPath
        self.realExecutablePath = realExecutablePath
    }
}

public struct AgentShimInstaller {
    public var shimDirectoryURL: URL
    public var runnerURL: URL

    public init(shimDirectoryURL: URL, runnerURL: URL) {
        self.shimDirectoryURL = shimDirectoryURL
        self.runnerURL = runnerURL
    }

    public func installShims(for results: [AgentDetectionResult]) throws -> [AgentShimInstallResult] {
        try FileManager.default.createDirectory(at: shimDirectoryURL, withIntermediateDirectories: true)

        var installed: [AgentShimInstallResult] = []
        for result in results {
            guard let cliName = result.definition.primaryCLIName, let cliPath = result.cliPath else {
                continue
            }

            let shimURL = shimDirectoryURL.appendingPathComponent(cliName).standardizedFileURL
            let script = Self.shimScript(
                definition: result.definition,
                realExecutablePath: cliPath,
                runnerPath: runnerURL.standardizedFileURL.path
            )
            try script.write(to: shimURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: shimURL.path)
            installed.append(
                AgentShimInstallResult(
                    platform: result.definition.platform,
                    shimPath: shimURL.path,
                    realExecutablePath: cliPath
                )
            )
        }

        return installed
    }

    public static func shimScript(
        definition: SupportedAgentDefinition,
        realExecutablePath: String,
        runnerPath: String
    ) -> String {
        let platform = shellSingleQuote(definition.platform.rawValue)
        let jumpApp = shellSingleQuote(definition.defaultJumpApp)
        let realExecutable = shellSingleQuote(realExecutablePath)
        let runner = shellSingleQuote(runnerPath)

        return """
        #!/usr/bin/env bash
        set -euo pipefail

        # Generated by Agent Beacon. Edit with: AgentBeaconStatus connect
        REAL_AGENT=\(realExecutable)
        DEFAULT_AGENT_BEACON_RUN=\(runner)
        AGENT_BEACON_RUN="${AGENT_BEACON_RUN:-$DEFAULT_AGENT_BEACON_RUN}"

        if [[ ! -x "$REAL_AGENT" ]]; then
          echo "Agent Beacon shim: real agent executable not found: $REAL_AGENT" >&2
          exit 127
        fi

        if [[ ! -x "$AGENT_BEACON_RUN" ]]; then
          echo "Agent Beacon shim: agent-beacon-run not found: $AGENT_BEACON_RUN" >&2
          exit 127
        fi

        task_suffix="$(date +%Y%m%d%H%M%S)-$$"
        task_id="${AGENT_BEACON_TASK_ID:-\(definition.platform.rawValue)-${task_suffix}}"
        project_name="$(basename "$PWD")"
        task_name="${AGENT_BEACON_TASK_NAME:-\(definition.displayName) ${project_name}}"

        exec "$AGENT_BEACON_RUN" --platform \(platform) --id "$task_id" --name "$task_name" --app \(jumpApp) -- "$REAL_AGENT" "$@"
        """
    }
}

public struct ShellProfileInstaller {
    public static let beginMarker = "# >>> Agent Beacon shims >>>"
    public static let endMarker = "# <<< Agent Beacon shims <<<"

    public var shimDirectoryURL: URL
    public var shellProfileURL: URL

    public init(shimDirectoryURL: URL, shellProfileURL: URL) {
        self.shimDirectoryURL = shimDirectoryURL
        self.shellProfileURL = shellProfileURL
    }

    public func ensureShimDirectoryIsFirstInPath() throws -> Bool {
        try FileManager.default.createDirectory(at: shimDirectoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: shellProfileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let existing = (try? String(contentsOf: shellProfileURL, encoding: .utf8)) ?? ""
        let block = Self.profileBlock(for: shimDirectoryURL.path)
        let next: String

        if let begin = existing.range(of: Self.beginMarker),
           let end = existing.range(of: Self.endMarker, range: begin.upperBound..<existing.endIndex) {
            let replacementRange = begin.lowerBound..<end.upperBound
            next = existing.replacingCharacters(in: replacementRange, with: block.trimmingCharacters(in: .newlines))
        } else {
            let separator = existing.isEmpty || existing.hasSuffix("\n") ? "" : "\n"
            next = existing + separator + block
        }

        guard next != existing else { return false }
        try next.write(to: shellProfileURL, atomically: true, encoding: .utf8)
        return true
    }

    public func isShimDirectoryConfigured() -> Bool {
        guard let profile = try? String(contentsOf: shellProfileURL, encoding: .utf8) else {
            return false
        }
        return profile.contains(Self.beginMarker)
            && profile.contains(Self.endMarker)
            && profile.contains(shimDirectoryURL.path)
    }

    public static func profileBlock(for shimPath: String) -> String {
        """
        \(beginMarker)
        export PATH="\(shimPath):$PATH"
        \(endMarker)
        """
    }
}

private func shellSingleQuote(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}
