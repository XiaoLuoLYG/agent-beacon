import Foundation

public struct TaskReadState: Codable, Equatable, Sendable {
    public var version: Int
    public var readTasks: [String: Date]

    public init(version: Int = 1, readTasks: [String: Date] = [:]) {
        self.version = version
        self.readTasks = readTasks
    }

    public func isRead(_ task: AgentTask) -> Bool {
        guard let readAt = readTasks[task.id] else {
            return false
        }
        return readAt >= task.updatedAt
    }

    public mutating func markRead(_ task: AgentTask, at date: Date = Date()) {
        readTasks[task.id] = max(date, task.updatedAt)
    }
}

public struct TaskReadStateStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL = Self.defaultFileURL()) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agent-beacon/read-state.json")
    }

    public func load() throws -> TaskReadState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return TaskReadState()
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TaskReadState.self, from: data)
    }

    public func markRead(_ task: AgentTask, at date: Date = Date()) throws {
        var state = (try? load()) ?? TaskReadState()
        state.markRead(task, at: date)
        try save(state)
    }

    public func save(_ state: TaskReadState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }
}

public struct TaskVisibilityFilter: Sendable {
    public var readState: TaskReadState
    public var now: Date
    public var completedRetentionInterval: TimeInterval

    public init(
        readState: TaskReadState = TaskReadState(),
        now: Date = Date(),
        completedRetentionInterval: TimeInterval = 86_400
    ) {
        self.readState = readState
        self.now = now
        self.completedRetentionInterval = completedRetentionInterval
    }

    public func filter(_ tasks: [AgentTask]) -> [AgentTask] {
        tasks.filter(isVisible)
    }

    public func isVisible(_ task: AgentTask) -> Bool {
        guard task.status == .completed else {
            return true
        }

        if readState.isRead(task) {
            return false
        }

        return task.updatedAt >= now.addingTimeInterval(-completedRetentionInterval)
    }
}
