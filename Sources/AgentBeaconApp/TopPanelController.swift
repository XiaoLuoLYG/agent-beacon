import AgentBeaconCore
import AgentBeaconUI
import AppKit
import SwiftUI

@MainActor
final class TopPanelController {
    private let panel: NSPanel
    private let store: BeaconTaskStore
    private let model = TopPanelPresentationModel()
    private let focusService = WindowFocusService()
    private let markTaskRead: (AgentTask) -> Void
    private var lastAnchorFrame: NSRect?

    init(
        store: BeaconTaskStore,
        markTaskRead: @escaping (AgentTask) -> Void
    ) {
        self.store = store
        self.markTaskRead = markTaskRead

        let initialIconSize = BeaconIconSize.stored()
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialIconSize.collapsedPanelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = BeaconPanelAppearance.drawsMenuBarTopPanelSystemWindowShadow
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false

        let rootView = TopPanelRootView(
            store: store,
            model: model,
            focusService: focusService,
            resizePanel: { [weak self] expanded, rowCount, iconSize in
                self?.resize(expanded: expanded, rowCount: rowCount, iconSize: iconSize)
            },
            markTaskRead: markTaskRead,
            closePanel: { [weak self] in
                self?.hide()
            }
        )
        panel.contentView = NSHostingView(rootView: rootView)
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func toggle(anchorFrame: NSRect?) {
        if panel.isVisible {
            hide()
        } else {
            show(anchorFrame: anchorFrame)
        }
    }

    func show(anchorFrame: NSRect?) {
        lastAnchorFrame = anchorFrame
        model.expanded = false
        resize(expanded: false, rowCount: store.sortedTasks.count, iconSize: BeaconIconSize.stored())
        panel.orderFrontRegardless()
    }

    func hide() {
        model.expanded = false
        panel.orderOut(nil)
    }

    private func resize(expanded: Bool, rowCount: Int, iconSize: BeaconIconSize) {
        let size = expanded ? iconSize.expandedPanelSize(rowCount: rowCount) : iconSize.collapsedPanelSize
        let frame = Self.panelFrame(size: size, anchorFrame: lastAnchorFrame)
        panel.setFrame(frame, display: true, animate: false)
        panel.invalidateShadow()
    }

    private static func panelFrame(size: NSSize, anchorFrame: NSRect?) -> NSRect {
        let screenFrame = preferredScreenFrame(anchorFrame: anchorFrame)
        let unclampedOrigin: NSPoint

        if let anchorFrame {
            unclampedOrigin = NSPoint(
                x: anchorFrame.midX - size.width / 2,
                y: anchorFrame.minY - size.height - 6
            )
        } else {
            unclampedOrigin = NSPoint(
                x: screenFrame.maxX - size.width - 12,
                y: screenFrame.maxY - size.height - 6
            )
        }

        return NSRect(
            origin: clamp(origin: unclampedOrigin, size: size, screenFrame: screenFrame),
            size: size
        )
    }

    private static func preferredScreenFrame(anchorFrame: NSRect?) -> NSRect {
        if let anchorFrame {
            let anchorPoint = NSPoint(x: anchorFrame.midX, y: anchorFrame.midY)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(anchorPoint) }) {
                return screen.visibleFrame
            }
        }

        if let mainScreen = NSScreen.main {
            return mainScreen.visibleFrame
        }

        return NSRect(x: 0, y: 0, width: 1200, height: 800)
    }

    private static func clamp(origin: NSPoint, size: NSSize, screenFrame: NSRect) -> NSPoint {
        NSPoint(
            x: min(max(origin.x, screenFrame.minX + 8), screenFrame.maxX - size.width - 8),
            y: min(max(origin.y, screenFrame.minY + 8), screenFrame.maxY - size.height - 8)
        )
    }
}

@MainActor
private final class TopPanelPresentationModel: ObservableObject {
    @Published var expanded = false
}

private struct TopPanelRootView: View {
    @ObservedObject var store: BeaconTaskStore
    @ObservedObject var model: TopPanelPresentationModel
    let focusService: WindowFocusService
    let resizePanel: (Bool, Int, BeaconIconSize) -> Void
    let markTaskRead: (AgentTask) -> Void
    let closePanel: () -> Void

    @State private var closeTask: DispatchWorkItem?
    @State private var deferredCollapseTask: DispatchWorkItem?
    @AppStorage(BeaconIconSize.preferenceKey) private var iconSizeRawValue = BeaconIconSize.defaultValue.rawValue

    private var iconSize: BeaconIconSize {
        BeaconIconSize(rawValue: iconSizeRawValue) ?? .defaultValue
    }

    var body: some View {
        BeaconTopSurfaceView(tasks: store.sortedTasks, expanded: model.expanded, iconSize: iconSize) { task in
            markTaskRead(task)
            focusService.activate(task.jumpTarget)
            closePanel()
        }
        .onHover { hovering in
            if hovering {
                cancelClose()
                setExpanded(true)
            } else {
                scheduleClose()
            }
        }
        .onChange(of: store.tasks.count) { _ in
            resizePanel(model.expanded, store.sortedTasks.count, iconSize)
        }
        .onChange(of: iconSizeRawValue) { _ in
            resizePanel(model.expanded, store.sortedTasks.count, iconSize)
        }
        .onDisappear {
            cancelClose()
            cancelDeferredCollapse()
        }
        .accessibilityLabel("Agent Beacon Top Panel")
    }

    private func setExpanded(_ expanded: Bool, closeWhenCollapsed: Bool = false) {
        if expanded {
            cancelDeferredCollapse()
        }

        guard model.expanded != expanded else {
            resizePanel(expanded, store.sortedTasks.count, iconSize)
            if closeWhenCollapsed {
                closePanel()
            }
            return
        }

        if expanded {
            resizePanel(true, store.sortedTasks.count, iconSize)
            withAnimation(BeaconPanelAnimation.reveal) {
                model.expanded = true
            }
        } else {
            withAnimation(BeaconPanelAnimation.reveal) {
                model.expanded = false
            }
            scheduleDeferredCollapse(closeWhenCollapsed: closeWhenCollapsed)
        }
    }

    private func scheduleClose() {
        cancelClose()

        let task = DispatchWorkItem {
            setExpanded(false, closeWhenCollapsed: true)
        }
        closeTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: task)
    }

    private func cancelClose() {
        closeTask?.cancel()
        closeTask = nil
        cancelDeferredCollapse()
    }

    private func scheduleDeferredCollapse(closeWhenCollapsed: Bool) {
        cancelDeferredCollapse()

        let task = DispatchWorkItem {
            resizePanel(false, store.sortedTasks.count, iconSize)
            if closeWhenCollapsed {
                closePanel()
            }
        }
        deferredCollapseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + BeaconPanelAnimation.revealDuration, execute: task)
    }

    private func cancelDeferredCollapse() {
        deferredCollapseTask?.cancel()
        deferredCollapseTask = nil
    }
}
