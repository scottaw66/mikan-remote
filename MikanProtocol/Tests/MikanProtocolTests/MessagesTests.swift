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
        let msg = ClientMessage.updateSettings(sensitivity: 15.0, cursorSize: 200.0, cursorDotSize: 8.0, cursorGapSize: 30.0, youtubePopupMode: "auto")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .updateSettings(let sensitivity, let cursorSize, let cursorDotSize, let cursorGapSize, let mode) = decoded else {
            XCTFail("Expected updateSettings"); return
        }
        XCTAssertEqual(sensitivity, 15.0)
        XCTAssertEqual(cursorSize, 200.0)
        XCTAssertEqual(cursorDotSize, 8.0)
        XCTAssertEqual(cursorGapSize, 30.0)
        XCTAssertEqual(mode, "auto")
    }

    func testSettingsSyncRoundTrip() throws {
        let msg = ServerMessage.settingsSync(sensitivity: 8.5, cursorSize: 120.0, cursorDotSize: 5.0, cursorGapSize: 33.0, youtubePopupMode: "auto")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        guard case .settingsSync(let sensitivity, let cursorSize, let cursorDotSize, let cursorGapSize, let mode) = decoded else {
            XCTFail("Expected settingsSync"); return
        }
        XCTAssertEqual(sensitivity, 8.5)
        XCTAssertEqual(cursorSize, 120.0)
        XCTAssertEqual(cursorDotSize, 5.0)
        XCTAssertEqual(cursorGapSize, 33.0)
        XCTAssertEqual(mode, "auto")
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

    func testUpdateSettingsRoundTripWithYouTubeMode() throws {
        let msg = ClientMessage.updateSettings(
            sensitivity: 12.0,
            cursorSize: 160.0,
            cursorDotSize: 5.0,
            cursorGapSize: 33.0,
            youtubePopupMode: "on"
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .updateSettings(let s, let cs, let ds, let gs, let mode) = decoded else {
            XCTFail("Expected updateSettings"); return
        }
        XCTAssertEqual(s, 12.0)
        XCTAssertEqual(cs, 160.0)
        XCTAssertEqual(ds, 5.0)
        XCTAssertEqual(gs, 33.0)
        XCTAssertEqual(mode, "on")
    }

    func testUpdateSettingsBackwardCompatibleDecodeWithoutMode() throws {
        // Older clients send updateSettings without youtubePopupMode — must decode with "auto".
        let json = #"{"type":"updateSettings","sensitivity":10.0,"cursorSize":140.0,"cursorDotSize":5.0,"cursorGapSize":33.0}"#
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .updateSettings(_, _, _, _, let mode) = decoded else {
            XCTFail("Expected updateSettings"); return
        }
        XCTAssertEqual(mode, "auto")
    }

    func testSettingsSyncRoundTripWithYouTubeMode() throws {
        let msg = ServerMessage.settingsSync(
            sensitivity: 8.5,
            cursorSize: 100.0,
            cursorDotSize: 4.0,
            cursorGapSize: 30.0,
            youtubePopupMode: "off"
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        guard case .settingsSync(let s, let cs, let ds, let gs, let mode) = decoded else {
            XCTFail("Expected settingsSync"); return
        }
        XCTAssertEqual(s, 8.5)
        XCTAssertEqual(cs, 100.0)
        XCTAssertEqual(ds, 4.0)
        XCTAssertEqual(gs, 30.0)
        XCTAssertEqual(mode, "off")
    }

    func testSettingsSyncBackwardCompatibleDecodeWithoutMode() throws {
        let json = #"{"type":"settingsSync","sensitivity":10.0,"cursorSize":140.0,"cursorDotSize":5.0,"cursorGapSize":33.0}"#
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        guard case .settingsSync(_, _, _, _, let mode) = decoded else {
            XCTFail("Expected settingsSync"); return
        }
        XCTAssertEqual(mode, "auto")
    }

    func testYouTubeCommandRoundTrips() throws {
        let names = [
            "ytPrevVideo", "ytNextVideo",
            "ytPrevChapter", "ytNextChapter",
            "ytToggleCaptions",
            "ytSlowDown", "ytSpeedUp",
            "ytFullscreen",
            "ytPlayPause"
        ]
        for name in names {
            let msg = ClientMessage.performCommand(command: name)
            let data = try JSONEncoder().encode(msg)
            let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
            guard case .performCommand(let command) = decoded else {
                XCTFail("Expected performCommand for \(name)"); return
            }
            XCTAssertEqual(command, name, "Round-trip failed for \(name)")
        }
    }

    func testAudioDeviceRoundTrip() throws {
        let device = AudioDevice(id: "AppleHDAEngineOutput:1F,3,0,1:0", name: "Studio Display Speakers")
        let data = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(AudioDevice.self, from: data)
        XCTAssertEqual(decoded.id, "AppleHDAEngineOutput:1F,3,0,1:0")
        XCTAssertEqual(decoded.name, "Studio Display Speakers")
    }

    func testAudioDevicesServerMessageRoundTrip() throws {
        let devices = [
            AudioDevice(id: "uid-1", name: "Studio Display Speakers"),
            AudioDevice(id: "uid-2", name: "AirPods Pro")
        ]
        let msg = ServerMessage.audioDevices(devices: devices, currentDeviceId: "uid-2")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        guard case .audioDevices(let decodedDevices, let currentId) = decoded else {
            XCTFail("Expected audioDevices"); return
        }
        XCTAssertEqual(decodedDevices.count, 2)
        XCTAssertEqual(decodedDevices[1].name, "AirPods Pro")
        XCTAssertEqual(currentId, "uid-2")
    }

    func testAudioDevicesJSONShape() throws {
        let msg = ServerMessage.audioDevices(
            devices: [AudioDevice(id: "uid-1", name: "Speakers")],
            currentDeviceId: "uid-1"
        )
        let data = try JSONEncoder().encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "audioDevices")
        XCTAssertEqual(json["currentDeviceId"] as? String, "uid-1")
        let devices = json["devices"] as! [[String: Any]]
        XCTAssertEqual(devices[0]["id"] as? String, "uid-1")
        XCTAssertEqual(devices[0]["name"] as? String, "Speakers")
    }

    func testSetAudioDeviceRoundTrip() throws {
        let msg = ClientMessage.setAudioDevice(deviceId: "uid-2")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .setAudioDevice(let deviceId) = decoded else {
            XCTFail("Expected setAudioDevice"); return
        }
        XCTAssertEqual(deviceId, "uid-2")
    }

    func testSetAudioDeviceJSONShape() throws {
        let msg = ClientMessage.setAudioDevice(deviceId: "uid-2")
        let data = try JSONEncoder().encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "setAudioDevice")
        XCTAssertEqual(json["deviceId"] as? String, "uid-2")
    }
}
