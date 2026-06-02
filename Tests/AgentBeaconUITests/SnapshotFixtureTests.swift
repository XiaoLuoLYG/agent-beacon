import AgentBeaconCore
import AgentBeaconUI
import Foundation
import Testing

@Test func snapshotFixtureCoversEveryVisibleStatus() {
    let counts = TaskAggregator.counts(for: SnapshotFixture.tasks)

    #expect(counts.needsReview == 1)
    #expect(counts.failed == 1)
    #expect(counts.running == 1)
    #expect(counts.completed == 1)
}

@Test func snapshotFixtureCoversEveryNamedAgentPlatform() {
    let platforms = Set(SnapshotFixture.tasks.map(\.platform))

    #expect(platforms == Set([.codex, .claudeCode, .cursor, .geminiCLI]))
}

@Test func runningRingAnimationUsesCumulativeCoreAnimationRotation() {
    #expect(RunningRingAnimation.rotationRadians == -Double.pi * 2)
    #expect(RunningRingAnimation.duration > 0)
    #expect(RunningRingAnimation.duration < 2)
}

@Test func containerChromeOnlyUsesFrostedGlassWhenExpanded() {
    let collapsedChrome = BeaconContainerChrome(isExpanded: false)
    let expandedChrome = BeaconContainerChrome(isExpanded: true)

    #expect(collapsedChrome.usesFrostedGlass == false)
    #expect(collapsedChrome.drawsOuterStroke == false)
    #expect(collapsedChrome.aggregateLayerOpacity == 0)
    #expect(expandedChrome.usesFrostedGlass == true)
    #expect(expandedChrome.drawsOuterStroke == false)
    #expect(expandedChrome.aggregateLayerOpacity == 0)
}

@Test func floatingPanelDoesNotDrawSystemWindowShadow() {
    #expect(BeaconPanelAppearance.drawsSystemWindowShadow == false)
}

@Test func menuBarTopPanelDoesNotDrawSystemWindowShadow() {
    #expect(BeaconPanelAppearance.drawsMenuBarTopPanelSystemWindowShadow == false)
}

@Test func iconSizeModesKeepRegularAsCurrentDefault() {
    #expect(BeaconIconSize.defaultValue == .regular)
    #expect(BeaconIconSize.allCases.map(\.rawValue) == ["compact", "regular", "large"])
    #expect(BeaconIconSize.regular.statusLightDiameter == 40)
    #expect(BeaconIconSize.compact.statusLightDiameter < BeaconIconSize.regular.statusLightDiameter)
    #expect(BeaconIconSize.large.statusLightDiameter > BeaconIconSize.regular.statusLightDiameter)
}
