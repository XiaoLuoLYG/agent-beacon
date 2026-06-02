import AgentBeaconCore
import Foundation
import Testing

@Test func desktopFloatingPanelPreferenceDefaultsOffInIsolatedSuite() {
    let defaults = isolatedDefaults()
    let preference = DesktopFloatingPanelPreference(defaults: defaults)

    #expect(preference.isEnabled == false)
    #expect(defaults.object(forKey: DesktopFloatingPanelPreference.key) == nil)
}

@Test func desktopFloatingPanelPreferenceCanBeEnabled() {
    let defaults = isolatedDefaults()
    let preference = DesktopFloatingPanelPreference(defaults: defaults)

    preference.isEnabled = true

    #expect(preference.isEnabled == true)
    #expect(defaults.bool(forKey: DesktopFloatingPanelPreference.key) == true)
}

@Test func desktopFloatingPanelPreferenceCanBeDisabledAfterBeingEnabled() {
    let defaults = isolatedDefaults()
    let preference = DesktopFloatingPanelPreference(defaults: defaults)
    preference.isEnabled = true

    preference.isEnabled = false

    #expect(preference.isEnabled == false)
    #expect(defaults.bool(forKey: DesktopFloatingPanelPreference.key) == false)
}

private func isolatedDefaults() -> UserDefaults {
    let suiteName = "AgentBeaconPreferenceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
