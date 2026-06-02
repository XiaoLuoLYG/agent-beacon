import AgentBeaconCore
import AppKit
import QuartzCore
import SwiftUI

public enum StatusVisualKind {
    case needsReview
    case failed
    case running
    case completed
}

public extension StatusVisualKind {
    init(status: AgentTaskStatus) {
        switch status {
        case .needsReview:
            self = .needsReview
        case .failed:
            self = .failed
        case .running:
            self = .running
        case .completed:
            self = .completed
        }
    }

    var color: Color {
        switch self {
        case .needsReview:
            Color(red: 1.0, green: 0.72, blue: 0.16)
        case .failed:
            Color(red: 0.93, green: 0.19, blue: 0.22)
        case .running:
            Color(red: 0.32, green: 0.62, blue: 1.0)
        case .completed:
            Color(red: 0.19, green: 0.78, blue: 0.38)
        }
    }

    var nsColor: NSColor {
        switch self {
        case .needsReview:
            NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.16, alpha: 1.0)
        case .failed:
            NSColor(calibratedRed: 0.93, green: 0.19, blue: 0.22, alpha: 1.0)
        case .running:
            NSColor(calibratedRed: 0.32, green: 0.62, blue: 1.0, alpha: 1.0)
        case .completed:
            NSColor(calibratedRed: 0.19, green: 0.78, blue: 0.38, alpha: 1.0)
        }
    }

    var shadowColor: Color {
        color.opacity(0.42)
    }
}

public struct CountLightView: View {
    public let count: Int
    public let kind: StatusVisualKind
    public let iconSize: BeaconIconSize

    public init(count: Int, kind: StatusVisualKind, iconSize: BeaconIconSize = .defaultValue) {
        self.count = count
        self.kind = kind
        self.iconSize = iconSize
    }

    public var body: some View {
        ZStack {
            if kind == .running {
                RunningRing(
                    size: iconSize.statusLightDiameter,
                    lineWidth: iconSize.runningRingLineWidth,
                    color: kind.nsColor
                )
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [kind.color.opacity(0.98), kind.color.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: kind.shadowColor, radius: 7, x: 0, y: 0)
            }

            Text("\(count)")
                .font(.system(size: iconSize.countFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(width: iconSize.statusLightDiameter, height: iconSize.statusLightDiameter)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch kind {
        case .needsReview:
            "\(count) waiting for review"
        case .failed:
            "\(count) failed"
        case .running:
            "\(count) running"
        case .completed:
            "\(count) completed"
        }
    }
}

public struct StatusIndicator: View {
    public let status: AgentTaskStatus
    public let iconSize: BeaconIconSize

    public init(status: AgentTaskStatus, iconSize: BeaconIconSize = .defaultValue) {
        self.status = status
        self.iconSize = iconSize
    }

    public var body: some View {
        let kind = StatusVisualKind(status: status)
        ZStack {
            if kind == .running {
                RunningRing(
                    size: iconSize.rowStatusDiameter,
                    lineWidth: iconSize.rowStatusLineWidth,
                    color: kind.nsColor
                )
            } else {
                Circle()
                    .fill(kind.color)
                    .shadow(color: kind.shadowColor, radius: 4, x: 0, y: 0)
                }
        }
        .frame(width: iconSize.rowStatusDiameter, height: iconSize.rowStatusDiameter)
        .accessibilityLabel(status.rawValue)
    }
}

private struct RunningRing: View {
    let size: CGFloat
    let lineWidth: CGFloat
    let color: NSColor

    var body: some View {
        RunningRingLayerView(size: size, lineWidth: lineWidth, color: color)
            .frame(width: size, height: size)
            .shadow(
                color: Color(nsColor: color).opacity(0.34),
                radius: 6,
                x: 0,
                y: 0
            )
    }
}

public enum RunningRingAnimation {
    public static let duration: TimeInterval = 1.05
    public static let rotationRadians = -Double.pi * 2
}

private struct RunningRingLayerView: NSViewRepresentable {
    let size: CGFloat
    let lineWidth: CGFloat
    let color: NSColor

    func makeNSView(context: Context) -> RunningRingNSView {
        let view = RunningRingNSView()
        view.configure(size: size, lineWidth: lineWidth, color: color)
        return view
    }

    func updateNSView(_ nsView: RunningRingNSView, context: Context) {
        nsView.configure(size: size, lineWidth: lineWidth, color: color)
    }
}

private final class RunningRingNSView: NSView {
    private let ringLayer = CAShapeLayer()
    private var currentSize: CGFloat = 0
    private var currentLineWidth: CGFloat = 0
    private var currentColor: NSColor = .systemBlue

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor

        ringLayer.fillColor = NSColor.clear.cgColor
        ringLayer.lineCap = .round
        ringLayer.strokeStart = 0.18
        ringLayer.strokeEnd = 0.86
        layer?.addSublayer(ringLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(size: CGFloat, lineWidth: CGFloat, color: NSColor) {
        currentSize = size
        currentLineWidth = lineWidth
        currentColor = color
        ringLayer.lineWidth = lineWidth
        ringLayer.strokeColor = color.cgColor
        needsLayout = true
        ensureAnimation()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringLayer.frame = bounds
        let inset = currentLineWidth / 2
        let pathRect = bounds.insetBy(dx: inset, dy: inset)
        ringLayer.path = CGPath(ellipseIn: pathRect, transform: nil)
        CATransaction.commit()
        ensureAnimation()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        ensureAnimation()
    }

    private func ensureAnimation() {
        guard window != nil else { return }
        guard ringLayer.animation(forKey: "agentBeacon.runningRotation") == nil else { return }

        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.byValue = RunningRingAnimation.rotationRadians
        animation.duration = RunningRingAnimation.duration
        animation.repeatCount = .infinity
        animation.isCumulative = true
        animation.isRemovedOnCompletion = false
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        ringLayer.add(animation, forKey: "agentBeacon.runningRotation")
    }
}
