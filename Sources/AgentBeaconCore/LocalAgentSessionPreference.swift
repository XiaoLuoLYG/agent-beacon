import Foundation

public struct LocalAgentSessionPreference {
    public static let key = "adapters.showLocalAgentSessions"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        get {
            guard defaults.object(forKey: Self.key) != nil else {
                return true
            }
            return defaults.bool(forKey: Self.key)
        }
        nonmutating set {
            defaults.set(newValue, forKey: Self.key)
        }
    }
}
