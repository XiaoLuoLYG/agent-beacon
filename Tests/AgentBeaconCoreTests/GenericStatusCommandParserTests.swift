import Foundation
import Testing
@testable import AgentBeaconCore

@Test func parserBuildsUpsertCommandFromMinimalArguments() throws {
    let command = try GenericStatusCommandParser.parse([
        "--id", "demo",
        "--name", "Demo task",
        "--status", "running",
        "--app", "Terminal"
    ])

    guard case let .upsert(task) = command.action else {
        Issue.record("Expected upsert command.")
        return
    }

    #expect(task.id == "demo")
    #expect(task.platform == .genericCLI)
    #expect(task.threadName == "Demo task")
    #expect(task.status == .running)
    #expect(task.jumpTarget == JumpTarget(type: .app, value: "Terminal"))
}

@Test func parserBuildsRemoveCommand() throws {
    let command = try GenericStatusCommandParser.parse([
        "remove",
        "--id", "demo",
        "--platform", "generic-cli"
    ])

    guard case let .remove(id, platform) = command.action else {
        Issue.record("Expected remove command.")
        return
    }

    #expect(id == "demo")
    #expect(platform == .genericCLI)
}

@Test func parserBuildsDoctorCommandWithoutTaskArguments() throws {
    let command = try GenericStatusCommandParser.parse([
        "doctor",
        "--file", "/tmp/agent-beacon-status.json"
    ])

    guard case .doctor = command.action else {
        Issue.record("Expected doctor command.")
        return
    }

    #expect(command.fileURL.path == "/tmp/agent-beacon-status.json")
}

@Test func parserAcceptsDetectCommandWithoutTaskArguments() throws {
    _ = try GenericStatusCommandParser.parse(["detect"])
}

@Test func parserAcceptsConnectCommandWithoutTaskArguments() throws {
    _ = try GenericStatusCommandParser.parse(["connect"])
}

@Test func parserRejectsMissingRequiredArguments() {
    #expect(throws: GenericStatusCommandParser.ParseError.self) {
        _ = try GenericStatusCommandParser.parse(["--id", "demo"])
    }
}
