import Foundation

final class SharedDefaults {
    static let shared: SharedDefaults = {
        let id = Bundle.main.object(forInfoDictionaryKey: "MikanAppGroupIdentifier") as? String ?? ""
        let defaults = UserDefaults(suiteName: id) ?? .standard
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
