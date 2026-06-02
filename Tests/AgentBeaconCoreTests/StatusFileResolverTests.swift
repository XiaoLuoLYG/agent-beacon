import AgentBeaconCore
import Foundation
import Testing

@Test func statusFileResolverUsesExplicitArgument() {
    let resolved = AgentBeaconStatusFileResolver.resolve(
        arguments: ["AgentBeacon", "--status-file", "/tmp/custom-status.json"],
        environment: [:],
        currentDirectoryURL: URL(fileURLWithPath: "/tmp/project")
    )

    #expect(resolved.path == "/tmp/custom-status.json")
}

@Test func statusFileResolverUsesEnvironmentWhenArgumentMissing() {
    let resolved = AgentBeaconStatusFileResolver.resolve(
        arguments: ["AgentBeacon"],
        environment: ["AGENT_BEACON_STATUS_FILE": "/tmp/env-status.json"],
        currentDirectoryURL: URL(fileURLWithPath: "/tmp/project")
    )

    #expect(resolved.path == "/tmp/env-status.json")
}

@Test func statusFileResolverDefaultsToUserStatusFileAndIgnoresProjectExample() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let examplesDirectory = temporaryDirectory.appendingPathComponent("examples", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    try FileManager.default.createDirectory(at: examplesDirectory, withIntermediateDirectories: true)
    try "{}".write(
        to: examplesDirectory.appendingPathComponent("generic-agent-status.json"),
        atomically: true,
        encoding: .utf8
    )

    let resolved = AgentBeaconStatusFileResolver.resolve(
        arguments: ["AgentBeacon"],
        environment: [:],
        currentDirectoryURL: temporaryDirectory
    )

    #expect(resolved == GenericStatusFileStore.defaultFileURL().standardizedFileURL)
}
