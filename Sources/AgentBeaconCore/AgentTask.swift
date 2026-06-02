import Foundation

public enum AgentPlatform: String, Codable, CaseIterable, Sendable {
    case codex
    case claudeCode = "claude-code"
    case cursor
    case geminiCLI = "gemini-cli"
    case genericCLI = "generic-cli"

    public var displayName: String {
        switch self {
        case .codex:
            "Codex"
        case .claudeCode:
            "Claude Code"
        case .cursor:
            "Cursor"
        case .geminiCLI:
            "Gemini CLI"
        case .genericCLI:
            "Generic CLI"
        }
    }

    public var badgeText: String {
        switch self {
        case .codex:
            "CX"
        case .claudeCode:
            "CL"
        case .cursor:
            "CU"
        case .geminiCLI:
            "GM"
        case .genericCLI:
            "$"
        }
    }
}

public enum AgentTaskStatus: String, Codable, CaseIterable, Sendable {
    case needsReview = "needs_review"
    case failed
    case running
    case completed

    public var attentionRank: Int {
        switch self {
        case .needsReview:
            0
        case .failed:
            1
        case .running:
            2
        case .completed:
            3
        }
    }
}

public enum JumpTargetType: String, Codable, Sendable {
    case app
    case window
    case url
}

public struct JumpTarget: Codable, Equatable, Sendable {
    public var type: JumpTargetType
    public var value: String

    public init(type: JumpTargetType, value: String) {
        self.type = type
        self.value = value
    }
}

public struct AgentTask: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var platform: AgentPlatform
    public var threadName: String
    public var status: AgentTaskStatus
    public var jumpTarget: JumpTarget?
    public var updatedAt: Date

    public init(
        id: String,
        platform: AgentPlatform,
        threadName: String,
        status: AgentTaskStatus,
        jumpTarget: JumpTarget?,
        updatedAt: Date
    ) {
        self.id = id
        self.platform = platform
        self.threadName = threadName
        self.status = status
        self.jumpTarget = jumpTarget
        self.updatedAt = updatedAt
    }
}

public struct AggregateCounts: Equatable, Sendable {
    public var needsReview: Int
    public var failed: Int
    public var running: Int
    public var completed: Int

    public init(needsReview: Int = 0, failed: Int = 0, running: Int = 0, completed: Int = 0) {
        self.needsReview = needsReview
        self.failed = failed
        self.running = running
        self.completed = completed
    }
}

