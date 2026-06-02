import AppKit
import Foundation

public enum MenuBarTemplateIconFactory {
    public static let defaultSize = NSSize(width: 22, height: 18)

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
                roundedRect: NSRect(x: 2, y: 5, width: 18, height: 9),
                xRadius: 4.5,
                yRadius: 4.5
            )
            capsule.fill()

            context.cgContext.setBlendMode(.clear)
            for centerX in [7.0, 11.0, 15.0] {
                NSBezierPath(ovalIn: NSRect(x: centerX - 1.2, y: 8.3, width: 2.4, height: 2.4)).fill()
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
