import Foundation

protocol PendingURLStore: AnyObject {
    var pendingShareURL: String? { get set }
}

// File-backed because UserDefaults shared between the app and extension races:
// the extension's set propagates to cfprefsd asynchronously and the host's
// in-process cache invalidates only on a Darwin notification, so the host's
// first read after foregrounding regularly returns nil.
final class SharedDefaults: PendingURLStore {
    static let shared: SharedDefaults = {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "MikanAppGroupIdentifier") as? String,
              !id.isEmpty else {
            preconditionFailure("MikanAppGroupIdentifier missing or empty in Info.plist — main app and share extension cannot share state")
        }
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) else {
            preconditionFailure("App Group container URL nil for \(id) — entitlement likely misconfigured")
        }
        return SharedDefaults(fileURL: container.appendingPathComponent("pendingShareURL.txt"))
    }()

    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    var pendingShareURL: String? {
        get {
            guard let data = try? Data(contentsOf: fileURL),
                  let str = String(data: data, encoding: .utf8),
                  !str.isEmpty else { return nil }
            return str
        }
        set {
            if let newValue, let data = newValue.data(using: .utf8) {
                try? data.write(to: fileURL, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}
