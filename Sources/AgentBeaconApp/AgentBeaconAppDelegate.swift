import AgentBeaconCore
import AppKit
import Foundation
import SwiftUI

@MainActor
final class AgentBeaconAppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AgentBeaconAppDelegate()

    private let store = BeaconTaskStore()
    private let readStateStore = TaskReadStateStore()
    private let desktopFloatingPanelPreference = DesktopFloatingPanelPreference()
    private let localAgentSessionPreference = LocalAgentSessionPreference()
    private var menuBarController: MenuBarController?
    private var topPanelController: TopPanelController?
    private var panelController: FloatingPanelController?
    private var pollTimer: Timer?
    private var statusFileURL: URL?
    private var hasStarted = false
    private var loadSequence = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        start()
    }

    func start() {
        guard !hasStarted else {
            if desktopFloatingPanelPreference.isEnabled {
                showDesktopFloatingPanel()
            }
            return
        }

        hasStarted = true
        statusFileURL = Self.resolveStatusFileURL()
        print("Agent Beacon launched. Status file: \(statusFileURL?.path ?? "none")")
        loadStatusFile()

        let topPanelController = TopPanelController(
            store: store,
            markTaskRead: { [weak self] task in
                self?.markTaskRead(task)
            }
        )
        self.topPanelController = topPanelController

        menuBarController = MenuBarController(
            topPanelController: topPanelController,
            connectInstalledAgents: { [weak self] in
                self?.connectInstalledAgents()
            },
            openStatusFile: { [weak self] in
                self?.openStatusFile()
            },
            isDesktopFloatingPanelEnabled: { [weak self] in
                self?.desktopFloatingPanelPreference.isEnabled ?? false
            },
            setDesktopFloatingPanelEnabled: { [weak self] enabled in
                self?.setDesktopFloatingPanelEnabled(enabled)
            },
            isLocalAgentSessionHistoryEnabled: { [weak self] in
                self?.localAgentSessionPreference.isEnabled ?? false
            },
            setLocalAgentSessionHistoryEnabled: { [weak self] enabled in
                self?.setLocalAgentSessionHistoryEnabled(enabled)
            },
            quitApp: {
                NSApplication.shared.terminate(nil)
            }
        )

        if desktopFloatingPanelPreference.isEnabled {
            showDesktopFloatingPanel()
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.loadStatusFile()
            }
        }
    }

    private func setLocalAgentSessionHistoryEnabled(_ enabled: Bool) {
        localAgentSessionPreference.isEnabled = enabled
        loadStatusFile()
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTimer?.invalidate()
    }

    private func setDesktopFloatingPanelEnabled(_ enabled: Bool) {
        desktopFloatingPanelPreference.isEnabled = enabled

        if enabled {
            showDesktopFloatingPanel()
        } else {
            panelController?.hide()
        }
    }

    private func showDesktopFloatingPanel() {
        if panelController == nil {
            panelController = FloatingPanelController(
                store: store,
                openStatusFile: { [weak self] in
                    self?.openStatusFile()
                },
                markTaskRead: { [weak self] task in
                    self?.markTaskRead(task)
                },
                connectInstalledAgents: { [weak self] in
                    self?.connectInstalledAgents()
                },
                quitApp: {
                    NSApplication.shared.terminate(nil)
                }
            )
        }

        panelController?.show()
    }

    private func loadStatusFile() {
        loadSequence += 1
        let sequence = loadSequence
        let statusFileURL = statusFileURL
        let includeLocalAgentSessions = localAgentSessionPreference.isEnabled

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let snapshot = Self.loadStatusSnapshot(
                statusFileURL: statusFileURL,
                includeLocalAgentSessions: includeLocalAgentSessions
            )

            DispatchQueue.main.async {
                guard let self, self.loadSequence == sequence else { return }
                self.store.replaceTasks(snapshot.tasks, diagnostic: snapshot.diagnostic)
            }
        }
    }

    private func markTaskRead(_ task: AgentTask) {
        guard task.status == .completed else {
            return
        }

        do {
            try readStateStore.markRead(task)
            loadStatusFile()
        } catch {
            print("Agent Beacon could not mark \(task.id) as read: \(error.localizedDescription)")
        }
    }

    private func openStatusFile() {
        guard let statusFileURL else {
            NSSound.beep()
            return
        }

        do {
            try GenericStatusFileStore(fileURL: statusFileURL).ensureDocumentExists()
            NSWorkspace.shared.activateFileViewerSelecting([statusFileURL])
        } catch {
            NSSound.beep()
        }
    }

    private func connectInstalledAgents() {
        guard let runnerURL = Self.resolveRunnerURL() else {
            print("Agent Beacon connect failed: agent-beacon-run was not found.")
            NSSound.beep()
            return
        }

        do {
            if let statusFileURL {
                try GenericStatusFileStore(fileURL: statusFileURL).ensureDocumentExists()
            }

            let results = AgentDetector().detect().filter { $0.canAutoConnect }
            let installed = try AgentShimInstaller(
                shimDirectoryURL: AgentBeaconIntegrationPaths.defaultShimDirectoryURL(),
                runnerURL: runnerURL
            ).installShims(for: results)
            let profileChanged = try ShellProfileInstaller(
                shimDirectoryURL: AgentBeaconIntegrationPaths.defaultShimDirectoryURL(),
                shellProfileURL: AgentBeaconIntegrationPaths.defaultShellProfileURL()
            ).ensureShimDirectoryIsFirstInPath()

            print("Agent Beacon connected \(installed.count) agent shim(s). Shell profile changed: \(profileChanged).")
            loadStatusFile()
        } catch {
            print("Agent Beacon connect failed: \(error.localizedDescription)")
            NSSound.beep()
        }
    }

    private static func resolveStatusFileURL() -> URL? {
        AgentBeaconStatusFileResolver.resolve()
    }

    private static func resolveRunnerURL() -> URL? {
        let environment = ProcessInfo.processInfo.environment
        if let explicit = environment["AGENT_BEACON_RUN"], !explicit.isEmpty {
            let url = URL(fileURLWithPath: explicit).standardizedFileURL
            if FileManager.default.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        let home = environment["HOME"] ?? NSHomeDirectory()
        let installed = URL(fileURLWithPath: home)
            .appendingPathComponent(".local/bin/agent-beacon-run")
            .standardizedFileURL
        if FileManager.default.isExecutableFile(atPath: installed.path) {
            return installed
        }

        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL.appendingPathComponent("agent-beacon-run").standardizedFileURL
            if FileManager.default.isExecutableFile(atPath: bundled.path) {
                return bundled
            }
        }

        let sourceTree = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("scripts/agent-beacon-run")
            .standardizedFileURL
        if FileManager.default.isExecutableFile(atPath: sourceTree.path) {
            return sourceTree
        }

        return nil
    }

    nonisolated private static func loadStatusSnapshot(
        statusFileURL: URL?,
        includeLocalAgentSessions: Bool
    ) -> StatusSnapshot {
        guard let statusFileURL else {
            return StatusSnapshot(tasks: [], diagnostic: "No status file configured.")
        }

        do {
            try GenericStatusFileStore(fileURL: statusFileURL).ensureDocumentExists()
            let genericTasks = try GenericStatusLoader().load(from: statusFileURL)
            let codexTasks = includeLocalAgentSessions ? ((try? CodexSessionLoader().load()) ?? []) : []
            let cursorTasks = includeLocalAgentSessions ? ((try? CursorComposerLoader().load()) ?? []) : []
            let readState = (try? TaskReadStateStore().load()) ?? TaskReadState()
            let tasks = TaskVisibilityFilter(readState: readState).filter(mergeTasks(genericTasks + codexTasks + cursorTasks))
            return StatusSnapshot(tasks: tasks, diagnostic: "Loaded \(tasks.count) task(s).")
        } catch {
            return StatusSnapshot(tasks: [], diagnostic: "Could not read \(statusFileURL.path): \(error.localizedDescription)")
        }
    }

    nonisolated private static func mergeTasks(_ tasks: [AgentTask]) -> [AgentTask] {
        var byID: [String: AgentTask] = [:]
        for task in tasks {
            byID[task.id] = task
        }
        return Array(byID.values)
    }
}

private struct StatusSnapshot: Sendable {
    var tasks: [AgentTask]
    var diagnostic: String
}
