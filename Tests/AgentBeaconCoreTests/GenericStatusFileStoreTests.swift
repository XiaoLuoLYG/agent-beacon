import Foundation
import Testing
@testable import AgentBeaconCore

@Test func genericStatusFileStoreUpsertsTasksThatLoaderCanRead() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = temporaryDirectory.appendingPathComponent("status.json")
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = GenericStatusFileStore(fileURL: fileURL)
    try store.upsert(
        id: "demo",
        platform: .genericCLI,
        threadName: "Demo task",
        status: .running,
        jumpTarget: JumpTarget(type: .app, value: "Terminal"),
        updatedAt: Date(timeIntervalSince1970: 1)
    )

    try store.upsert(
        id: "demo",
        platform: .genericCLI,
        threadName: "Demo task",
        status: .completed,
        jumpTarget: JumpTarget(type: .app, value: "Terminal"),
        updatedAt: Date(timeIntervalSince1970: 2)
    )

    let tasks = try GenericStatusLoader().load(from: fileURL)

    #expect(tasks.count == 1)
    #expect(tasks[0].id == "generic-cli:demo")
    #expect(tasks[0].status == .completed)
}

@Test func genericStatusFileStoreRemovesTasksByPlatformAndId() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = temporaryDirectory.appendingPathComponent("status.json")
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = GenericStatusFileStore(fileURL: fileURL)
    try store.upsert(
        id: "task-a",
        platform: .genericCLI,
        threadName: "Task A",
        status: .running,
        jumpTarget: nil,
        updatedAt: Date(timeIntervalSince1970: 1)
    )
    try store.remove(id: "task-a", platform: .genericCLI)

    let tasks = try GenericStatusLoader().load(from: fileURL)
    #expect(tasks.isEmpty)
}

@Test func genericStatusFileStoreCreatesEmptyDocumentWhenMissing() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = temporaryDirectory.appendingPathComponent("status.json")
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let store = GenericStatusFileStore(fileURL: fileURL)
    try store.ensureDocumentExists()

    let tasks = try GenericStatusLoader().load(from: fileURL)
    #expect(tasks.isEmpty)
    #expect(FileManager.default.fileExists(atPath: fileURL.path))
}
