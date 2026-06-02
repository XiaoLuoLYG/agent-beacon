import AgentBeaconCore
import AgentBeaconUI
import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController {
    private let panel: NSPanel
    private var dragStartFrame: NSRect?

    init(
        store: BeaconTaskStore,
        openStatusFile: @escaping () -> Void,
        markTaskRead: @escaping (AgentTask) -> Void,
        connectInstalledAgents: @escaping () -> Void,
        quitApp: @escaping () -> Void
    ) {
        let initialIconSize = BeaconIconSize.stored()
        let collapsedSize = initialIconSize.collapsedPanelSize
        let screenFrame = Self.preferredScreenFrame()
        let defaultOrigin = NSPoint(
            x: screenFrame.maxX - collapsedSize.width - 28,
            y: screenFrame.maxY - collapsedSize.height - 48
        )
        let origin = Self.savedOrigin(size: collapsedSize, fallback: defaultOrigin)

        panel = NSPanel(
            contentRect: NSRect(origin: origin, size: collapsedSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = BeaconPanelAppearance.drawsSystemWindowShadow
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true

        let rootView = BeaconRootView(
            store: store,
            focusService: WindowFocusService(),
            resizePanel: { [weak self] expanded, rowCount, iconSize in
                self?.resize(expanded: expanded, rowCount: rowCount, iconSize: iconSize)
            },
            movePanel: { [weak self] translation in
                self?.move(translation: translation)
            },
            savePanelPosition: { [weak self] in
                self?.savePanelPosition()
            },
            markTaskRead: markTaskRead,
            openStatusFile: openStatusFile,
            connectInstalledAgents: connectInstalledAgents,
            quitApp: quitApp
        )
        panel.contentView = NSHostingView(rootView: rootView)
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    var isVisible: Bool {
        panel.isVisible
    }

    private static let originXKey = "floatingPanel.origin.x"
    private static let originYKey = "floatingPanel.origin.y"

    private static func preferredScreenFrame() -> NSRect {
        if let originScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) {
            return originScreen.visibleFrame
        }

        if let mainScreen = NSScreen.main {
            return mainScreen.visibleFrame
        }

        return NSRect(x: 0, y: 0, width: 1200, height: 800)
    }

    private func resize(expanded: Bool, rowCount: Int, iconSize: BeaconIconSize) {
        let oldFrame = panel.frame
        let newSize = expanded ? iconSize.expandedPanelSize(rowCount: rowCount) : iconSize.collapsedPanelSize
        let screenFrame = Self.preferredScreenFrame()
        let targetX = oldFrame.maxX - newSize.width
        let clampedX = min(max(targetX, screenFrame.minX + 16), screenFrame.maxX - newSize.width - 16)
        let targetY = oldFrame.maxY - newSize.height
        let clampedY = min(max(targetY, screenFrame.minY + 16), screenFrame.maxY - newSize.height - 16)
        let newOrigin = NSPoint(x: clampedX, y: clampedY)
        panel.setFrame(NSRect(origin: newOrigin, size: newSize), display: true, animate: false)
        panel.invalidateShadow()
    }

    private func move(translation: CGSize) {
        if dragStartFrame == nil {
            dragStartFrame = panel.frame
        }

        guard let start = dragStartFrame else { return }

        let screenFrame = Self.preferredScreenFrame()
        let target = NSPoint(
            x: start.minX + translation.width,
            y: start.minY - translation.height
        )
        let clamped = Self.clamp(origin: target, size: start.size, screenFrame: screenFrame)
        panel.setFrameOrigin(clamped)
    }

    private func savePanelPosition() {
        Self.saveOrigin(panel.frame.origin)
        dragStartFrame = nil
    }

    private static func savedOrigin(size: NSSize, fallback: NSPoint) -> NSPoint {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: originXKey) != nil, defaults.object(forKey: originYKey) != nil else {
            return fallback
        }

        let screenFrame = preferredScreenFrame()
        let saved = NSPoint(
            x: defaults.double(forKey: originXKey),
            y: defaults.double(forKey: originYKey)
        )
        return clamp(origin: saved, size: size, screenFrame: screenFrame)
    }

    private static func saveOrigin(_ origin: NSPoint) {
        let defaults = UserDefaults.standard
        defaults.set(origin.x, forKey: originXKey)
        defaults.set(origin.y, forKey: originYKey)
    }

    private static func clamp(origin: NSPoint, size: NSSize, screenFrame: NSRect) -> NSPoint {
        NSPoint(
            x: min(max(origin.x, screenFrame.minX + 16), screenFrame.maxX - size.width - 16),
            y: min(max(origin.y, screenFrame.minY + 16), screenFrame.maxY - size.height - 16)
        )
    }
}
