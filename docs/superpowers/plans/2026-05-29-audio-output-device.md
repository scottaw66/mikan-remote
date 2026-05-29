# Audio Output Device Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user pick the Mac's default audio output device (Studio Display speakers, AirPods, etc.) from a new "Audio Output" section in the iPhone Utilities sheet, with the device list updating live.

**Architecture:** A new `AudioDevice` type plus two messages (`ServerMessage.audioDevices`, `ClientMessage.setAudioDevice`) extend the existing flat-JSON WebSocket protocol. On macOS, a new `AudioDeviceController` wraps the CoreAudio HAL to enumerate output devices, switch the default, and fire a callback on live changes via property listeners. `MenuBarManager` pushes the device list on connect and on change, and switches on request. The iPhone `ConnectionManager` holds the device list as observable state, rendered as a tappable list in `UtilitiesView`.

**Tech Stack:** Swift, CoreAudio (AudioToolbox HAL), Network.framework WebSocket, SwiftUI, XCTest, xcodegen.

**Reference spec:** `docs/superpowers/specs/2026-05-29-audio-output-device-design.md`

---

## File Structure

- **Modify** `MikanProtocol/Sources/MikanProtocol/Messages.swift` — add `AudioDevice` struct, `ServerMessage.audioDevices`, `ClientMessage.setAudioDevice`.
- **Modify** `MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift` — round-trip + JSON-shape tests for the new types.
- **Create** `MikanRemoteServer/MikanRemoteServer/AudioDeviceController.swift` — CoreAudio HAL wrapper (enumerate, switch, live listeners).
- **Modify** `MikanRemoteServer/MikanRemoteServer/MenuBarManager.swift` — own the controller, push on connect/change, handle `setAudioDevice`.
- **Modify** `MikanRemote/MikanRemote/ConnectionManager.swift` — observable `audioDevices` / `currentAudioDeviceId`, handle the server message, `sendSetAudioDevice`.
- **Modify** `MikanRemote/MikanRemote/UtilitiesView.swift` — new "Audio Output" section.

---

## Task 1: Add `AudioDevice` type and protocol messages

**Files:**
- Modify: `MikanProtocol/Sources/MikanProtocol/Messages.swift`
- Test: `MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift`

- [ ] **Step 1: Write the failing tests**

Append these tests to `MessagesTests.swift` (inside the `final class MessagesTests` body, before the closing brace):

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd MikanProtocol && swift test 2>&1 | tail -20`
Expected: Compile failure — `AudioDevice` is undefined and `.audioDevices` / `.setAudioDevice` are not members of the message enums.

- [ ] **Step 3: Add the `AudioDevice` struct**

In `Messages.swift`, add at the top after `import Foundation` (before `public enum ClientMessage`):

```swift
public struct AudioDevice: Codable, Sendable, Identifiable, Equatable {
    public let id: String   // persistent CoreAudio device UID
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
```

- [ ] **Step 4: Add the `ClientMessage.setAudioDevice` case**

In `ClientMessage`:

1. Add the case to the enum (after `case updateActions(actions: [Action])`):
```swift
    case setAudioDevice(deviceId: String)
```
2. Add `deviceId` to `CodingKeys` (append to the existing list):
```swift
        case type, deltaX, deltaY, url, command, deviceId, code, sensitivity, cursorSize, cursorDotSize, cursorGapSize, actions, youtubePopupMode
```
(`deviceId` is already present — reuse it.)
3. Add a decode branch in `init(from:)` (before `default:`):
```swift
        case "setAudioDevice":
            let deviceId = try container.decode(String.self, forKey: .deviceId)
            self = .setAudioDevice(deviceId: deviceId)
```
4. Add an encode branch in `encode(to:)` (after the `.updateActions` case):
```swift
        case .setAudioDevice(let deviceId):
            try container.encode("setAudioDevice", forKey: .type)
            try container.encode(deviceId, forKey: .deviceId)
```

Note: `deviceId` already exists in `ClientMessage.CodingKeys` (used by `hello`). Do not add a duplicate key — reuse it.

- [ ] **Step 5: Add the `ServerMessage.audioDevices` case**

In `ServerMessage`:

1. Add the case to the enum (after `case settingsSync(...)`):
```swift
    case audioDevices(devices: [AudioDevice], currentDeviceId: String)
```
2. Add the new keys to `CodingKeys`:
```swift
        case type, actions, connected, hostname, reason, sensitivity, cursorSize, cursorDotSize, cursorGapSize, youtubePopupMode, devices, currentDeviceId
```
3. Add a decode branch in `init(from:)` (before `default:`):
```swift
        case "audioDevices":
            let devices = try container.decode([AudioDevice].self, forKey: .devices)
            let currentDeviceId = try container.decode(String.self, forKey: .currentDeviceId)
            self = .audioDevices(devices: devices, currentDeviceId: currentDeviceId)
```
4. Add an encode branch in `encode(to:)` (after the `.settingsSync` case):
```swift
        case .audioDevices(let devices, let currentDeviceId):
            try container.encode("audioDevices", forKey: .type)
            try container.encode(devices, forKey: .devices)
            try container.encode(currentDeviceId, forKey: .currentDeviceId)
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd MikanProtocol && swift test 2>&1 | tail -20`
Expected: All tests pass, including the five new ones.

- [ ] **Step 7: Commit**

```bash
git add MikanProtocol/Sources/MikanProtocol/Messages.swift MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift
git commit -m "feat(protocol): add AudioDevice type and audio output messages"
```

---

## Task 2: Create `AudioDeviceController` on the server

**Files:**
- Create: `MikanRemoteServer/MikanRemoteServer/AudioDeviceController.swift`

This is CoreAudio HAL code that cannot be unit-tested without real hardware; verification is a build + the manual test in Task 5. Write the whole file as specified.

- [ ] **Step 1: Write the controller**

Create `MikanRemoteServer/MikanRemoteServer/AudioDeviceController.swift` with exactly this content:

```swift
import Foundation
import CoreAudio
import MikanProtocol

/// Wraps the CoreAudio HAL to enumerate output devices, switch the system
/// default output, and notify on live device/selection changes.
final class AudioDeviceController {
    /// Fired (on the main queue) whenever the device list or default output changes.
    var onChange: (() -> Void)?

    private var listenerBlock: AudioObjectPropertyListenerBlock?

    init() {
        installListeners()
    }

    deinit {
        removeListeners()
    }

    // MARK: - Public API

    /// Current output devices and the UID of the default output device.
    func currentState() -> (devices: [AudioDevice], currentDeviceId: String) {
        let devices = outputDevices()
        let currentUID = defaultOutputDeviceID().flatMap { uid(for: $0) } ?? ""
        return (devices, currentUID)
    }

    /// Switch the system default output device to the one with the given UID.
    /// Returns false if no matching device is found or the set call fails.
    @discardableResult
    func setDefaultOutput(uid targetUID: String) -> Bool {
        guard let deviceID = outputDeviceIDs().first(where: { uid(for: $0) == targetUID }) else {
            return false
        }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = deviceID
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &id
        )
        return status == noErr
    }

    // MARK: - Enumeration

    private func outputDevices() -> [AudioDevice] {
        outputDeviceIDs().compactMap { id in
            guard let deviceUID = uid(for: id), let name = name(for: id) else { return nil }
            return AudioDevice(id: deviceUID, name: name)
        }
    }

    /// All device IDs that have at least one output stream.
    private func outputDeviceIDs() -> [AudioDeviceID] {
        allDeviceIDs().filter { hasOutputStreams($0) }
    }

    private func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        ) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids
        ) == noErr else { return [] }
        return ids
    }

    private func hasOutputStreams(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &dataSize) == noErr else {
            return false
        }
        return dataSize > 0
    }

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    // MARK: - Per-device string properties

    private func uid(for id: AudioDeviceID) -> String? {
        stringProperty(kAudioDevicePropertyDeviceUID, for: id)
    }

    private func name(for id: AudioDeviceID) -> String? {
        stringProperty(kAudioObjectPropertyName, for: id)
    }

    private func stringProperty(_ selector: AudioObjectPropertySelector, for id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) { ptr -> OSStatus in
            AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, ptr)
        }
        guard status == noErr else { return nil }
        return value as String
    }

    // MARK: - Live update listeners

    private func installListeners() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async { self?.onChange?() }
        }
        listenerBlock = block

        for selector in [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice
        ] {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, block
            )
        }
    }

    private func removeListeners() {
        guard let block = listenerBlock else { return }
        for selector in [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice
        ] {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, block
            )
        }
    }
}
```

- [ ] **Step 2: Regenerate the Xcode project and build**

Run:
```bash
cd MikanRemoteServer && xcodegen generate && xcodebuild -scheme MikanRemoteServer -configuration Release build 2>&1 | tail -15
```
Expected: `** BUILD SUCCEEDED **`. (Sources are auto-discovered by xcodegen, so the new file is picked up.)

- [ ] **Step 3: Commit**

```bash
git add MikanRemoteServer/MikanRemoteServer/AudioDeviceController.swift MikanRemoteServer/MikanRemoteServer.xcodeproj
git commit -m "feat(server): add AudioDeviceController CoreAudio wrapper"
```

---

## Task 3: Wire `AudioDeviceController` into `MenuBarManager`

**Files:**
- Modify: `MikanRemoteServer/MikanRemoteServer/MenuBarManager.swift`

- [ ] **Step 1: Add the controller property**

In `MenuBarManager`, next to the other private controllers (`private let mouseController = MouseController()`), add:

```swift
    private let audioController = AudioDeviceController()
```

- [ ] **Step 2: Add the push helper**

After the existing `func pushSettings()` method, add:

```swift
    func pushAudioDevices() {
        let state = audioController.currentState()
        server.send(.audioDevices(devices: state.devices, currentDeviceId: state.currentDeviceId))
    }
```

- [ ] **Step 3: Wire the live-update callback in `init`**

In `init()`, after the `server.onConnectionChanged = { ... }` closure and before `try? server.start()`, add:

```swift
        audioController.onChange = { [weak self] in
            self?.pushAudioDevices()
        }
```

- [ ] **Step 4: Push the device list on connect**

In `handleHello(_:)`, inside the `if pairingStore.isDevicePaired(deviceId)` branch, after the existing `pushSettings()` line, add:

```swift
            pushAudioDevices()
```

In `handlePairResponse(_:)`, inside the `if pairingStore.validateCode(code)` branch, after the existing `pushSettings()` line, add:

```swift
            pushAudioDevices()
```

- [ ] **Step 5: Handle the `setAudioDevice` client message**

In `handleMessage(_:)`, add a new case (after the `.updateActions` case, before the closing brace of the switch):

```swift
        case .setAudioDevice(let deviceId):
            // On success, the CoreAudio default-output listener fires onChange →
            // pushAudioDevices(). On failure, re-push so the stale entry disappears.
            if !audioController.setDefaultOutput(uid: deviceId) {
                pushAudioDevices()
            }
```

- [ ] **Step 6: Build to verify**

Run:
```bash
cd MikanRemoteServer && xcodegen generate && xcodebuild -scheme MikanRemoteServer -configuration Release build 2>&1 | tail -15
```
Expected: `** BUILD SUCCEEDED **`. (The `switch message` in `handleMessage` is now exhaustive over all `ClientMessage` cases.)

- [ ] **Step 7: Commit**

```bash
git add MikanRemoteServer/MikanRemoteServer/MenuBarManager.swift
git commit -m "feat(server): push and switch audio output devices"
```

---

## Task 4: Add audio device state and UI to the iPhone client

**Files:**
- Modify: `MikanRemote/MikanRemote/ConnectionManager.swift`
- Modify: `MikanRemote/MikanRemote/UtilitiesView.swift`

- [ ] **Step 1: Add observable state to `ConnectionManager`**

After `private(set) var pairingFailed = false`, add:

```swift
    private(set) var audioDevices: [AudioDevice] = []
    private(set) var currentAudioDeviceId: String = ""
```

- [ ] **Step 2: Reset the state on disconnect**

In `disconnect()`, after the `pairingFailed = false` line, add:

```swift
        audioDevices = []
        currentAudioDeviceId = ""
```

In `handleDisconnect()`, after the `pairingFailed = false` line, add:

```swift
        audioDevices = []
        currentAudioDeviceId = ""
```

- [ ] **Step 3: Handle the server message**

In `handleServerMessage(_:)`, add a new case (after the `.pairRejected` case, before the closing brace):

```swift
        case .audioDevices(let devices, let currentDeviceId):
            audioDevices = devices
            currentAudioDeviceId = currentDeviceId
```

- [ ] **Step 4: Add the send helper**

After `func sendUpdateActions(_ actions: [Action])`, add:

```swift
    func sendSetAudioDevice(_ deviceId: String) {
        send(.setAudioDevice(deviceId: deviceId))
    }
```

- [ ] **Step 5: Add the "Audio Output" section to `UtilitiesView`**

In `UtilitiesView.body`, insert a new `Section` between the `Section("Tools")` block and the `Section("Open URL on Mac")` block:

```swift
                Section("Audio Output") {
                    if connectionManager.audioDevices.isEmpty {
                        Text("No devices")
                            .foregroundStyle(.secondary)
                            .disabled(true)
                    } else {
                        ForEach(connectionManager.audioDevices) { device in
                            Button {
                                selectAudioDevice(device)
                            } label: {
                                HStack {
                                    Text(device.name)
                                    Spacer()
                                    if device.id == connectionManager.currentAudioDeviceId {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .disabled(!connectionManager.isConnected)
                        }
                    }
                }
```

- [ ] **Step 6: Add the selection handler**

In `UtilitiesView`, after the `private func sendCommand(_ command: String)` method, add:

```swift
    private func selectAudioDevice(_ device: AudioDevice) {
        feedbackGenerator.impactOccurred()
        feedbackGenerator.prepare()
        connectionManager.sendSetAudioDevice(device.id)
    }
```

- [ ] **Step 7: Regenerate the iOS project and build for the device**

Run:
```bash
cd MikanRemote && xcodegen generate
```
Then build for a connected iPhone to confirm it compiles (the project's run scheme is Release/no-debugger — do not change it):
```bash
xcodebuild -project MikanRemote.xcodeproj -scheme MikanRemote -configuration Release -destination 'generic/platform=iOS' build 2>&1 | tail -15
```
Expected: `** BUILD SUCCEEDED **`. If no signing identity is configured for command-line builds, instead open `MikanRemote.xcodeproj` and build (Cmd+B) to verify compilation.

- [ ] **Step 8: Commit**

```bash
git add MikanRemote/MikanRemote/ConnectionManager.swift MikanRemote/MikanRemote/UtilitiesView.swift MikanRemote/MikanRemote.xcodeproj
git commit -m "feat(client): audio output device picker in Utilities sheet"
```

---

## Task 5: Manual end-to-end verification

**Files:** none (manual test on real hardware, per project constraints — simulator is impractical and CoreAudio needs a real Mac).

- [ ] **Step 1: Install the server build**

Run:
```bash
cd MikanRemoteServer && xcodebuild -scheme MikanRemoteServer -configuration Release build 2>&1 | tail -5
APP_PATH=$(xcodebuild -scheme MikanRemoteServer -configuration Release -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')
rm -rf /Applications/MikanRemoteServer.app && cp -R "$APP_PATH/MikanRemoteServer.app" /Applications/MikanRemoteServer.app
open /Applications/MikanRemoteServer.app
```
Expected: menu bar app running.

- [ ] **Step 2: Deploy the iPhone app**

From Xcode (`MikanRemote.xcodeproj`), build and run to the physical iPhone (Cmd+R). Connect/pair if prompted.

- [ ] **Step 3: Verify the device list**

Open the Utilities sheet (wrench icon). Confirm the "Audio Output" section lists the Mac's output devices, with a checkmark on the current default. Order: Tools, Audio Output, Open URL.

- [ ] **Step 4: Verify switching**

Tap a different device. Confirm: the Mac's audio output actually changes (play audio or check System Settings > Sound), and the checkmark moves to the tapped device within a moment.

- [ ] **Step 5: Verify live updates**

With the sheet open: plug in or unplug headphones / connect AirPods. Confirm the iPhone list updates without reopening the sheet. Then change the output device from the macOS menu-bar Sound control and confirm the iPhone checkmark follows.

- [ ] **Step 6: Verify disconnect behavior**

Kill the server (or disconnect). Confirm the Audio Output rows become disabled / show "No devices". Reconnect and confirm the list repopulates.

- [ ] **Step 7: Final protocol test run**

Run: `cd MikanProtocol && swift test 2>&1 | tail -5`
Expected: all tests pass.

---

## Task 6: Update documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/testing-guide.md`
- Modify: `README.md` (if it documents the Utilities sheet / feature list)

- [ ] **Step 1: Update `CLAUDE.md`**

In the "Key Conventions" list, add a bullet describing the audio output feature. Add it near the Utilities sheet bullet:

```markdown
- **Audio output device selection (iPhone):** The Utilities sheet has an "Audio Output" section (between Tools and Open URL) listing the Mac's output devices; tapping one switches the Mac default output. The server's `AudioDeviceController` (`MikanRemoteServer/MikanRemoteServer/AudioDeviceController.swift`) wraps the CoreAudio HAL: it enumerates devices with output streams, switches `kAudioHardwarePropertyDefaultOutputDevice`, and installs property listeners on `kAudioHardwarePropertyDevices` + `kAudioHardwarePropertyDefaultOutputDevice` for live updates. Devices are identified over the wire by their persistent **UID** (`kAudioDevicePropertyDeviceUID`), not the session-local `AudioDeviceID`. Protocol: `ServerMessage.audioDevices(devices:currentDeviceId:)` pushed on connect/change, `ClientMessage.setAudioDevice(deviceId:)` on tap. A failed switch silently re-pushes the current list (self-correcting); no error UI. Output only — no input/mic, no server menu bar UI.
```

- [ ] **Step 2: Update `docs/testing-guide.md`**

Add a test section for audio output device switching mirroring the Task 5 manual steps (list appears, switching works, live updates on plug/unplug and on macOS-side change, disabled when disconnected). Match the file's existing section format.

- [ ] **Step 3: Update `README.md` if applicable**

If `README.md` enumerates Utilities sheet features or the feature list, add audio output device selection there. (Skip if the README does not cover this level of detail.)

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/testing-guide.md README.md
git commit -m "docs: document audio output device selection"
```

---

## Done

The branch now has: protocol support for audio devices (tested), a CoreAudio controller on the server, server wiring that pushes the list and switches on request with live updates, the iPhone Utilities picker, manual verification, and updated docs.
