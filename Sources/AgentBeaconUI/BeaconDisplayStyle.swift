import Foundation
import SwiftUI

public struct BeaconContainerChrome: Equatable, Sendable {
    public let isExpanded: Bool

    public init(isExpanded: Bool) {
        self.isExpanded = isExpanded
    }

    public var usesFrostedGlass: Bool {
        isExpanded
    }

    public var drawsOuterStroke: Bool {
        false
    }

    public var cornerRadius: CGFloat {
        18
    }

    public var contentPadding: CGFloat {
        8
    }

    public var contentSpacing: CGFloat {
        8
    }

    public var aggregateLayerOpacity: Double {
        0
    }
}

public enum BeaconPanelAppearance {
    public static let drawsSystemWindowShadow = false
    public static let drawsMenuBarTopPanelSystemWindowShadow = false
}

public enum BeaconPanelAnimation {
    public static let revealDuration: TimeInterval = 0.16
    public static let reveal = Animation.easeOut(duration: revealDuration)
}

public enum BeaconIconSize: String, CaseIterable, Identifiable, Sendable {
    case compact
    case regular
    case large

    public static let defaultValue = BeaconIconSize.regular
    public static let preferenceKey = "appearance.iconSize"

    public var id: String {
        rawValue
    }

    public var menuTitle: String {
        switch self {
        case .compact:
            "Small"
        case .regular:
            "Regular"
        case .large:
            "Large"
        }
    }

    public var statusLightDiameter: CGFloat {
        switch self {
        case .compact:
            34
        case .regular:
            40
        case .large:
            48
        }
    }

    public var countFontSize: CGFloat {
        switch self {
        case .compact:
            13
        case .regular:
            15
        case .large:
            17
        }
    }

    public var aggregateSpacing: CGFloat {
        switch self {
        case .compact:
            7
        case .regular:
            8
        case .large:
            9
        }
    }

    public var aggregateHorizontalPadding: CGFloat {
        switch self {
        case .compact:
            7
        case .regular:
            8
        case .large:
            9
        }
    }

    public var aggregateVerticalPadding: CGFloat {
        switch self {
        case .compact:
            5
        case .regular:
            6
        case .large:
            7
        }
    }

    public var runningRingLineWidth: CGFloat {
        max(3, statusLightDiameter * 0.10)
    }

    public var rowHeight: CGFloat {
        switch self {
        case .compact:
            34
        case .regular:
            36
        case .large:
            40
        }
    }

    public var rowSpacing: CGFloat {
        switch self {
        case .compact:
            8
        case .regular:
            10
        case .large:
            12
        }
    }

    public var rowHorizontalPadding: CGFloat {
        switch self {
        case .compact:
            9
        case .regular:
            10
        case .large:
            12
        }
    }

    public var platformIconDiameter: CGFloat {
        switch self {
        case .compact:
            24
        case .regular:
            28
        case .large:
            32
        }
    }

    public var platformIconCornerRadius: CGFloat {
        switch self {
        case .compact:
            7
        case .regular:
            8
        case .large:
            9
        }
    }

    public var platformIconPadding: CGFloat {
        switch self {
        case .compact:
            2
        case .regular:
            3
        case .large:
            3
        }
    }

    public var platformBadgeFontSize: CGFloat {
        switch self {
        case .compact:
            9
        case .regular:
            10
        case .large:
            11
        }
    }

    public var rowStatusDiameter: CGFloat {
        switch self {
        case .compact:
            16
        case .regular:
            18
        case .large:
            21
        }
    }

    public var rowStatusLineWidth: CGFloat {
        max(2, rowStatusDiameter * 0.14)
    }

    public var aggregateBarSize: CGSize {
        CGSize(
            width: statusLightDiameter * 4 + aggregateSpacing * 3 + aggregateHorizontalPadding * 2,
            height: statusLightDiameter + aggregateVerticalPadding * 2
        )
    }

    public var collapsedPanelSize: CGSize {
        let padding = BeaconContainerChrome(isExpanded: false).contentPadding
        return CGSize(
            width: aggregateBarSize.width + padding * 2,
            height: aggregateBarSize.height + padding * 2
        )
    }

    public var expandedPanelWidth: CGFloat {
        max(390, collapsedPanelSize.width)
    }

    public func expandedPanelSize(rowCount: Int) -> CGSize {
        let chrome = BeaconContainerChrome(isExpanded: true)
        let rows = max(rowCount, 1)
        let rowStackHeight = rowHeight * CGFloat(rows) + 4 * CGFloat(max(rows - 1, 0))
        let contentHeight = chrome.contentPadding * 2 +
            aggregateBarSize.height +
            chrome.contentSpacing +
            rowStackHeight

        return CGSize(
            width: expandedPanelWidth,
            height: min(max(contentHeight, 128), 420)
        )
    }

    public static func stored(in defaults: UserDefaults = .standard) -> BeaconIconSize {
        if let value = defaults.string(forKey: preferenceKey),
           let iconSize = BeaconIconSize(rawValue: value) {
            return iconSize
        }
        return defaultValue
    }
}

public struct BeaconContainerBackground: View {
    public let chrome: BeaconContainerChrome

    public init(chrome: BeaconContainerChrome) {
        self.chrome = chrome
    }

    public var body: some View {
        ZStack {
            if chrome.usesFrostedGlass {
                RoundedRectangle(cornerRadius: chrome.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: chrome.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                RoundedRectangle(cornerRadius: chrome.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.14),
                                Color.white.opacity(0.035),
                                Color.black.opacity(0.055)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
    }
}
