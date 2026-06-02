import AgentBeaconCore
import AgentBeaconUI
import AppKit
import Foundation
import SwiftUI

let outputDirectory = resolveOutputDirectory()
let iconSize = BeaconIconSize.defaultValue

do {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    let collapsedURL = outputDirectory.appendingPathComponent("agent-beacon-collapsed.png")
    let expandedURL = outputDirectory.appendingPathComponent("agent-beacon-expanded.png")
    let topCollapsedURL = outputDirectory.appendingPathComponent("agent-beacon-top-collapsed.png")
    let topExpandedURL = outputDirectory.appendingPathComponent("agent-beacon-top-expanded.png")

    try render(
        BeaconSnapshotSurfaceView(tasks: SnapshotFixture.tasks, expanded: false, iconSize: iconSize),
        size: iconSize.collapsedPanelSize,
        to: collapsedURL
    )
    try render(
        BeaconSnapshotSurfaceView(tasks: SnapshotFixture.tasks, expanded: true, iconSize: iconSize),
        size: iconSize.expandedPanelSize(rowCount: SnapshotFixture.tasks.count),
        to: expandedURL
    )
    try render(
        BeaconTopSurfaceView(tasks: SnapshotFixture.tasks, expanded: false, iconSize: iconSize) { _ in },
        size: iconSize.collapsedPanelSize,
        to: topCollapsedURL
    )
    try render(
        BeaconTopSurfaceView(tasks: SnapshotFixture.tasks, expanded: true, iconSize: iconSize) { _ in },
        size: iconSize.expandedPanelSize(rowCount: SnapshotFixture.tasks.count),
        to: topExpandedURL
    )

    try verifyNonBlankPNG(collapsedURL)
    try verifyNonBlankPNG(expandedURL)
    try verifyNonBlankPNG(topCollapsedURL)
    try verifyNonBlankPNG(topExpandedURL)

    print("Wrote \(collapsedURL.path)")
    print("Wrote \(expandedURL.path)")
    print("Wrote \(topCollapsedURL.path)")
    print("Wrote \(topExpandedURL.path)")
} catch {
    fputs("AgentBeaconSnapshot: \(error.localizedDescription)\n", stderr)
    exit(2)
}

private func resolveOutputDirectory() -> URL {
    let arguments = CommandLine.arguments
    if let index = arguments.firstIndex(of: "--output"), arguments.indices.contains(index + 1) {
        return URL(fileURLWithPath: arguments[index + 1]).standardizedFileURL
    }

    return URL(fileURLWithPath: "dist/snapshots").standardizedFileURL
}

@MainActor
private func render<V: View>(_ view: V, size: NSSize, to url: URL) throws {
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = NSRect(origin: .zero, size: size)
    hostingView.setFrameSize(size)
    hostingView.layoutSubtreeIfNeeded()

    guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
        throw SnapshotError.couldNotCreateBitmap
    }

    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw SnapshotError.couldNotEncodePNG
    }

    try pngData.write(to: url, options: [.atomic])
}

private func verifyNonBlankPNG(_ url: URL) throws {
    guard
        let image = NSImage(contentsOf: url),
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff)
    else {
        throw SnapshotError.couldNotReadPNG(url.path)
    }

    var visiblePixels = 0
    let width = bitmap.pixelsWide
    let height = bitmap.pixelsHigh

    for y in 0..<height {
        for x in 0..<width {
            guard let color = bitmap.colorAt(x: x, y: y) else { continue }
            if color.alphaComponent > 0.05 &&
                (color.redComponent > 0.05 || color.greenComponent > 0.05 || color.blueComponent > 0.05) {
                visiblePixels += 1
            }
        }
    }

    if visiblePixels < 200 {
        throw SnapshotError.blankPNG(url.path)
    }
}

private enum SnapshotError: LocalizedError {
    case couldNotCreateBitmap
    case couldNotEncodePNG
    case couldNotReadPNG(String)
    case blankPNG(String)

    var errorDescription: String? {
        switch self {
        case .couldNotCreateBitmap:
            "Could not create bitmap."
        case .couldNotEncodePNG:
            "Could not encode PNG."
        case .couldNotReadPNG(let path):
            "Could not read PNG at \(path)."
        case .blankPNG(let path):
            "Snapshot looked blank: \(path)."
        }
    }
}
