import Foundation
import Testing
@testable import AgentBeaconCore

@Test func taskVisibilityFilterKeepsActiveTasksAndRecentUnreadCompletions() throws {
    let now = try #require(ISO8601DateFormatter().date(from: "2026-06-01T02:30:00Z"))
    let recent = now.addingTimeInterval(-60 * 60)
    let old = now.addingTimeInterval(-60 * 60 * 25)

    let tasks = [
        AgentTask.fixture(id: "old-running", status: .running, updatedAt: old),
        AgentTask.fixture(id: "recent-complete", status: .completed, updatedAt: recent),
        AgentTask.fixture(id: "old-complete", status: .completed, updatedAt: old)
    ]

    let visible = TaskVisibilityFilter(now: now).filter(tasks)

    #expect(visible.map(\.id) == ["old-running", "recent-complete"])
}

@Test func taskVisibilityFilterHidesReadCompletedTasks() throws {
    let now = try #require(ISO8601DateFormatter().date(from: "2026-06-01T02:30:00Z"))
    let updatedAt = now.addingTimeInterval(-60)
    let task = AgentTask.fixture(id: "codex:done", status: .completed, updatedAt: updatedAt)
    let readState = TaskReadState(readTasks: ["codex:done": now])

    let visible = TaskVisibilityFilter(readState: readState, now: now).filter([task])

    #expect(visible.isEmpty)
}

private extension AgentTask {
    static func fixture(id: String, status: AgentTaskStatus, updatedAt: Date) -> AgentTask {
        AgentTask(
            id: id,
            platform: .codex,
            threadName: id,
            status: status,
            jumpTarget: JumpTarget(type: .app, value: "Codex"),
            updatedAt: updatedAt
        )
    }
}
