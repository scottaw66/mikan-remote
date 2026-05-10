import Foundation

final class SharedDefaults {
    static let shared: SharedDefaults = {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "MikanAppGroupIdentifier") as? String,
              !id.isEmpty else {
            preconditionFailure("MikanAppGroupIdentifier missing or empty in Info.plist — main app and share extension cannot share state")
        }
        guard let defaults = UserDefaults(suiteName: id) else {
            preconditionFailure("UserDefaults(suiteName:) returned nil for \(id) — App Group entitlement likely misconfigured")
        }
        return SharedDefaults(defaults: defaults)
    }()

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var pendingShareURL: String? {
        get { defaults.string(forKey: Keys.pendingShareURL) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Keys.pendingShareURL)
            } else {
                defaults.removeObject(forKey: Keys.pendingShareURL)
            }
        }
    }

    private enum Keys {
        static let pendingShareURL = "pendingShareURL"
    }
}
