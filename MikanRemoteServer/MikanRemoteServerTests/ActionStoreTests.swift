import XCTest
@testable import MikanRemoteServer
import MikanProtocol

final class ActionStoreTests: XCTestCase {

    var tempDir: URL!
    var store: ActionStore!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = ActionStore(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testLoadsDefaultsWhenNoFile() {
        XCTAssertEqual(store.actions, Action.defaults)
    }

    func testSaveAndLoad() throws {
        let custom = [Action(id: "test", label: "Test", url: "https://example.com")]
        store.actions = custom
        try store.save()

        let reloaded = ActionStore(directory: tempDir)
        XCTAssertEqual(reloaded.actions, custom)
    }

    func testSaveCreatesFile() throws {
        try store.save()
        let filePath = tempDir.appendingPathComponent("actions.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath.path))
    }
}
