import AgentBeaconCore
import AgentBeaconUI
import AppKit
import SwiftUI
import Testing

@MainActor
@Test func topSurfaceCollapsedRendersFourLightSurface() throws {
    let iconSize = BeaconIconSize.defaultValue
    let image = try render(
        BeaconTopSurfaceView(tasks: SnapshotFixture.tasks, expanded: false, iconSize: iconSize) { _ in },
        size: iconSize.collapsedPanelSize
    )

    #expect(try visiblePixelCount(in: image) > 200)
}

@MainActor
@Test func topSurfaceExpandedRendersTaskListSurface() throws {
    let iconSize = BeaconIconSize.defaultValue
    let image = try render(
        BeaconTopSurfaceView(tasks: SnapshotFixture.tasks, expanded: true, iconSize: iconSize) { _ in },
        size: iconSize.expandedPanelSize(rowCount: SnapshotFixture.tasks.count)
    )

    #expect(try visiblePixelCount(in: image) > 1_000)
}

@MainActor
@Test func topSurfaceExpandedWithManyTasksProvidesScrollableTaskList() throws {
    let iconSize = BeaconIconSize.defaultValue
    let hostingView = host(
        BeaconTopSurfaceView(tasks: manyTasks(count: 24), expanded: true, iconSize: iconSize) { _ in },
        size: iconSize.expandedPanelSize(rowCount: 24)
    )
    let scrollView = try #require(firstScrollView(in: hostingView))

    #expect(scrollableContentExtent(in: scrollView) > scrollView.contentView.bounds.height)
}

@MainActor
@Test func topSurfaceKeepsAggregateLightsVisibleWhenExpandedFrameIsStillCollapsed() throws {
    let iconSize = BeaconIconSize.defaultValue
    let image = try render(
        BeaconTopSurfaceView(tasks: SnapshotFixture.tasks, expanded: true, iconSize: iconSize) { _ in },
        size: iconSize.collapsedPanelSize
    )

    try expectAggregateLightsVisible(in: image, iconSize: iconSize)
}

@MainActor
@Test func collapsedTopSurfaceCanRenderInsideExpandedFrameWithoutMovingAggregateLights() throws {
    let iconSize = BeaconIconSize.defaultValue
    let image = try render(
        BeaconTopSurfaceView(tasks: SnapshotFixture.tasks, expanded: false, iconSize: iconSize) { _ in },
        size: iconSize.expandedPanelSize(rowCount: SnapshotFixture.tasks.count)
    )

    try expectAggregateLightsVisible(in: image, iconSize: iconSize)
}

@MainActor
private func render<V: View>(_ view: V, size: NSSize) throws -> NSBitmapImageRep {
    let hostingView = host(view, size: size)

    guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
        throw TopSurfaceTestError("Could not create top-surface bitmap.")
    }

    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
    return bitmap
}

@MainActor
private func host<V: View>(_ view: V, size: NSSize) -> NSHostingView<V> {
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = NSRect(origin: .zero, size: size)
    hostingView.setFrameSize(size)
    hostingView.layoutSubtreeIfNeeded()
    return hostingView
}

private struct TopSurfaceTestError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

private func visiblePixelCount(in bitmap: NSBitmapImageRep) throws -> Int {
    var visiblePixels = 0
    for y in 0..<bitmap.pixelsHigh {
        for x in 0..<bitmap.pixelsWide {
            guard let color = bitmap.colorAt(x: x, y: y) else { continue }
            if color.alphaComponent > 0.05 &&
                (color.redComponent > 0.05 || color.greenComponent > 0.05 || color.blueComponent > 0.05) {
                visiblePixels += 1
            }
        }
    }
    return visiblePixels
}

private func expectAggregateLightsVisible(in bitmap: NSBitmapImageRep, iconSize: BeaconIconSize) throws {
    let padding = Int(BeaconContainerChrome(isExpanded: false).contentPadding.rounded())
    let headerHeight = Int((iconSize.aggregateBarSize.height + BeaconContainerChrome(isExpanded: false).contentPadding * 2).rounded())
    let headerRect = CGRect(
        x: 0,
        y: 0,
        width: bitmap.pixelsWide,
        height: min(bitmap.pixelsHigh, headerHeight + padding)
    )

    let lightPixels = try statusLightPixelCounts(in: bitmap, rect: headerRect)
    #expect(lightPixels.completed > 120)
    #expect(lightPixels.needsReview > 120)
    #expect(lightPixels.failed > 120)
    #expect(lightPixels.running > 120)
}

@MainActor
private func firstScrollView(in view: NSView) -> NSScrollView? {
    if let scrollView = view as? NSScrollView {
        return scrollView
    }

    for subview in view.subviews {
        if let scrollView = firstScrollView(in: subview) {
            return scrollView
        }
    }

    return nil
}

private func manyTasks(count: Int) -> [AgentTask] {
    let formatter = ISO8601DateFormatter()
    return (0..<count).map { index in
        AgentTask(
            id: "many-\(index)",
            platform: AgentPlatform.allCases[index % AgentPlatform.allCases.count],
            threadName: "Scrollable task \(index)",
            status: AgentTaskStatus.allCases[index % AgentTaskStatus.allCases.count],
            jumpTarget: JumpTarget(type: .app, value: "Terminal"),
            updatedAt: formatter.date(from: "2026-06-01T00:00:00Z") ?? Date(timeIntervalSince1970: 0)
        )
    }
}

@MainActor
private func scrollableContentExtent(in view: NSView, offsetY: CGFloat = 0) -> CGFloat {
    view.subviews.reduce(CGFloat.zero) { partialResult, subview in
        let subviewOffsetY = offsetY + subview.frame.minY
        let subviewMaxY = subviewOffsetY + subview.frame.height
        return max(partialResult, subviewMaxY, scrollableContentExtent(in: subview, offsetY: subviewOffsetY))
    }
}

private func statusLightPixelCounts(
    in bitmap: NSBitmapImageRep,
    rect: CGRect
) throws -> (completed: Int, needsReview: Int, failed: Int, running: Int) {
    var completed = 0
    var needsReview = 0
    var failed = 0
    var running = 0

    let minX = max(0, Int(rect.minX.rounded(.down)))
    let maxX = min(bitmap.pixelsWide, Int(rect.maxX.rounded(.up)))
    let minY = max(0, Int(rect.minY.rounded(.down)))
    let maxY = min(bitmap.pixelsHigh, Int(rect.maxY.rounded(.up)))

    for y in minY..<maxY {
        for x in minX..<maxX {
            guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.08 else { continue }

            if color.greenComponent > 0.55, color.redComponent < 0.42, color.blueComponent < 0.48 {
                completed += 1
            } else if color.redComponent > 0.72, color.greenComponent > 0.42, color.blueComponent < 0.30 {
                needsReview += 1
            } else if color.redComponent > 0.66, color.greenComponent < 0.34, color.blueComponent < 0.36 {
                failed += 1
            } else if color.blueComponent > 0.62, color.redComponent < 0.50, color.greenComponent > 0.35 {
                running += 1
            }
        }
    }

    return (completed, needsReview, failed, running)
}
