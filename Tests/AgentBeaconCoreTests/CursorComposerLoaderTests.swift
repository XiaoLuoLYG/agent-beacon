import Foundation
import Testing
@testable import AgentBeaconCore

@Test func cursorComposerLoaderDecodesRecentActiveComposerAsRunning() throws {
    let now = try #require(ISO8601DateFormatter().date(from: "2026-06-01T03:00:00Z"))
    let data = """
    {
      "allComposers": [
        {
          "composerId": "0da02d5b-c7ef-4431-81bf-e7d42ffd8d5f",
          "name": "长时间任务的执行",
          "hasBlockingPendingActions": false,
          "hasUnreadMessages": false,
          "isArchived": false,
          "isDraft": false,
          "lastUpdatedAt": 1780281000000,
          "workspaceIdentifier": {
            "id": "workspace-1",
            "uri": {
              "fsPath": "/Users/example/Documents/projects"
            }
          }
        }
      ]
    }
    """.data(using: .utf8)!

    let tasks = try CursorComposerLoader().decode(
        data,
        activeWorkspaceNames: ["projects"],
        now: now
    )

    #expect(tasks.count == 1)
    #expect(tasks[0].id == "cursor:0da02d5b-c7ef-4431-81bf-e7d42ffd8d5f")
    #expect(tasks[0].platform == .cursor)
    #expect(tasks[0].threadName == "长时间任务的执行")
    #expect(tasks[0].status == .running)
    #expect(tasks[0].jumpTarget == JumpTarget(type: .app, value: "Cursor"))
}

@Test func cursorComposerLoaderMarksBlockingComposerAsNeedsReview() throws {
    let now = try #require(ISO8601DateFormatter().date(from: "2026-06-01T03:00:00Z"))
    let data = """
    {
      "allComposers": [
        {
          "composerId": "review-me",
          "name": "Approve file edits",
          "hasBlockingPendingActions": true,
          "isArchived": false,
          "isDraft": false,
          "lastUpdatedAt": 1780279200000,
          "workspaceIdentifier": {
            "uri": {
              "fsPath": "/Users/example/Documents/GOD"
            }
          }
        }
      ]
    }
    """.data(using: .utf8)!

    let tasks = try CursorComposerLoader().decode(
        data,
        activeWorkspaceNames: [],
        now: now
    )

    #expect(tasks.count == 1)
    #expect(tasks[0].status == .needsReview)
}

@Test func cursorComposerLoaderSkipsArchivedDraftAndOldReadComposers() throws {
    let now = try #require(ISO8601DateFormatter().date(from: "2026-06-01T03:00:00Z"))
    let data = """
    {
      "allComposers": [
        {
          "composerId": "archived",
          "name": "Archived",
          "isArchived": true,
          "isDraft": false,
          "lastUpdatedAt": 1780282740000
        },
        {
          "composerId": "draft",
          "name": "Draft",
          "isArchived": false,
          "isDraft": true,
          "lastUpdatedAt": 1780282740000
        },
        {
          "composerId": "old-read",
          "name": "Old read",
          "hasUnreadMessages": false,
          "isArchived": false,
          "isDraft": false,
          "lastUpdatedAt": 1780192800000
        }
      ]
    }
    """.data(using: .utf8)!

    let tasks = try CursorComposerLoader().decode(
        data,
        activeWorkspaceNames: [],
        now: now
    )

    #expect(tasks.isEmpty)
}

@Test func cursorComposerLoaderParsesActiveAgentWorkspaceNames() {
    let processList = """
    /Applications/Cursor.app/Contents/Frameworks/Cursor Helper (Plugin).app/Contents/MacOS/Cursor Helper (Plugin): extension-host (agent-exec) projects [2-5]
    /Applications/Cursor.app/Contents/Frameworks/Cursor Helper (Plugin).app/Contents/MacOS/Cursor Helper (Plugin): extension-host (agent-exec) GOD [1-8]
    /Applications/Cursor.app/Contents/MacOS/Cursor
    """

    #expect(CursorComposerLoader.activeWorkspaceNames(fromProcessList: processList) == Set(["GOD", "projects"]))
}

@Test func cursorComposerLoaderProcessOutputHandlesLargeOutputWithoutDeadlock() throws {
    let script = """
    import sys
    sys.stdout.write("o" * 200000)
    sys.stderr.write("e" * 200000)
    """

    let output = try CursorComposerLoader.processOutput(
        executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
        arguments: ["-c", script]
    )

    #expect(output.count == 200000)
}
