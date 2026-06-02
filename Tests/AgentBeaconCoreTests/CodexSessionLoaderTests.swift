import Foundation
import Testing
@testable import AgentBeaconCore

@Test func codexSessionLoaderReadsThreadNamesAndTailStatuses() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let indexURL = temporaryDirectory.appendingPathComponent("session_index.jsonl")
    let sessionsDirectory = temporaryDirectory.appendingPathComponent("sessions", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

    let runningID = "019e7e2a-9810-7fa0-b6a8-2059fdf4e971"
    let completedID = "019e7e5a-e69a-7da3-ba64-bfce0ee99b2c"
    try """
    {"id":"\(runningID)","thread_name":"设计导入导出入口","updated_at":"2026-05-31T13:13:31.71032Z"}
    {"id":"\(completedID)","thread_name":"评估上线发布差距","updated_at":"2026-05-31T14:05:55.641014Z"}

    """.write(to: indexURL, atomically: true, encoding: .utf8)

    try """
    {"timestamp":"2026-05-31T13:13:17.638Z","type":"session_meta","payload":{"id":"\(runningID)"}}
    {"timestamp":"2026-05-31T13:13:30.000Z","type":"event_msg","payload":{"type":"agent_reasoning"}}
    """.write(
        to: sessionsDirectory.appendingPathComponent("rollout-2026-05-31T21-13-01-\(runningID).jsonl"),
        atomically: true,
        encoding: .utf8
    )
    try """
    {"timestamp":"2026-05-31T14:05:48.688Z","type":"session_meta","payload":{"id":"\(completedID)"}}
    {"timestamp":"2026-05-31T14:12:12.386Z","type":"event_msg","payload":{"type":"task_complete"}}
    """.write(
        to: sessionsDirectory.appendingPathComponent("rollout-2026-05-31T22-05-47-\(completedID).jsonl"),
        atomically: true,
        encoding: .utf8
    )

    let tasks = try CodexSessionLoader(
        indexURL: indexURL,
        sessionsDirectoryURL: sessionsDirectory,
        archivedSessionsDirectoryURL: temporaryDirectory.appendingPathComponent("archived", isDirectory: true),
        maxTasks: 8
    ).load()

    #expect(tasks.map(\.threadName) == ["评估上线发布差距", "设计导入导出入口"])
    #expect(tasks[0].status == .completed)
    #expect(tasks[1].status == .running)
    #expect(tasks[0].platform == .codex)
    #expect(tasks[0].jumpTarget == JumpTarget(type: .app, value: "Codex"))
}

@Test func codexSessionLoaderIgnoresMessageBodyTextWhenReadingStatus() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let indexURL = temporaryDirectory.appendingPathComponent("session_index.jsonl")
    let sessionsDirectory = temporaryDirectory.appendingPathComponent("sessions", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

    let id = "019e80dd-b735-7b63-b95a-11db393425a3"
    try """
    {"id":"\(id)","thread_name":"提出可插拔 Agent 工具方向","updated_at":"2026-06-01T01:48:23.059858Z"}

    """.write(to: indexURL, atomically: true, encoding: .utf8)

    try """
    {"timestamp":"2026-06-01T01:48:23.000Z","type":"session_meta","payload":{"id":"\(id)"}}
    {"timestamp":"2026-06-01T01:48:24.000Z","type":"response_item","payload":{"type":"message","content":"this body says task_complete but it is not a status event"}}
    """.write(
        to: sessionsDirectory.appendingPathComponent("rollout-2026-06-01T09-48-23-\(id).jsonl"),
        atomically: true,
        encoding: .utf8
    )

    let tasks = try CodexSessionLoader(
        indexURL: indexURL,
        sessionsDirectoryURL: sessionsDirectory,
        archivedSessionsDirectoryURL: temporaryDirectory.appendingPathComponent("archived", isDirectory: true),
        maxTasks: 8
    ).load()

    #expect(tasks.count == 1)
    #expect(tasks[0].status == .running)
}

@Test func codexSessionLoaderTreatsNewTurnAfterTerminalStateAsRunning() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let indexURL = temporaryDirectory.appendingPathComponent("session_index.jsonl")
    let sessionsDirectory = temporaryDirectory.appendingPathComponent("sessions", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

    let id = "019e810f-7c83-7a25-bd41-808dc9f75c11"
    try """
    {"id":"\(id)","thread_name":"修复 Agent Beacon 状态刷新","updated_at":"2026-06-01T03:00:00Z"}

    """.write(to: indexURL, atomically: true, encoding: .utf8)

    try """
    {"timestamp":"2026-06-01T02:58:00.000Z","type":"session_meta","payload":{"id":"\(id)","thread_source":"user"}}
    {"timestamp":"2026-06-01T02:59:00.000Z","type":"event_msg","payload":{"type":"thread_goal_updated","goal":{"status":"blocked"}}}
    {"timestamp":"2026-06-01T02:59:01.000Z","type":"event_msg","payload":{"type":"task_complete"}}
    {"timestamp":"2026-06-01T03:00:00.000Z","type":"event_msg","payload":{"type":"task_started"}}
    {"timestamp":"2026-06-01T03:00:00.100Z","type":"event_msg","payload":{"type":"user_message"}}
    """.write(
        to: sessionsDirectory.appendingPathComponent("rollout-2026-06-01T11-00-00-\(id).jsonl"),
        atomically: true,
        encoding: .utf8
    )

    let tasks = try CodexSessionLoader(
        indexURL: indexURL,
        sessionsDirectoryURL: sessionsDirectory,
        archivedSessionsDirectoryURL: temporaryDirectory.appendingPathComponent("archived", isDirectory: true),
        maxTasks: 8
    ).load()

    #expect(tasks.count == 1)
    #expect(tasks[0].status == .running)
}

@Test func codexSessionLoaderKeepsLatestBlockedTurnFailed() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let indexURL = temporaryDirectory.appendingPathComponent("session_index.jsonl")
    let sessionsDirectory = temporaryDirectory.appendingPathComponent("sessions", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

    let id = "019e8110-bdf7-786a-b6c3-884cd09c27cc"
    try """
    {"id":"\(id)","thread_name":"检查失败状态","updated_at":"2026-06-01T03:03:00Z"}

    """.write(to: indexURL, atomically: true, encoding: .utf8)

    try """
    {"timestamp":"2026-06-01T03:02:00.000Z","type":"session_meta","payload":{"id":"\(id)","thread_source":"user"}}
    {"timestamp":"2026-06-01T03:02:01.000Z","type":"event_msg","payload":{"type":"task_started"}}
    {"timestamp":"2026-06-01T03:02:30.000Z","type":"event_msg","payload":{"type":"thread_goal_updated","goal":{"status":"blocked"}}}
    {"timestamp":"2026-06-01T03:02:31.000Z","type":"event_msg","payload":{"type":"task_complete"}}
    """.write(
        to: sessionsDirectory.appendingPathComponent("rollout-2026-06-01T11-03-00-\(id).jsonl"),
        atomically: true,
        encoding: .utf8
    )

    let tasks = try CodexSessionLoader(
        indexURL: indexURL,
        sessionsDirectoryURL: sessionsDirectory,
        archivedSessionsDirectoryURL: temporaryDirectory.appendingPathComponent("archived", isDirectory: true),
        maxTasks: 8
    ).load()

    #expect(tasks.count == 1)
    #expect(tasks[0].status == .failed)
}

@Test func codexSessionLoaderDetectsExplicitUserInputWaitAsNeedsReview() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let indexURL = temporaryDirectory.appendingPathComponent("session_index.jsonl")
    let sessionsDirectory = temporaryDirectory.appendingPathComponent("sessions", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

    let id = "019e8111-f16d-7743-9376-01502c0a11e1"
    try """
    {"id":"\(id)","thread_name":"等待用户选择方案","updated_at":"2026-06-01T03:05:00Z"}

    """.write(to: indexURL, atomically: true, encoding: .utf8)

    try """
    {"timestamp":"2026-06-01T03:04:00.000Z","type":"session_meta","payload":{"id":"\(id)","thread_source":"user"}}
    {"timestamp":"2026-06-01T03:04:01.000Z","type":"event_msg","payload":{"type":"task_started"}}
    {"timestamp":"2026-06-01T03:04:30.000Z","type":"response_item","payload":{"type":"function_call","name":"request_user_input"}}
    """.write(
        to: sessionsDirectory.appendingPathComponent("rollout-2026-06-01T11-05-00-\(id).jsonl"),
        atomically: true,
        encoding: .utf8
    )

    let tasks = try CodexSessionLoader(
        indexURL: indexURL,
        sessionsDirectoryURL: sessionsDirectory,
        archivedSessionsDirectoryURL: temporaryDirectory.appendingPathComponent("archived", isDirectory: true),
        maxTasks: 8
    ).load()

    #expect(tasks.count == 1)
    #expect(tasks[0].status == .needsReview)
}

@Test func codexSessionLoaderSkipsSubagentSessions() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let indexURL = temporaryDirectory.appendingPathComponent("session_index.jsonl")
    let sessionsDirectory = temporaryDirectory.appendingPathComponent("sessions", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

    let userID = "019e7e2d-9b5d-73f2-80af-4e983628619b"
    let subagentID = "019e80dd-b735-7b63-b95a-11db393425a3"
    try """
    {"id":"\(userID)","thread_name":"提出可插拔 Agent 工具方向","updated_at":"2026-06-01T01:48:23.059858Z"}
    {"id":"\(subagentID)","thread_name":"Implement one-line companion","updated_at":"2026-06-01T01:50:48.415074Z"}

    """.write(to: indexURL, atomically: true, encoding: .utf8)

    try """
    {"timestamp":"2026-06-01T01:48:23.000Z","type":"session_meta","payload":{"id":"\(userID)","thread_source":"user"}}
    """.write(
        to: sessionsDirectory.appendingPathComponent("rollout-2026-06-01T09-48-23-\(userID).jsonl"),
        atomically: true,
        encoding: .utf8
    )
    try """
    {"timestamp":"2026-06-01T01:50:48.000Z","type":"session_meta","payload":{"id":"\(subagentID)","thread_source":"subagent"}}
    """.write(
        to: sessionsDirectory.appendingPathComponent("rollout-2026-06-01T09-50-48-\(subagentID).jsonl"),
        atomically: true,
        encoding: .utf8
    )

    let tasks = try CodexSessionLoader(
        indexURL: indexURL,
        sessionsDirectoryURL: sessionsDirectory,
        archivedSessionsDirectoryURL: temporaryDirectory.appendingPathComponent("archived", isDirectory: true),
        maxTasks: 8
    ).load()

    #expect(tasks.map(\.threadName) == ["提出可插拔 Agent 工具方向"])
}

@Test func codexSessionLoaderUsesSessionFileModificationDateForRecentActivity() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let indexURL = temporaryDirectory.appendingPathComponent("session_index.jsonl")
    let sessionsDirectory = temporaryDirectory.appendingPathComponent("sessions", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)

    let id = "019e7e2a-9810-7fa0-b6a8-2059fdf4e971"
    let sessionURL = sessionsDirectory.appendingPathComponent("rollout-2026-05-31T21-13-01-\(id).jsonl")
    let fileModifiedAt = try #require(ISO8601DateFormatter().date(from: "2026-06-01T02:00:00Z"))

    try """
    {"id":"\(id)","thread_name":"设计导入导出入口","updated_at":"2026-05-31T13:13:31.71032Z"}

    """.write(to: indexURL, atomically: true, encoding: .utf8)
    try """
    {"timestamp":"2026-05-31T13:13:17.638Z","type":"session_meta","payload":{"id":"\(id)","thread_source":"user"}}
    {"timestamp":"2026-05-31T13:14:49.870Z","type":"event_msg","payload":{"type":"task_complete"}}
    """.write(to: sessionURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.modificationDate: fileModifiedAt], ofItemAtPath: sessionURL.path)

    let tasks = try CodexSessionLoader(
        indexURL: indexURL,
        sessionsDirectoryURL: sessionsDirectory,
        archivedSessionsDirectoryURL: temporaryDirectory.appendingPathComponent("archived", isDirectory: true),
        maxTasks: 8
    ).load()

    #expect(tasks.count == 1)
    #expect(tasks[0].updatedAt == fileModifiedAt)
}
