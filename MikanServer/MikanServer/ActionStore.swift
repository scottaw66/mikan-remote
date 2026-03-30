import Foundation
import MikanProtocol

@Observable
final class ActionStore {
    private let fileURL: URL
    var actions: [Action]

    init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("actions.json")
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode([Action].self, from: data) {
            self.actions = loaded
        } else {
            self.actions = Action.defaults
        }
    }

    convenience init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MikanServer")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.init(directory: dir)
    }

    func save() throws {
        let data = try JSONEncoder().encode(actions)
        try data.write(to: fileURL, options: .atomic)
    }
}
