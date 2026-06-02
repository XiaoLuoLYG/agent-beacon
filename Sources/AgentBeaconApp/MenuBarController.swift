import AgentBeaconUI
import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let topPanelController: TopPanelController
    private let connectInstalledAgents: () -> Void
    private let openStatusFile: () -> Void
    private let isDesktopFloatingPanelEnabled: () -> Bool
    private let setDesktopFloatingPanelEnabled: (Bool) -> Void
    private let isLocalAgentSessionHistoryEnabled: () -> Bool
    private let setLocalAgentSessionHistoryEnabled: (Bool) -> Void
    private let quitApp: () -> Void

    init(
        topPanelController: TopPanelController,
        connectInstalledAgents: @escaping () -> Void,
        openStatusFile: @escaping () -> Void,
        isDesktopFloatingPanelEnabled: @escaping () -> Bool,
        setDesktopFloatingPanelEnabled: @escaping (Bool) -> Void,
        isLocalAgentSessionHistoryEnabled: @escaping () -> Bool,
        setLocalAgentSessionHistoryEnabled: @escaping (Bool) -> Void,
        quitApp: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.topPanelController = topPanelController
        self.connectInstalledAgents = connectInstalledAgents
        self.openStatusFile = openStatusFile
        self.isDesktopFloatingPanelEnabled = isDesktopFloatingPanelEnabled
        self.setDesktopFloatingPanelEnabled = setDesktopFloatingPanelEnabled
        self.isLocalAgentSessionHistoryEnabled = isLocalAgentSessionHistoryEnabled
        self.setLocalAgentSessionHistoryEnabled = setLocalAgentSessionHistoryEnabled
        self.quitApp = quitApp
        super.init()
        configureStatusItem()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.image = MenuBarTemplateIconFactory.makeImage()
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = "Agent Beacon"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isSecondaryClick = event?.type == .rightMouseUp ||
            event?.modifierFlags.contains(.control) == true

        if isSecondaryClick {
            showUtilityMenu()
        } else {
            topPanelController.toggle(anchorFrame: statusItemFrameInScreen())
        }
    }

    private func showUtilityMenu() {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Connect Installed Agents",
                action: #selector(connectInstalledAgentsSelected(_:)),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "Open Status File",
                action: #selector(openStatusFileSelected(_:)),
                keyEquivalent: ""
            )
        )
        menu.addItem(NSMenuItem.separator())

        let desktopStripItem = NSMenuItem(
            title: "Show Desktop Floating Strip",
            action: #selector(toggleDesktopFloatingStrip(_:)),
            keyEquivalent: ""
        )
        desktopStripItem.state = isDesktopFloatingPanelEnabled() ? .on : .off
        menu.addItem(desktopStripItem)

        let localSessionsItem = NSMenuItem(
            title: "Show Codex/Cursor Local History",
            action: #selector(toggleLocalSessionHistory(_:)),
            keyEquivalent: ""
        )
        localSessionsItem.state = isLocalAgentSessionHistoryEnabled() ? .on : .off
        menu.addItem(localSessionsItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit Agent Beacon",
                action: #selector(quitSelected(_:)),
                keyEquivalent: "q"
            )
        )

        for item in menu.items {
            item.target = self
        }

        guard let button = statusItem.button else {
            return
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY - 4), in: button)
    }

    private func statusItemFrameInScreen() -> NSRect? {
        guard let button = statusItem.button, let window = button.window else {
            return nil
        }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        return window.convertToScreen(buttonFrameInWindow)
    }

    @objc private func connectInstalledAgentsSelected(_ sender: NSMenuItem) {
        connectInstalledAgents()
    }

    @objc private func openStatusFileSelected(_ sender: NSMenuItem) {
        openStatusFile()
    }

    @objc private func toggleDesktopFloatingStrip(_ sender: NSMenuItem) {
        setDesktopFloatingPanelEnabled(!isDesktopFloatingPanelEnabled())
    }

    @objc private func toggleLocalSessionHistory(_ sender: NSMenuItem) {
        setLocalAgentSessionHistoryEnabled(!isLocalAgentSessionHistoryEnabled())
    }

    @objc private func quitSelected(_ sender: NSMenuItem) {
        quitApp()
    }
}
