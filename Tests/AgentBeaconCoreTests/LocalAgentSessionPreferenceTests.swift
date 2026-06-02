import AgentBeaconCore
import Foundation
import Testing

@Test func localAgentSessionPreferenceDefaultsOnInIsolatedSuite() {
    let defaults = isolatedDefaults()
    let preference = LocalAgentSessionPreference(defaults: defaults)

    #expect(preference.isEnabled == true)
    #expect(defaults.object(forKey: LocalAgentSessionPreference.key) == nil)
}

@Test func localAgentSessionPreferenceCanBeToggled() {
    let defaults = isolatedDefaults()
    let preference = LocalAgentSessionPreference(defaults: defaults)

    preference.isEnabled = true
    #expect(preference.isEnabled == true)

    preference.isEnabled = false
    #expect(preference.isEnabled == false)
}

private func isolatedDefaults() -> UserDefaults {
    let suiteName = "AgentBeaconLocalSessionPreferenceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
