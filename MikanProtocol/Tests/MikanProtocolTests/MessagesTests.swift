import XCTest
@testable import MikanProtocol

final class MessagesTests: XCTestCase {

    func testMouseMoveRoundTrip() throws {
        let msg = ClientMessage.mouseMove(deltaX: 12.5, deltaY: -3.0)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .mouseMove(let dx, let dy) = decoded else {
            XCTFail("Expected mouseMove"); return
        }
        XCTAssertEqual(dx, 12.5)
        XCTAssertEqual(dy, -3.0)
    }

    func testMouseClickRoundTrip() throws {
        let msg = ClientMessage.mouseClick(button: .left)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .mouseClick(let button) = decoded else {
            XCTFail("Expected mouseClick"); return
        }
        XCTAssertEqual(button, .left)
    }

    func testMouseScrollRoundTrip() throws {
        let msg = ClientMessage.mouseScroll(deltaX: 0, deltaY: -5.0)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .mouseScroll(let dx, let dy) = decoded else {
            XCTFail("Expected mouseScroll"); return
        }
        XCTAssertEqual(dx, 0)
        XCTAssertEqual(dy, -5.0)
    }

    func testOpenURLRoundTrip() throws {
        let msg = ClientMessage.openURL(url: "https://netflix.com")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .openURL(let url) = decoded else {
            XCTFail("Expected openURL"); return
        }
        XCTAssertEqual(url, "https://netflix.com")
    }

    func testActionConfigRoundTrip() throws {
        let action = Action(id: "netflix", label: "Netflix", url: "https://netflix.com", icon: "play.tv")
        let msg = ServerMessage.actionConfig(actions: [action])
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        guard case .actionConfig(let actions) = decoded else {
            XCTFail("Expected actionConfig"); return
        }
        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions[0].id, "netflix")
        XCTAssertEqual(actions[0].icon, "play.tv")
    }

    func testServerStatusRoundTrip() throws {
        let msg = ServerMessage.serverStatus(connected: true, hostname: "Scott's Mac")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        guard case .serverStatus(let connected, let hostname) = decoded else {
            XCTFail("Expected serverStatus"); return
        }
        XCTAssertTrue(connected)
        XCTAssertEqual(hostname, "Scott's Mac")
    }

    func testMouseMoveJSON() throws {
        let msg = ClientMessage.mouseMove(deltaX: 1.0, deltaY: 2.0)
        let data = try JSONEncoder().encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "mouseMove")
        XCTAssertEqual(json["deltaX"] as? Double, 1.0)
        XCTAssertEqual(json["deltaY"] as? Double, 2.0)
    }

    func testActionDefaultConfig() {
        let defaults = Action.defaults
        XCTAssertTrue(defaults.contains(where: { $0.url == "https://netflix.com" }))
        XCTAssertTrue(defaults.contains(where: { $0.url == "https://youtube.com" }))
    }
}
