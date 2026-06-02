import AgentBeaconCore
import AppKit
import Foundation

@MainActor
final class WindowFocusService {
    func activate(_ target: JumpTarget?) {
        guard let target else {
            NSSound.beep()
            return
        }

        switch target.type {
        case .app, .window:
            activateApplication(namedOrIdentifiedBy: target.value)
        case .url:
            openURL(target.value)
        }
    }

    private func activateApplication(namedOrIdentifiedBy value: String) {
        let workspace = NSWorkspace.shared
        if let runningApp = workspace.runningApplications.first(where: { app in
            app.bundleIdentifier == value ||
                app.localizedName?.localizedCaseInsensitiveCompare(value) == .orderedSame
        }) {
            runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return
        }

        if let url = workspace.urlForApplication(withBundleIdentifier: value) {
            let configuration = NSWorkspace.OpenConfiguration()
            workspace.openApplication(at: url, configuration: configuration)
            return
        }

        runActivateScript(forApplicationName: value)
    }

    private func openURL(_ value: String) {
        guard let url = URL(string: value) else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func runActivateScript(forApplicationName applicationName: String) {
        let escapedName = applicationName.replacingOccurrences(of: "\"", with: "\\\"")
        let source = "tell application \"\(escapedName)\" to activate"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if error != nil {
            NSSound.beep()
        }
    }
}
