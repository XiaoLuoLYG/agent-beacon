import AgentBeaconCore
import AppKit
import SwiftUI

public struct AggregateBarView: View {
    public let counts: AggregateCounts
    public let isExpanded: Bool
    public let iconSize: BeaconIconSize

    public init(counts: AggregateCounts, isExpanded: Bool, iconSize: BeaconIconSize = .defaultValue) {
        self.counts = counts
        self.isExpanded = isExpanded
        self.iconSize = iconSize
    }

    public var body: some View {
        HStack(spacing: iconSize.aggregateSpacing) {
            CountLightView(count: counts.completed, kind: .completed, iconSize: iconSize)
            CountLightView(count: counts.needsReview, kind: .needsReview, iconSize: iconSize)
            CountLightView(count: counts.failed, kind: .failed, iconSize: iconSize)
            CountLightView(count: counts.running, kind: .running, iconSize: iconSize)
        }
        .padding(.horizontal, iconSize.aggregateHorizontalPadding)
        .padding(.vertical, iconSize.aggregateVerticalPadding)
    }
}

public struct TaskListView: View {
    public let tasks: [AgentTask]
    public let iconSize: BeaconIconSize
    public let activate: (AgentTask) -> Void

    public init(
        tasks: [AgentTask],
        iconSize: BeaconIconSize = .defaultValue,
        activate: @escaping (AgentTask) -> Void
    ) {
        self.tasks = tasks
        self.iconSize = iconSize
        self.activate = activate
    }

    public var body: some View {
        VStack(spacing: 4) {
            if tasks.isEmpty {
                EmptyTaskRow(iconSize: iconSize)
            } else {
                ForEach(tasks) { task in
                    Button {
                        activate(task)
                    } label: {
                        TaskRow(task: task, iconSize: iconSize)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

public struct BeaconPanelSurfaceView<Header: View>: View {
    public let tasks: [AgentTask]
    public let expanded: Bool
    public let iconSize: BeaconIconSize
    public let header: () -> Header
    public let activate: (AgentTask) -> Void

    public init(
        tasks: [AgentTask],
        expanded: Bool,
        iconSize: BeaconIconSize = .defaultValue,
        @ViewBuilder header: @escaping () -> Header,
        activate: @escaping (AgentTask) -> Void
    ) {
        self.tasks = tasks
        self.expanded = expanded
        self.iconSize = iconSize
        self.header = header
        self.activate = activate
    }

    public var body: some View {
        let chrome = BeaconContainerChrome(isExpanded: expanded)
        GeometryReader { proxy in
            let listWidth = max(0, proxy.size.width - chrome.contentPadding * 2)
            let listHeight = max(
                0,
                proxy.size.height -
                    chrome.contentPadding * 2 -
                    iconSize.aggregateBarSize.height -
                    chrome.contentSpacing
            )

            ZStack(alignment: .topLeading) {
                header()
                    .frame(
                        width: iconSize.aggregateBarSize.width,
                        height: iconSize.aggregateBarSize.height,
                        alignment: .topLeading
                    )
                    .zIndex(1)

                ScrollView(.vertical, showsIndicators: true) {
                    TaskListView(tasks: TaskAggregator.sortedForDisplay(tasks), iconSize: iconSize, activate: activate)
                        .frame(width: listWidth, alignment: .topLeading)
                }
                .frame(width: listWidth, height: listHeight, alignment: .topLeading)
                .padding(.top, iconSize.aggregateBarSize.height + chrome.contentSpacing)
                .opacity(expanded ? 1 : 0)
                .offset(y: expanded ? 0 : -6)
                .allowsHitTesting(expanded)
                .accessibilityHidden(!expanded)
                .clipped()
                .zIndex(0)
            }
            .padding(chrome.contentPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                BeaconContainerBackground(chrome: chrome)
            }
            .clipped()
        }
    }
}

public struct BeaconTopSurfaceView: View {
    public let tasks: [AgentTask]
    public let expanded: Bool
    public let iconSize: BeaconIconSize
    public let activate: (AgentTask) -> Void

    public init(
        tasks: [AgentTask],
        expanded: Bool,
        iconSize: BeaconIconSize = .defaultValue,
        activate: @escaping (AgentTask) -> Void
    ) {
        self.tasks = tasks
        self.expanded = expanded
        self.iconSize = iconSize
        self.activate = activate
    }

    public var body: some View {
        BeaconPanelSurfaceView(
            tasks: tasks,
            expanded: expanded,
            iconSize: iconSize
        ) {
            AggregateBarView(
                counts: TaskAggregator.counts(for: tasks),
                isExpanded: expanded,
                iconSize: iconSize
            )
        } activate: { task in
            activate(task)
        }
    }
}

public struct BeaconSnapshotSurfaceView: View {
    public let tasks: [AgentTask]
    public let expanded: Bool
    public let iconSize: BeaconIconSize

    public init(tasks: [AgentTask], expanded: Bool, iconSize: BeaconIconSize = .defaultValue) {
        self.tasks = tasks
        self.expanded = expanded
        self.iconSize = iconSize
    }

    public var body: some View {
        BeaconTopSurfaceView(tasks: tasks, expanded: expanded, iconSize: iconSize) { _ in }
    }
}

private struct TaskRow: View {
    let task: AgentTask
    let iconSize: BeaconIconSize

    var body: some View {
        HStack(spacing: iconSize.rowSpacing) {
            PlatformIconView(platform: task.platform, iconSize: iconSize)

            Text(task.threadName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            StatusIndicator(status: task.status, iconSize: iconSize)
        }
        .frame(height: iconSize.rowHeight)
        .padding(.horizontal, iconSize.rowHorizontalPadding)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityLabel("\(task.platform.displayName), \(task.threadName)")
    }
}

private struct EmptyTaskRow: View {
    let iconSize: BeaconIconSize

    init(iconSize: BeaconIconSize = .defaultValue) {
        self.iconSize = iconSize
    }

    var body: some View {
        HStack(spacing: iconSize.rowSpacing) {
            PlatformIconView(platform: .genericCLI, iconSize: iconSize)
            Text("No agent tasks")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            StatusIndicator(status: .completed, iconSize: iconSize)
        }
        .frame(height: iconSize.rowHeight)
        .padding(.horizontal, iconSize.rowHorizontalPadding)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct PlatformBadge: View {
    var text: String
    let iconSize: BeaconIconSize

    init(platform: AgentPlatform, iconSize: BeaconIconSize) {
        self.text = platform.badgeText
        self.iconSize = iconSize
    }

    init(text: String, iconSize: BeaconIconSize) {
        self.text = text
        self.iconSize = iconSize
    }

    var body: some View {
        Text(text)
            .font(.system(size: iconSize.platformBadgeFontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: iconSize.platformIconDiameter, height: iconSize.platformIconDiameter)
            .background(
                Color.black.opacity(0.38),
                in: RoundedRectangle(cornerRadius: iconSize.platformIconCornerRadius, style: .continuous)
            )
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

private struct PlatformIconView: View {
    let platform: AgentPlatform
    let iconSize: BeaconIconSize

    var body: some View {
        Group {
            if let image = PlatformIconResolver.image(for: platform) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                PlatformBadge(platform: platform, iconSize: iconSize)
            }
        }
        .frame(width: iconSize.platformIconDiameter, height: iconSize.platformIconDiameter)
        .clipShape(RoundedRectangle(cornerRadius: iconSize.platformIconCornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

enum PlatformIconResolutionSource: Equatable, Sendable {
    case asset
    case appIcon
}

struct PlatformIconResolution: Equatable, Sendable {
    let image: NSImage
    let source: PlatformIconResolutionSource
    let url: URL
}

enum PlatformIconResolver {
    @MainActor
    static func image(for platform: AgentPlatform) -> NSImage? {
        resolution(for: platform)?.image
    }

    @MainActor
    static func resolution(for platform: AgentPlatform) -> PlatformIconResolution? {
        guard platform != .genericCLI else {
            return nil
        }

        for url in assetCandidates(for: platform) {
            if let image = NSImage(contentsOf: url) {
                return PlatformIconResolution(image: image, source: .asset, url: url)
            }
        }

        if let appIcon = appIcon(for: platform) {
            return appIcon
        }

        return nil
    }

    @MainActor
    private static func appIcon(for platform: AgentPlatform) -> PlatformIconResolution? {
        for appPath in appPathCandidates(for: platform) where FileManager.default.fileExists(atPath: appPath) {
            let image = NSWorkspace.shared.icon(forFile: appPath)
            return PlatformIconResolution(
                image: image,
                source: .appIcon,
                url: URL(fileURLWithPath: appPath)
            )
        }
        return nil
    }

    private static func appPathCandidates(for platform: AgentPlatform) -> [String] {
        let names: [String]
        switch platform {
        case .codex:
            names = ["Codex.app"]
        case .claudeCode:
            names = ["Claude.app"]
        case .cursor:
            names = ["Cursor.app"]
        case .geminiCLI:
            names = ["Gemini.app"]
        case .genericCLI:
            names = []
        }

        return names.flatMap { name in
            [
                "/Applications/\(name)",
                "\(NSHomeDirectory())/Applications/\(name)"
            ]
        }
    }

    private static func assetCandidates(for platform: AgentPlatform) -> [URL] {
        let fileName = "\(platform.rawValue).png"
        var candidates: [URL] = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".agent-beacon/assets/platform-icons")
                .appendingPathComponent(fileName)
        ]

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(
                resourceURL
                    .appendingPathComponent("PlatformIcons")
                    .appendingPathComponent(fileName)
            )
        }

        candidates.append(
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Assets/PlatformIcons")
                .appendingPathComponent(fileName)
        )

        return candidates
    }
}
