import Foundation

public struct GenericStatusLoader: Sendable {
    private let decoder: JSONDecoder

    public init() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func decode(_ data: Data) throws -> [AgentTask] {
        let document = try decoder.decode(GenericStatusDocument.self, from: data)
        return document.tasks.compactMap { task in
            guard
                let platform = AgentPlatform(rawValue: task.platform),
                let status = AgentTaskStatus(rawValue: task.status)
            else {
                return nil
            }

            return AgentTask(
                id: "\(platform.rawValue):\(task.id)",
                platform: platform,
                threadName: task.threadName,
                status: status,
                jumpTarget: task.jumpTarget,
                updatedAt: task.updatedAt
            )
        }
    }

    public func load(from url: URL) throws -> [AgentTask] {
        let data = try Data(contentsOf: url)
        return try decode(data)
    }
}

private struct GenericStatusDocument: Decodable {
    var version: Int
    var tasks: [GenericStatusTask]
}

private struct GenericStatusTask: Decodable {
    var id: String
    var platform: String
    var threadName: String
    var status: String
    var jumpTarget: JumpTarget?
    var updatedAt: Date
}

