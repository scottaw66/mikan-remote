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
        let msg = ClientMessage.mouseClick
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .mouseClick = decoded else {
            XCTFail("Expected mouseClick"); return
        }
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

    func testPerformCommandRoundTrip() throws {
        let msg = ClientMessage.performCommand(command: "fullscreen")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .performCommand(let command) = decoded else {
            XCTFail("Expected performCommand"); return
        }
        XCTAssertEqual(command, "fullscreen")
    }

    func testHelloRoundTrip() throws {
        let msg = ClientMessage.hello(deviceId: "test-uuid-123")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .hello(let deviceId) = decoded else {
            XCTFail("Expected hello"); return
        }
        XCTAssertEqual(deviceId, "test-uuid-123")
    }

    func testPairResponseRoundTrip() throws {
        let msg = ClientMessage.pairResponse(code: "1234")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .pairResponse(let code) = decoded else {
            XCTFail("Expected pairResponse"); return
        }
        XCTAssertEqual(code, "1234")
    }

    func testPairRequiredRoundTrip() throws {
        let msg = ServerMessage.pairRequired
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        guard case .pairRequired = decoded else {
            XCTFail("Expected pairRequired"); return
        }
    }

    func testPairAcceptedRoundTrip() throws {
        let msg = ServerMessage.pairAccepted
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        guard case .pairAccepted = decoded else {
            XCTFail("Expected pairAccepted"); return
        }
    }

    func testPairRejectedRoundTrip() throws {
        let msg = ServerMessage.pairRejected(reason: "Invalid code")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        guard case .pairRejected(let reason) = decoded else {
            XCTFail("Expected pairRejected"); return
        }
        XCTAssertEqual(reason, "Invalid code")
    }

    func testUpdateSettingsRoundTrip() throws {
        let msg = ClientMessage.updateSettings(sensitivity: 15.0, cursorSize: 200.0, cursorDotSize: 8.0, cursorGapSize: 30.0)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .updateSettings(let sensitivity, let cursorSize, let cursorDotSize, let cursorGapSize) = decoded else {
            XCTFail("Expected updateSettings"); return
        }
        XCTAssertEqual(sensitivity, 15.0)
        XCTAssertEqual(cursorSize, 200.0)
        XCTAssertEqual(cursorDotSize, 8.0)
        XCTAssertEqual(cursorGapSize, 30.0)
    }

    func testSettingsSyncRoundTrip() throws {
        let msg = ServerMessage.settingsSync(sensitivity: 8.5, cursorSize: 120.0, cursorDotSize: 5.0, cursorGapSize: 33.0)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        guard case .settingsSync(let sensitivity, let cursorSize, let cursorDotSize, let cursorGapSize) = decoded else {
            XCTFail("Expected settingsSync"); return
        }
        XCTAssertEqual(sensitivity, 8.5)
        XCTAssertEqual(cursorSize, 120.0)
        XCTAssertEqual(cursorDotSize, 5.0)
        XCTAssertEqual(cursorGapSize, 33.0)
    }

    func testUpdateActionsRoundTrip() throws {
        let actions = [Action(id: "test", label: "Test", url: "https://test.com", icon: "star")]
        let msg = ClientMessage.updateActions(actions: actions)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .updateActions(let decodedActions) = decoded else {
            XCTFail("Expected updateActions"); return
        }
        XCTAssertEqual(decodedActions.count, 1)
        XCTAssertEqual(decodedActions[0].id, "test")
        XCTAssertEqual(decodedActions[0].url, "https://test.com")
    }

    func testActionDefaultConfig() {
        let defaults = Action.defaults
        XCTAssertTrue(defaults.contains(where: { $0.url == "https://netflix.com" }))
    }
}
