import XCTest
@testable import MikanRemote

final class SharedDefaultsTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testPendingShareURLStartsNil() {
        let s = SharedDefaults(defaults: userDefaults)
        XCTAssertNil(s.pendingShareURL)
    }

    func testPendingShareURLRoundTrips() {
        let s = SharedDefaults(defaults: userDefaults)
        s.pendingShareURL = "https://example.com/foo"
        XCTAssertEqual(s.pendingShareURL, "https://example.com/foo")
    }

    func testPendingShareURLClears() {
        let s = SharedDefaults(defaults: userDefaults)
        s.pendingShareURL = "https://example.com"
        s.pendingShareURL = nil
        XCTAssertNil(s.pendingShareURL)
    }

    func testTwoInstancesShareSameStorage() {
        let a = SharedDefaults(defaults: userDefaults)
        let b = SharedDefaults(defaults: userDefaults)
        a.pendingShareURL = "https://example.com/share"
        XCTAssertEqual(b.pendingShareURL, "https://example.com/share")
    }
}
