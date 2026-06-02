import AgentBeaconUI
import AppKit
import Testing

@Test func menuBarTemplateIconIsTemplateAtExpectedSize() throws {
    let image = MenuBarTemplateIconFactory.makeImage()

    #expect(image.isTemplate)
    #expect(image.size == MenuBarTemplateIconFactory.defaultSize)
    #expect(image.size == NSSize(width: 22, height: 18))
}

@Test func menuBarTemplateIconHasNonBlankAlphaMaskAndTransparentCorners() throws {
    let bitmap = try bitmap(for: MenuBarTemplateIconFactory.makeImage())

    var visiblePixels = 0
    var coloredPixels = 0
    for y in 0..<bitmap.pixelsHigh {
        for x in 0..<bitmap.pixelsWide {
            guard let color = bitmap.colorAt(x: x, y: y) else { continue }
            guard color.alphaComponent > 0.05 else { continue }

            visiblePixels += 1
            if abs(color.redComponent - color.greenComponent) > 0.01 ||
                abs(color.greenComponent - color.blueComponent) > 0.01 {
                coloredPixels += 1
            }
        }
    }

    #expect(visiblePixels > 80)
    #expect(coloredPixels == 0)
    #expect(bitmap.colorAt(x: 0, y: 0)?.alphaComponent == 0)
    #expect(bitmap.colorAt(x: bitmap.pixelsWide - 1, y: 0)?.alphaComponent == 0)
    #expect(bitmap.colorAt(x: 0, y: bitmap.pixelsHigh - 1)?.alphaComponent == 0)
    #expect(bitmap.colorAt(x: bitmap.pixelsWide - 1, y: bitmap.pixelsHigh - 1)?.alphaComponent == 0)
}

@Test func menuBarTemplateIconHasNoSeparateUnderlineBand() throws {
    let bitmap = try bitmap(for: MenuBarTemplateIconFactory.makeImage())
    let visibleRows = visibleAlphaRows(in: bitmap)

    #expect(contiguousBands(in: visibleRows).count == 1)
}

@Test func menuBarTemplateIconMaskIsCenteredAndLargeEnoughForMenuBar() throws {
    let bitmap = try bitmap(for: MenuBarTemplateIconFactory.makeImage())
    let bounds = try visibleAlphaBounds(in: bitmap)
    let maskCenterY = Double(bounds.minY + bounds.maxY) / 2
    let imageCenterY = Double(bitmap.pixelsHigh - 1) / 2

    #expect(bounds.width >= 18)
    #expect(bounds.height >= 9)
    #expect(abs(maskCenterY - imageCenterY) <= 1)
}

private func bitmap(for image: NSImage) throws -> NSBitmapImageRep {
    guard
        let data = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: data)
    else {
        throw MenuBarIconTestError("Could not read menu bar icon bitmap.")
    }
    return bitmap
}

private func visibleAlphaBounds(in bitmap: NSBitmapImageRep) throws -> PixelBounds {
    var minX = Int.max
    var minY = Int.max
    var maxX = Int.min
    var maxY = Int.min

    for y in 0..<bitmap.pixelsHigh {
        for x in 0..<bitmap.pixelsWide {
            guard bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0 > 0.05 else { continue }

            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }

    guard minX <= maxX, minY <= maxY else {
        throw MenuBarIconTestError("Menu bar icon alpha mask is blank.")
    }

    return PixelBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
}

private func visibleAlphaRows(in bitmap: NSBitmapImageRep) -> [Int] {
    var rows: [Int] = []
    for y in 0..<bitmap.pixelsHigh {
        let hasVisiblePixel = (0..<bitmap.pixelsWide).contains { x in
            bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0 > 0.05
        }
        if hasVisiblePixel {
            rows.append(y)
        }
    }
    return rows
}

private func contiguousBands(in rows: [Int]) -> [[Int]] {
    rows.reduce(into: []) { bands, row in
        guard let lastBand = bands.last, lastBand.last == row - 1 else {
            bands.append([row])
            return
        }

        bands[bands.count - 1].append(row)
    }
}

private struct PixelBounds {
    let minX: Int
    let minY: Int
    let maxX: Int
    let maxY: Int

    var width: Int {
        maxX - minX + 1
    }

    var height: Int {
        maxY - minY + 1
    }
}

private struct MenuBarIconTestError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
