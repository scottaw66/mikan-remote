import XCTest
import ApplicationServices
@testable import MikanServer

final class MouseControllerTests: XCTestCase {

    func testMoveUpdatesPosition() throws {
        try XCTSkipUnless(AXIsProcessTrusted(), "Requires Accessibility permission")
        let controller = MouseController()
        let before = CGEvent(source: nil)!.location
        controller.move(deltaX: 10, deltaY: 0, sensitivity: 1.0)
        let after = CGEvent(source: nil)!.location
        // The cursor should have moved right by ~10 points
        XCTAssertEqual(after.x, before.x + 10, accuracy: 2.0)
        XCTAssertEqual(after.y, before.y, accuracy: 2.0)
    }

    func testSensitivityMultiplier() throws {
        try XCTSkipUnless(AXIsProcessTrusted(), "Requires Accessibility permission")
        let controller = MouseController()
        let before = CGEvent(source: nil)!.location
        controller.move(deltaX: 10, deltaY: 0, sensitivity: 2.0)
        let after = CGEvent(source: nil)!.location
        XCTAssertEqual(after.x, before.x + 20, accuracy: 2.0)
    }

    func testClickDoesNotCrash() {
        let controller = MouseController()
        // Just verify it doesn't throw/crash — click at current position
        controller.click()
    }

    func testScrollDoesNotCrash() {
        let controller = MouseController()
        controller.scroll(deltaX: 0, deltaY: -3)
    }
}
