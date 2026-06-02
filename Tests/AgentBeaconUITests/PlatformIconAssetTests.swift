import AgentBeaconCore
import AppKit
@testable import AgentBeaconUI
import Foundation
import Testing

@Test func platformIconAssetsExistForEveryPlatformAndStayHighResolution() throws {
    for platform in officialIconPlatforms {
        let url = try platformIconAssetURL(for: platform)
        let bitmap = try bitmapImage(at: url)

        #expect(bitmap.pixelsWide >= 512, "\(platform.displayName) icon should be at least 512px wide.")
        #expect(bitmap.pixelsHigh >= 512, "\(platform.displayName) icon should be at least 512px tall.")
        #expect(try hasTransparentCorners(bitmap), "\(platform.displayName) icon should not include a baked app-tile shadow.")
    }
}

@MainActor
@Test func platformIconResolverPrefersLocalAssetsOverInstalledAppIcons() throws {
    for platform in officialIconPlatforms {
        let resolution = try #require(PlatformIconResolver.resolution(for: platform))

        #expect(resolution.source == .asset)
        #expect(resolution.url.lastPathComponent == "\(platform.rawValue).png")
    }
}

@MainActor
@Test func genericCLIUsesBadgeFallbackInsteadOfUnofficialArtwork() {
    #expect(PlatformIconResolver.resolution(for: .genericCLI) == nil)
}

private let officialIconPlatforms = AgentPlatform.allCases.filter { $0 != .genericCLI }

private func platformIconAssetURL(for platform: AgentPlatform) throws -> URL {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    let url = packageRoot
        .appendingPathComponent("Assets/PlatformIcons", isDirectory: true)
        .appendingPathComponent("\(platform.rawValue).png")

    #expect(FileManager.default.fileExists(atPath: url.path), "\(platform.displayName) icon asset is missing.")
    return url
}

private func bitmapImage(at url: URL) throws -> NSBitmapImageRep {
    let data = try Data(contentsOf: url)
    return try #require(NSBitmapImageRep(data: data), "Could not decode \(url.path).")
}

private func hasTransparentCorners(_ bitmap: NSBitmapImageRep) throws -> Bool {
    let maxX = bitmap.pixelsWide - 1
    let maxY = bitmap.pixelsHigh - 1
    let cornerPoints = [
        (0, 0),
        (maxX, 0),
        (0, maxY),
        (maxX, maxY)
    ]

    for point in cornerPoints {
        let color = try #require(bitmap.colorAt(x: point.0, y: point.1))
        guard color.alphaComponent <= 0.05 else {
            return false
        }
    }

    return true
}
