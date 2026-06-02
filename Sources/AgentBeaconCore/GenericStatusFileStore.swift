import Foundation

public struct GenericStatusFileStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL = Self.defaultFileURL()) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agent-beacon/status.json")
    }

    public func ensureDocumentExists() throws {
        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        try write(GenericStatusWritableDocument(version: 1, tasks: []))
    }

    public func upsert(
        id: String,
        platform: AgentPlatform,
        threadName: String,
        status: AgentTaskStatus,
        jumpTarget: JumpTarget?,
        updatedAt: Date = Date()
    ) throws {
        var document = try readDocumentIfPresent()
        let task = GenericStatusWritableTask(
            id: id,
            platform: platform.rawValue,
            threadName: threadName,
            status: status.rawValue,
            jumpTarget: jumpTarget,
            updatedAt: updatedAt
        )

        if let index = document.tasks.firstIndex(where: { $0.id == id && $0.platform == platform.rawValue }) {
            document.tasks[index] = task
        } else {
            document.tasks.append(task)
        }

        try write(document)
    }

    public func remove(id: String, platform: AgentPlatform) throws {
        var document = try readDocumentIfPresent()
        document.tasks.removeAll { $0.id == id && $0.platform == platform.rawValue }
        try write(document)
    }

    private func readDocumentIfPresent() throws -> GenericStatusWritableDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return GenericStatusWritableDocument(version: 1, tasks: [])
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GenericStatusWritableDocument.self, from: data)
    }

    private func write(_ document: GenericStatusWritableDocument) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        try data.write(to: fileURL, options: [.atomic])
    }
}

private struct GenericStatusWritableDocument: Codable {
    var version: Int
    var tasks: [GenericStatusWritableTask]
}

private struct GenericStatusWritableTask: Codable {
    var id: String
    var platform: String
    var threadName: String
    var status: String
    var jumpTarget: JumpTarget?
    var updatedAt: Date
}
