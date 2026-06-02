import AgentBeaconCore
import Foundation

public enum SnapshotFixture {
    public static let tasks: [AgentTask] = [
        task(
            id: "snapshot-review",
            platform: .claudeCode,
            threadName: "Review generated README changes",
            status: .needsReview,
            updatedAt: "2026-06-01T00:00:03Z"
        ),
        task(
            id: "snapshot-failed",
            platform: .cursor,
            threadName: "Fix failing macOS build",
            status: .failed,
            updatedAt: "2026-06-01T00:00:02Z"
        ),
        task(
            id: "snapshot-running",
            platform: .codex,
            threadName: "Run adapter smoke tests",
            status: .running,
            updatedAt: "2026-06-01T00:00:01Z"
        ),
        task(
            id: "snapshot-completed",
            platform: .geminiCLI,
            threadName: "Draft UI spec",
            status: .completed,
            updatedAt: "2026-06-01T00:00:00Z"
        )
    ]

    private static func task(
        id: String,
        platform: AgentPlatform,
        threadName: String,
        status: AgentTaskStatus,
        updatedAt: String
    ) -> AgentTask {
        let formatter = ISO8601DateFormatter()
        return AgentTask(
            id: id,
            platform: platform,
            threadName: threadName,
            status: status,
            jumpTarget: JumpTarget(type: .app, value: "Terminal"),
            updatedAt: formatter.date(from: updatedAt) ?? Date(timeIntervalSince1970: 0)
        )
    }
}
