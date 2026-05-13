import XCTest
@testable import MikanRemote

final class SharedDefaultsTests: XCTestCase {
    private var tempDir: URL!
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SharedDefaultsTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("pendingShareURL.txt")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testPendingShareURLStartsNil() {
        let s = SharedDefaults(fileURL: fileURL)
        XCTAssertNil(s.pendingShareURL)
    }

    func testPendingShareURLRoundTrips() {
        let s = SharedDefaults(fileURL: fileURL)
        s.pendingShareURL = "https://example.com/foo"
        XCTAssertEqual(s.pendingShareURL, "https://example.com/foo")
    }

    func testPendingShareURLClears() {
        let s = SharedDefaults(fileURL: fileURL)
        s.pendingShareURL = "https://example.com"
        s.pendingShareURL = nil
        XCTAssertNil(s.pendingShareURL)
    }

    func testTwoInstancesShareSameStorage() {
        let a = SharedDefaults(fileURL: fileURL)
        let b = SharedDefaults(fileURL: fileURL)
        a.pendingShareURL = "https://example.com/share"
        XCTAssertEqual(b.pendingShareURL, "https://example.com/share")
    }

    func testWritesAreImmediatelyVisibleToFreshInstance() {
        // This is the key cross-process property: a write from one process
        // must be visible to a fresh read from another. UserDefaults fails this
        // when an in-process cache holds a stale value.
        let writer = SharedDefaults(fileURL: fileURL)
        writer.pendingShareURL = "https://example.com/cross-process"
        let reader = SharedDefaults(fileURL: fileURL)
        XCTAssertEqual(reader.pendingShareURL, "https://example.com/cross-process")
    }
}
