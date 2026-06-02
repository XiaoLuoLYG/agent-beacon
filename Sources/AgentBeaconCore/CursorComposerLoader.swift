import Foundation

public struct CursorComposerLoader: Sendable {
    public var globalStorageDatabaseURL: URL
    public var recentRetentionInterval: TimeInterval
    public var runningFreshnessInterval: TimeInterval
    public var maxTasks: Int

    public init(
        globalStorageDatabaseURL: URL = Self.defaultGlobalStorageDatabaseURL(),
        recentRetentionInterval: TimeInterval = 86_400,
        runningFreshnessInterval: TimeInterval = 2 * 60 * 60,
        maxTasks: Int = 8
    ) {
        self.globalStorageDatabaseURL = globalStorageDatabaseURL
        self.recentRetentionInterval = recentRetentionInterval
        self.runningFreshnessInterval = runningFreshnessInterval
        self.maxTasks = maxTasks
    }

    public static func defaultGlobalStorageDatabaseURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }

    public func load(now: Date = Date()) throws -> [AgentTask] {
        guard FileManager.default.fileExists(atPath: globalStorageDatabaseURL.path) else {
            return []
        }

        let data = try composerHeadersData()
        guard !data.isEmpty else {
            return []
        }

        return try decode(
            data,
            activeWorkspaceNames: Self.activeWorkspaceNames(),
            now: now
        )
    }

    public func decode(
        _ data: Data,
        activeWorkspaceNames: Set<String>,
        now: Date = Date()
    ) throws -> [AgentTask] {
        let document = try JSONDecoder().decode(CursorComposerHeadersDocument.self, from: data)
        let cutoff = now.addingTimeInterval(-recentRetentionInterval)

        return document.allComposers
            .compactMap { header -> AgentTask? in
                guard let id = header.composerId?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !id.isEmpty
                else {
                    return nil
                }

                guard header.isArchived != true, header.isDraft != true else {
                    return nil
                }

                let updatedAt = header.bestUpdatedAt ?? now
                let workspaceName = header.workspaceDisplayName
                let isFresh = updatedAt >= now.addingTimeInterval(-runningFreshnessInterval)
                let isActiveWorkspace = workspaceName.map(activeWorkspaceNames.contains) ?? false
                let isRunning = isFresh && isActiveWorkspace
                let needsReview = header.hasBlockingPendingActions == true || header.hasPendingPlan == true
                let hasUnread = header.hasUnreadMessages == true

                if updatedAt < cutoff && !needsReview && !hasUnread && !isRunning {
                    return nil
                }

                let status: AgentTaskStatus
                if needsReview {
                    status = .needsReview
                } else if isRunning {
                    status = .running
                } else if hasUnread {
                    status = .needsReview
                } else {
                    status = .completed
                }

                return AgentTask(
                    id: "\(AgentPlatform.cursor.rawValue):\(id)",
                    platform: .cursor,
                    threadName: header.displayName,
                    status: status,
                    jumpTarget: JumpTarget(type: .app, value: "Cursor"),
                    updatedAt: updatedAt
                )
            }
            .sorted { lhs, rhs in
                if lhs.status.attentionRank != rhs.status.attentionRank {
                    return lhs.status.attentionRank < rhs.status.attentionRank
                }
                return lhs.updatedAt > rhs.updatedAt
            }
            .prefix(maxTasks)
            .map { $0 }
    }

    public static func activeWorkspaceNames(fromProcessList processList: String) -> Set<String> {
        processList
            .split(whereSeparator: \.isNewline)
            .reduce(into: Set<String>()) { result, line in
                guard let markerRange = line.range(of: "extension-host (agent-exec)") else {
                    return
                }

                var workspace = String(line[markerRange.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let bracketIndex = workspace.firstIndex(of: "[") {
                    workspace = String(workspace[..<bracketIndex])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }

                if !workspace.isEmpty {
                    result.insert(workspace)
                }
            }
    }

    private static func activeWorkspaceNames() -> Set<String> {
        guard let output = try? processOutput(
            executableURL: URL(fileURLWithPath: "/bin/ps"),
            arguments: ["-axo", "command="]
        ) else {
            return []
        }

        return activeWorkspaceNames(fromProcessList: output)
    }

    private func composerHeadersData() throws -> Data {
        let output = try Self.processOutput(
            executableURL: URL(fileURLWithPath: "/usr/bin/sqlite3"),
            arguments: [
                "-readonly",
                globalStorageDatabaseURL.path,
                "select value from ItemTable where key='composer.composerHeaders'"
            ]
        )
        return Data(output.utf8)
    }

    static func processOutput(executableURL: URL, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let outputBuffer = ProcessOutputBuffer()
        let errorBuffer = ProcessOutputBuffer()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading

        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            outputBuffer.append(data)
        }

        errorHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            errorBuffer.append(data)
        }

        try process.run()
        process.waitUntilExit()

        outputHandle.readabilityHandler = nil
        errorHandle.readabilityHandler = nil
        outputBuffer.append(outputHandle.readDataToEndOfFile())
        errorBuffer.append(errorHandle.readDataToEndOfFile())

        if process.terminationStatus != 0 {
            let errorMessage = errorBuffer.string(fallback: "process failed")
            throw CursorComposerLoaderError.processFailed(errorMessage)
        }

        return outputBuffer.string()
    }
}

private final class ProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    func string(fallback: String = "") -> String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return String(data: snapshot, encoding: .utf8) ?? fallback
    }
}

private struct CursorComposerHeadersDocument: Decodable {
    var allComposers: [CursorComposerHeader]
}

private struct CursorComposerHeader: Decodable {
    var composerId: String?
    var name: String?
    var subtitle: String?
    var hasBlockingPendingActions: Bool?
    var hasPendingPlan: Bool?
    var hasUnreadMessages: Bool?
    var isArchived: Bool?
    var isDraft: Bool?
    var lastUpdatedAt: Double?
    var conversationCheckpointLastUpdatedAt: Double?
    var createdAt: Double?
    var workspaceIdentifier: CursorWorkspaceIdentifier?

    var displayName: String {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            return trimmedName
        }

        if let workspaceDisplayName {
            return "Cursor \(workspaceDisplayName)"
        }

        return "Cursor Agent"
    }

    var bestUpdatedAt: Date? {
        let timestamp = lastUpdatedAt
            ?? conversationCheckpointLastUpdatedAt
            ?? createdAt
        guard let timestamp else {
            return nil
        }

        return Date(timeIntervalSince1970: timestamp / 1000)
    }

    var workspaceDisplayName: String? {
        let rawPath = workspaceIdentifier?.uri?.fsPath
            ?? workspaceIdentifier?.uri?.path
            ?? workspaceIdentifier?.id
        guard let rawPath, !rawPath.isEmpty else {
            return nil
        }

        if rawPath == "empty-window" {
            return nil
        }

        return URL(fileURLWithPath: rawPath).lastPathComponent
    }
}

private struct CursorWorkspaceIdentifier: Decodable {
    var id: String?
    var uri: CursorWorkspaceURI?
}

private struct CursorWorkspaceURI: Decodable {
    var fsPath: String?
    var path: String?
}

private enum CursorComposerLoaderError: LocalizedError {
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .processFailed(let message):
            "Cursor composer loader failed: \(message)"
        }
    }
}
