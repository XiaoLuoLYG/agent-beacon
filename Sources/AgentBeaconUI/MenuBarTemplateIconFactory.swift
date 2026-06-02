import AppKit
import Foundation

public enum MenuBarTemplateIconFactory {
    public static let defaultSize = NSSize(width: 24, height: 18)

    public static func makeImage(size: NSSize = defaultSize) -> NSImage {
        let pixelWidth = max(1, Int(size.width.rounded(.up)))
        let pixelHeight = max(1, Int(size.height.rounded(.up)))
        let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        representation.size = size

        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: representation) {
            NSGraphicsContext.current = context
            context.cgContext.clear(CGRect(origin: .zero, size: size))
            NSColor.black.setFill()

            let capsule = NSBezierPath(
                roundedRect: NSRect(x: 2, y: 4, width: 20, height: 10),
                xRadius: 5,
                yRadius: 5
            )
            capsule.fill()

            context.cgContext.setBlendMode(.clear)
            for centerX in [7.5, 12.0, 16.5] {
                NSBezierPath(ovalIn: NSRect(x: centerX - 1.35, y: 7.65, width: 2.7, height: 2.7)).fill()
            }
            context.cgContext.setBlendMode(.normal)
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(representation)
        image.isTemplate = true
        return image
    }
}
