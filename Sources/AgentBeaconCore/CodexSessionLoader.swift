import Foundation

public struct CodexSessionLoader: Sendable {
    public var indexURL: URL
    public var sessionsDirectoryURL: URL
    public var archivedSessionsDirectoryURL: URL
    public var includeArchivedSessions: Bool
    public var maxTasks: Int
    public var completionScanByteLimit: Int

    public init(
        indexURL: URL = Self.defaultIndexURL(),
        sessionsDirectoryURL: URL = Self.defaultSessionsDirectoryURL(),
        archivedSessionsDirectoryURL: URL = Self.defaultArchivedSessionsDirectoryURL(),
        includeArchivedSessions: Bool = false,
        maxTasks: Int = 8,
        completionScanByteLimit: Int = 524_288
    ) {
        self.indexURL = indexURL
        self.sessionsDirectoryURL = sessionsDirectoryURL
        self.archivedSessionsDirectoryURL = archivedSessionsDirectoryURL
        self.includeArchivedSessions = includeArchivedSessions
        self.maxTasks = maxTasks
        self.completionScanByteLimit = completionScanByteLimit
    }

    public static func defaultIndexURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/session_index.jsonl")
    }

    public static func defaultSessionsDirectoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    public static func defaultArchivedSessionsDirectoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/archived_sessions", isDirectory: true)
    }

    public func load() throws -> [AgentTask] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            return []
        }

        let records = try loadIndexRecords()
            .sorted { $0.updatedAt > $1.updatedAt }

        guard !records.isEmpty else {
            return []
        }

        var tasks: [AgentTask] = []
        let sessionFiles = try sessionFileURLs()

        for record in records {
            guard tasks.count < maxTasks else { break }
            guard let sessionFileURL = sessionFiles[record.id] else { continue }
            guard isUserVisibleSession(sessionFileURL) else { continue }

            let sessionState = state(for: sessionFileURL)
            let updatedAt = [
                record.updatedAt,
                sessionState.lastActivityAt,
                modificationDate(for: sessionFileURL)
            ]
                .compactMap { $0 }
                .max() ?? record.updatedAt

            tasks.append(
                AgentTask(
                    id: "\(AgentPlatform.codex.rawValue):\(record.id)",
                    platform: .codex,
                    threadName: record.threadName,
                    status: sessionState.status,
                    jumpTarget: JumpTarget(type: .app, value: "Codex"),
                    updatedAt: updatedAt
                )
            )
        }

        return tasks
    }

    private func loadIndexRecords() throws -> [CodexSessionIndexRecord] {
        let data = try Data(contentsOf: indexURL)
        guard let contents = String(data: data, encoding: .utf8) else {
            return []
        }

        let decoder = JSONDecoder()
        return contents
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                guard let lineData = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(CodexSessionIndexRecord.self, from: lineData)
            }
            .filter { !$0.threadName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func sessionFileURLs() throws -> [String: URL] {
        var urlsByID: [String: URL] = [:]
        var directories = [sessionsDirectoryURL]
        if includeArchivedSessions {
            directories.append(archivedSessionsDirectoryURL)
        }

        for directory in directories {
            guard FileManager.default.fileExists(atPath: directory.path) else { continue }

            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let url as URL in enumerator where url.pathExtension == "jsonl" {
                guard let id = sessionID(from: url.lastPathComponent), urlsByID[id] == nil else {
                    continue
                }
                urlsByID[id] = url
            }
        }

        return urlsByID
    }

    private func sessionID(from fileName: String) -> String? {
        let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        guard let range = stem.range(of: #"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$"#, options: .regularExpression) else {
            return nil
        }
        return String(stem[range])
    }

    private func isUserVisibleSession(_ sessionFileURL: URL) -> Bool {
        guard let line = try? firstLine(from: sessionFileURL),
              let data = line.data(using: .utf8),
              let metadata = try? JSONDecoder().decode(CodexSessionMetadataEvent.self, from: data)
        else {
            return true
        }

        return metadata.payload?.threadSource != "subagent"
    }

    private func state(for sessionFileURL: URL) -> CodexSessionState {
        guard let tail = try? tailString(from: sessionFileURL) else {
            return CodexSessionState(status: .running, lastActivityAt: nil)
        }

        let decoder = JSONDecoder()
        var status: AgentTaskStatus = .running
        var turnHasBlockedGoal = false
        var turnHasUserInterventionRequest = false
        var lastActivityAt: Date?

        for line in tail.split(whereSeparator: \.isNewline) {
            guard let data = String(line).data(using: .utf8),
                  let event = try? decoder.decode(CodexSessionEvent.self, from: data)
            else {
                continue
            }

            if let timestamp = event.timestamp {
                lastActivityAt = max(lastActivityAt ?? timestamp, timestamp)
            }

            if event.startsNewTurn {
                status = .running
                turnHasBlockedGoal = false
                turnHasUserInterventionRequest = false
                continue
            }

            if event.resolvesUserInterventionRequest {
                status = .running
                turnHasUserInterventionRequest = false
                continue
            }

            if event.requestsUserIntervention {
                status = .needsReview
                turnHasUserInterventionRequest = true
                continue
            }

            if let goalStatus = event.goalStatus {
                switch goalStatus {
                case "active":
                    status = .running
                    turnHasBlockedGoal = false
                    turnHasUserInterventionRequest = false
                case "blocked", "failed":
                    status = .failed
                    turnHasBlockedGoal = true
                    turnHasUserInterventionRequest = false
                case "complete", "completed", "succeeded", "success":
                    status = .completed
                    turnHasBlockedGoal = false
                    turnHasUserInterventionRequest = false
                default:
                    break
                }
                continue
            }

            if event.isTaskComplete {
                if turnHasUserInterventionRequest {
                    status = .needsReview
                } else if turnHasBlockedGoal {
                    status = .failed
                } else {
                    status = .completed
                }
                continue
            }

            if event.isFailedEvent {
                status = .failed
                turnHasBlockedGoal = true
                turnHasUserInterventionRequest = false
                continue
            }

            if event.isRunningActivity {
                status = .running
            }
        }

        return CodexSessionState(status: status, lastActivityAt: lastActivityAt)
    }

    private func firstLine(from url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var data = Data()
        while let byte = try handle.read(upToCount: 1), !byte.isEmpty {
            if byte.first == 10 {
                break
            }
            data.append(byte)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    private func tailString(from url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let fileSize = try handle.seekToEnd()
        let readSize = min(UInt64(completionScanByteLimit), fileSize)
        try handle.seek(toOffset: fileSize - readSize)
        let data = try handle.readToEnd() ?? Data()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func modificationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}

private struct CodexSessionState: Sendable {
    var status: AgentTaskStatus
    var lastActivityAt: Date?
}

private struct CodexSessionIndexRecord: Decodable {
    var id: String
    var threadName: String
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case threadName = "thread_name"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        threadName = try container.decode(String.self, forKey: .threadName)

        let rawDate = try container.decode(String.self, forKey: .updatedAt)
        guard let parsedDate = CodexDateParser.parse(rawDate) else {
            throw DecodingError.dataCorruptedError(
                forKey: .updatedAt,
                in: container,
                debugDescription: "Invalid Codex session index date: \(rawDate)"
            )
        }
        updatedAt = parsedDate
    }

}

private enum CodexDateParser {
    static func parse(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}

private struct CodexSessionMetadataEvent: Decodable {
    var payload: Payload?

    struct Payload: Decodable {
        var threadSource: String?

        enum CodingKeys: String, CodingKey {
            case threadSource = "thread_source"
        }
    }
}

private struct CodexSessionEvent: Decodable {
    var timestamp: Date?
    var type: String
    var payload: Payload?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case type
        case payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        payload = try container.decodeIfPresent(Payload.self, forKey: .payload)

        if let rawTimestamp = try container.decodeIfPresent(String.self, forKey: .timestamp) {
            timestamp = CodexDateParser.parse(rawTimestamp)
        } else {
            timestamp = nil
        }
    }

    struct Payload: Decodable {
        var type: String?
        var name: String?
        var role: String?
        var status: String?
        var subtype: String?
        var goal: Goal?
    }

    struct Goal: Decodable {
        var status: String?
    }
}

private extension CodexSessionEvent {
    var payloadType: String {
        payload?.type?.lowercased() ?? ""
    }

    var goalStatus: String? {
        payload?.goal?.status?.lowercased()
    }

    var startsNewTurn: Bool {
        if type == "turn_context" {
            return true
        }

        if payloadType == "task_started" || payloadType == "user_message" {
            return true
        }

        return type == "response_item" && payloadType == "message" && payload?.role == "user"
    }

    var isTaskComplete: Bool {
        type == "task_complete" || payloadType == "task_complete"
    }

    var isFailedEvent: Bool {
        let failureTypes: Set<String> = [
            "turn_aborted",
            "task_failed",
            "error",
            "failed"
        ]
        return failureTypes.contains(payloadType)
    }

    var requestsUserIntervention: Bool {
        let requestTypes: Set<String> = [
            "approval_request",
            "authorization_request",
            "confirmation_request",
            "needs_review",
            "permission_request",
            "requires_action",
            "user_input_requested",
            "waiting_for_approval",
            "waiting_for_authorization",
            "waiting_for_confirmation",
            "waiting_for_permission",
            "waiting_for_user",
            "waiting_for_user_input"
        ]

        let requestStatuses: Set<String> = [
            "approval_required",
            "awaiting_user",
            "needs_review",
            "pending_approval",
            "requires_action",
            "requires_approval",
            "waiting_for_approval",
            "waiting_for_user"
        ]

        if requestTypes.contains(payloadType) {
            return true
        }

        if let status = payload?.status?.lowercased(), requestStatuses.contains(status) {
            return true
        }

        guard type == "response_item", payloadType == "function_call" else {
            return false
        }

        switch payload?.name?.lowercased() {
        case "request_user_input", "request_plugin_install":
            return true
        default:
            return false
        }
    }

    var resolvesUserInterventionRequest: Bool {
        type == "response_item" && payloadType == "function_call_output"
    }

    var isRunningActivity: Bool {
        if startsNewTurn {
            return true
        }

        if type == "response_item" {
            let activeResponseTypes: Set<String> = [
                "custom_tool_call",
                "custom_tool_call_output",
                "function_call",
                "function_call_output",
                "image_generation_call",
                "message",
                "reasoning",
                "tool_search_call",
                "tool_search_output",
                "web_search_call"
            ]
            return activeResponseTypes.contains(payloadType)
        }

        if type == "event_msg" {
            let activeEventTypes: Set<String> = [
                "agent_message",
                "context_compacted",
                "image_generation_end",
                "item_completed",
                "mcp_tool_call_end",
                "patch_apply_end",
                "thread_rolled_back",
                "web_search_end"
            ]
            return activeEventTypes.contains(payloadType)
        }

        return false
    }
}
