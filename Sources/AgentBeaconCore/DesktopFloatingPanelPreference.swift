import Foundation

public struct DesktopFloatingPanelPreference {
    public static let key = "surface.showDesktopFloatingPanel"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        get {
            defaults.bool(forKey: Self.key)
        }
        nonmutating set {
            defaults.set(newValue, forKey: Self.key)
        }
    }
}
