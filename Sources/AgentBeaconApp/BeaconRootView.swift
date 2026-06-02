import AgentBeaconCore
import AgentBeaconUI
import SwiftUI

struct BeaconRootView: View {
    @ObservedObject var store: BeaconTaskStore
    let focusService: WindowFocusService
    let resizePanel: (Bool, Int, BeaconIconSize) -> Void
    let movePanel: (CGSize) -> Void
    let savePanelPosition: () -> Void
    let markTaskRead: (AgentTask) -> Void
    let openStatusFile: () -> Void
    let connectInstalledAgents: () -> Void
    let quitApp: () -> Void

    @State private var expanded = false
    @State private var pinnedOpen = false
    @State private var isDragging = false
    @State private var isHovering = false
    @State private var suppressHoverUntil = Date.distantPast
    @State private var hoverCloseTask: DispatchWorkItem?
    @State private var deferredResizeTask: DispatchWorkItem?
    @AppStorage(BeaconIconSize.preferenceKey) private var iconSizeRawValue = BeaconIconSize.defaultValue.rawValue

    private var iconSize: BeaconIconSize {
        BeaconIconSize(rawValue: iconSizeRawValue) ?? .defaultValue
    }

    var body: some View {
        BeaconPanelSurfaceView(
            tasks: store.tasks,
            expanded: expanded,
            iconSize: iconSize
        ) {
            AggregateBarView(counts: store.counts, isExpanded: expanded, iconSize: iconSize)
                .contentShape(Capsule())
                .onTapGesture {
                    guard !isDragging else { return }
                    cancelHoverClose()
                    pinnedOpen.toggle()
                    setExpanded(pinnedOpen)
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            if !isDragging {
                                cancelHoverClose()
                                isDragging = true
                            }
                            movePanel(value.translation)
                        }
                        .onEnded { _ in
                            savePanelPosition()
                            suppressHoverUntil = Date().addingTimeInterval(0.35)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                isDragging = false
                                if !pinnedOpen, !isHovering {
                                    scheduleHoverClose()
                                }
                            }
                        }
                )
        } activate: { task in
            markTaskRead(task)
            focusService.activate(task.jumpTarget)
            pinnedOpen = false
            setExpanded(false)
        }
        .onHover { hovering in
            handleHover(hovering)
        }
        .onChange(of: store.tasks.count) { newValue in
            resizePanel(expanded, newValue, iconSize)
        }
        .onChange(of: iconSizeRawValue) { _ in
            resizePanel(expanded, store.sortedTasks.count, iconSize)
        }
        .onDisappear {
            cancelHoverClose()
            cancelDeferredResize()
        }
        .contextMenu {
            Picker("Icon Size", selection: $iconSizeRawValue) {
                ForEach(BeaconIconSize.allCases) { size in
                    Text(size.menuTitle).tag(size.rawValue)
                }
            }
            Divider()
            Button("Connect Installed Agents") {
                connectInstalledAgents()
            }
            Button("Open Status File") {
                openStatusFile()
            }
            Button("Quit Agent Beacon") {
                quitApp()
            }
        }
        .accessibilityLabel("Agent Beacon")
    }

    private func setExpanded(_ value: Bool) {
        if value {
            cancelDeferredResize()
        }

        guard expanded != value else {
            resizePanel(value, store.sortedTasks.count, iconSize)
            return
        }

        if value {
            resizePanel(true, store.sortedTasks.count, iconSize)
            withAnimation(BeaconPanelAnimation.reveal) {
                expanded = true
            }
        } else {
            withAnimation(BeaconPanelAnimation.reveal) {
                expanded = false
            }
            scheduleDeferredResize()
        }
    }

    private func handleHover(_ hovering: Bool) {
        isHovering = hovering
        guard !pinnedOpen else { return }
        guard !isDragging else {
            cancelHoverClose()
            return
        }
        guard Date() >= suppressHoverUntil else { return }

        if hovering {
            cancelHoverClose()
            setExpanded(true)
        } else {
            scheduleHoverClose()
        }
    }

    private func scheduleHoverClose() {
        cancelHoverClose()

        let task = DispatchWorkItem {
            guard !pinnedOpen, !isDragging else { return }
            setExpanded(false)
        }
        hoverCloseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: task)
    }

    private func cancelHoverClose() {
        hoverCloseTask?.cancel()
        hoverCloseTask = nil
    }

    private func scheduleDeferredResize() {
        cancelDeferredResize()

        let task = DispatchWorkItem {
            resizePanel(false, store.sortedTasks.count, iconSize)
        }
        deferredResizeTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + BeaconPanelAnimation.revealDuration, execute: task)
    }

    private func cancelDeferredResize() {
        deferredResizeTask?.cancel()
        deferredResizeTask = nil
    }
}
