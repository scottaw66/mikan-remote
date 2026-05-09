import Foundation

@Observable
final class PairingStore {
    private(set) var pairedDeviceIds: Set<String> = []
    private(set) var pendingCode: String?
    private(set) var pendingDeviceId: String?

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MikanRemoteServer")
        let legacyDir = appSupport.appendingPathComponent("MikanServer")
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path), fm.fileExists(atPath: legacyDir.path) {
            try? fm.moveItem(at: legacyDir, to: dir)
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("paired-devices.json")
        load()
    }

    func isDevicePaired(_ deviceId: String) -> Bool {
        pairedDeviceIds.contains(deviceId)
    }

    func generateCode(for deviceId: String) -> String {
        let code = String(format: "%04d", Int.random(in: 0...9999))
        pendingCode = code
        pendingDeviceId = deviceId
        return code
    }

    func validateCode(_ code: String) -> Bool {
        guard let pending = pendingCode, let deviceId = pendingDeviceId else { return false }
        if code == pending {
            pairedDeviceIds.insert(deviceId)
            pendingCode = nil
            pendingDeviceId = nil
            save()
            return true
        }
        return false
    }

    func clearPending() {
        pendingCode = nil
        pendingDeviceId = nil
    }

    func unpairAll() {
        pairedDeviceIds.removeAll()
        pendingCode = nil
        pendingDeviceId = nil
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else { return }
        pairedDeviceIds = ids
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(pairedDeviceIds) else { return }
        try? data.write(to: fileURL)
    }
}
