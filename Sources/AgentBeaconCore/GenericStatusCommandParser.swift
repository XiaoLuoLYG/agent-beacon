import Foundation

public struct GenericStatusCommand: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case upsert(GenericStatusUpsert)
        case remove(id: String, platform: AgentPlatform)
        case doctor
        case detect
        case connect(platform: AgentPlatform?)
    }

    public var fileURL: URL
    public var action: Action

    public init(fileURL: URL, action: Action) {
        self.fileURL = fileURL
        self.action = action
    }
}

public struct GenericStatusUpsert: Equatable, Sendable {
    public var id: String
    public var platform: AgentPlatform
    public var threadName: String
    public var status: AgentTaskStatus
    public var jumpTarget: JumpTarget?

    public init(
        id: String,
        platform: AgentPlatform,
        threadName: String,
        status: AgentTaskStatus,
        jumpTarget: JumpTarget?
    ) {
        self.id = id
        self.platform = platform
        self.threadName = threadName
        self.status = status
        self.jumpTarget = jumpTarget
    }
}

public enum GenericStatusCommandParser {
    public enum ParseError: Error, Equatable, LocalizedError {
        case missingRequired(String)
        case missingValue(String)
        case unknownPlatform(String)
        case unknownStatus(String)
        case unknownOption(String)

        public var errorDescription: String? {
            switch self {
            case .missingRequired(let name):
                "Missing required argument: \(name)"
            case .missingValue(let name):
                "Missing value for argument: \(name)"
            case .unknownPlatform(let value):
                "Unknown platform: \(value)"
            case .unknownStatus(let value):
                "Unknown status: \(value)"
            case .unknownOption(let value):
                "Unknown option: \(value)"
            }
        }
    }

    public static func parse(_ arguments: [String]) throws -> GenericStatusCommand {
        var mutableArguments = arguments
        let mode: String
        if mutableArguments.first == "detect" {
            mode = "detect"
            mutableArguments.removeFirst()
        } else if mutableArguments.first == "connect" {
            mode = "connect"
            mutableArguments.removeFirst()
        } else if mutableArguments.first == "doctor" {
            mode = "doctor"
            mutableArguments.removeFirst()
        } else if mutableArguments.first == "remove" {
            mode = "remove"
            mutableArguments.removeFirst()
        } else {
            mode = "upsert"
            if mutableArguments.first == "upsert" {
                mutableArguments.removeFirst()
            }
        }

        let values = try parseOptions(mutableArguments)
        let fileURL = values["file"].map { URL(fileURLWithPath: $0).standardizedFileURL }
            ?? GenericStatusFileStore.defaultFileURL()

        if mode == "doctor" {
            return GenericStatusCommand(fileURL: fileURL, action: .doctor)
        }
        if mode == "detect" {
            return GenericStatusCommand(fileURL: fileURL, action: .detect)
        }
        if mode == "connect" {
            let platform = try values["platform"].map(parsePlatform)
            return GenericStatusCommand(fileURL: fileURL, action: .connect(platform: platform))
        }

        let platform = try parsePlatform(values["platform"] ?? AgentPlatform.genericCLI.rawValue)

        guard let id = values["id"], !id.isEmpty else {
            throw ParseError.missingRequired("--id")
        }

        if mode == "remove" {
            return GenericStatusCommand(fileURL: fileURL, action: .remove(id: id, platform: platform))
        }

        guard let threadName = values["name"], !threadName.isEmpty else {
            throw ParseError.missingRequired("--name")
        }
        guard let statusValue = values["status"], !statusValue.isEmpty else {
            throw ParseError.missingRequired("--status")
        }
        guard let status = AgentTaskStatus(rawValue: statusValue) else {
            throw ParseError.unknownStatus(statusValue)
        }

        let jumpTarget = parseJumpTarget(values)
        let task = GenericStatusUpsert(
            id: id,
            platform: platform,
            threadName: threadName,
            status: status,
            jumpTarget: jumpTarget
        )
        return GenericStatusCommand(fileURL: fileURL, action: .upsert(task))
    }

    private static func parseOptions(_ arguments: [String]) throws -> [String: String] {
        let knownOptions = Set(["--id", "--platform", "--name", "--status", "--app", "--window", "--url", "--file"])
        var values: [String: String] = [:]
        var index = 0

        while index < arguments.count {
            let option = arguments[index]
            guard knownOptions.contains(option) else {
                throw ParseError.unknownOption(option)
            }
            guard arguments.indices.contains(index + 1) else {
                throw ParseError.missingValue(option)
            }
            values[String(option.dropFirst(2))] = arguments[index + 1]
            index += 2
        }

        return values
    }

    private static func parsePlatform(_ value: String) throws -> AgentPlatform {
        guard let platform = AgentPlatform(rawValue: value) else {
            throw ParseError.unknownPlatform(value)
        }
        return platform
    }

    private static func parseJumpTarget(_ values: [String: String]) -> JumpTarget? {
        if let app = values["app"] {
            return JumpTarget(type: .app, value: app)
        }
        if let window = values["window"] {
            return JumpTarget(type: .window, value: window)
        }
        if let url = values["url"] {
            return JumpTarget(type: .url, value: url)
        }
        return nil
    }
}
