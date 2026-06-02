import Foundation
import Testing
@testable import AgentBeaconCore

@Test func genericStatusLoaderDecodesValidTasksAndSkipsUnknownStatuses() throws {
    let json = """
    {
      "version": 1,
      "tasks": [
        {
          "id": "needs-review",
          "platform": "generic-cli",
          "threadName": "Approve file edit",
          "status": "needs_review",
          "jumpTarget": { "type": "app", "value": "Terminal" },
          "updatedAt": "2026-05-31T12:00:00Z"
        },
        {
          "id": "unknown",
          "platform": "generic-cli",
          "threadName": "Unknown state",
          "status": "paused",
          "updatedAt": "2026-05-31T12:00:01Z"
        }
      ]
    }
    """

    let tasks = try GenericStatusLoader().decode(Data(json.utf8))

    #expect(tasks.count == 1)
    #expect(tasks[0].id == "generic-cli:needs-review")
    #expect(tasks[0].platform == .genericCLI)
    #expect(tasks[0].threadName == "Approve file edit")
    #expect(tasks[0].status == .needsReview)
    #expect(tasks[0].jumpTarget == JumpTarget(type: .app, value: "Terminal"))
}

@Test func taskStoreComputesAggregateCountsForAllFourStatuses() {
    let tasks: [AgentTask] = [
        .fixture(id: "yellow", status: .needsReview),
        .fixture(id: "red", status: .failed),
        .fixture(id: "running-1", status: .running),
        .fixture(id: "running-2", status: .running),
        .fixture(id: "green", status: .completed)
    ]

    let counts = TaskAggregator.counts(for: tasks)

    #expect(counts.needsReview == 1)
    #expect(counts.failed == 1)
    #expect(counts.running == 2)
    #expect(counts.completed == 1)
}

@Test func taskAggregatorSortsByAttentionPriorityThenRecentUpdates() throws {
    let formatter = ISO8601DateFormatter()
    let older = try #require(formatter.date(from: "2026-05-31T12:00:00Z"))
    let newer = try #require(formatter.date(from: "2026-05-31T12:05:00Z"))

    let tasks: [AgentTask] = [
        .fixture(id: "completed", status: .completed, updatedAt: newer),
        .fixture(id: "failed-old", status: .failed, updatedAt: older),
        .fixture(id: "running", status: .running, updatedAt: newer),
        .fixture(id: "review-old", status: .needsReview, updatedAt: older),
        .fixture(id: "review-new", status: .needsReview, updatedAt: newer)
    ]

    let sorted = TaskAggregator.sortedForDisplay(tasks)

    #expect(sorted.map(\.id) == [
        "review-new",
        "review-old",
        "failed-old",
        "running",
        "completed"
    ])
}

private extension AgentTask {
    static func fixture(
        id: String,
        status: AgentTaskStatus,
        updatedAt: Date = Date(timeIntervalSince1970: 0)
    ) -> AgentTask {
        AgentTask(
            id: id,
            platform: .genericCLI,
            threadName: id,
            status: status,
            jumpTarget: JumpTarget(type: .app, value: "Terminal"),
            updatedAt: updatedAt
        )
    }
}
