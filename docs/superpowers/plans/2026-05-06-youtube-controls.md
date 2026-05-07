# YouTube Controls Popup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a YouTube-specific keyboard-shortcut popup to the iPhone client, with a 3-state visibility setting (Auto / Always On / Always Off) where Auto reacts to the presence of a YouTube action button.

**Architecture:** Eight new `yt*` `performCommand` strings are added to the protocol (no schema change beyond accepted values). A new `youtubePopupMode: String` field is added to `updateSettings` and `settingsSync` with backward-compatible decoding. The server gets new `MouseController` methods + dispatch + UserDefaults persistence + a menu-bar submenu. The client gets a pure visibility function, a settings picker, a launcher button, and a modal popup `YouTubePopupView`.

**Tech Stack:** Swift 5.9+, SwiftUI, UIKit (multi-touch), Network.framework (WebSocket), CoreGraphics (CGEvent), MikanProtocol (shared Swift Package), xcodegen.

**Spec:** `docs/superpowers/specs/2026-05-06-youtube-controls-design.md`

**Branch:** `yt-buttons` (already checked out).

---

## File Map

**Modify:**
- `MikanProtocol/Sources/MikanProtocol/Messages.swift` — add `youtubePopupMode` to `updateSettings` (ClientMessage) and `settingsSync` (ServerMessage); backward-compat decode with `decodeIfPresent` defaulting to `"auto"`.
- `MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift` — round-trip tests for new field and the 8 `yt*` command strings.
- `MikanServer/MikanServer/MouseController.swift` — add 8 keystroke methods.
- `MikanServer/MikanServer/MenuBarManager.swift` — add `youtubePopupMode` state with persistence, route 8 new commands in `handleCommand`, broadcast in `pushSettings`, accept in `updateSettings` handler.
- `MikanServer/MikanServer/MikanServerApp.swift` — add "YouTube Popup" `Picker` to `MenuBarContentView`.
- `MikanRemote/MikanRemote/ConnectionManager.swift` — add `youtubePopupMode` state; update `sendUpdateSettings` signature; decode the new field in `settingsSync`.
- `MikanRemote/MikanRemote/SettingsView.swift` — add "YouTube Controls" section with picker; thread the new field through every `sendUpdateSettings` call.
- `MikanRemote/MikanRemote/ContentView.swift` — add launcher button to the top safe-area inset; present `YouTubePopupView` as a sheet.

**Create:**
- `MikanRemote/MikanRemote/YouTubePopupView.swift` — modal sheet view with 8 buttons.
- `MikanRemote/MikanRemote/YouTubeVisibility.swift` — pure function `effectiveYouTubeButtonVisible(mode:actions:) -> Bool` for unit testing.

---

## Task 1: Add `youtubePopupMode` field to MikanProtocol messages

**Files:**
- Modify: `MikanProtocol/Sources/MikanProtocol/Messages.swift`

- [ ] **Step 1: Modify `updateSettings` to include `youtubePopupMode`**

In `MikanProtocol/Sources/MikanProtocol/Messages.swift`, replace the `updateSettings` case in the `ClientMessage` enum. Old:

```swift
case updateSettings(sensitivity: Double, cursorSize: Double, cursorDotSize: Double, cursorGapSize: Double)
```

New:

```swift
case updateSettings(sensitivity: Double, cursorSize: Double, cursorDotSize: Double, cursorGapSize: Double, youtubePopupMode: String)
```

Add `youtubePopupMode` to `CodingKeys` (in the same enum). Old:

```swift
case type, deltaX, deltaY, url, command, deviceId, code, sensitivity, cursorSize, cursorDotSize, cursorGapSize, actions
```

New:

```swift
case type, deltaX, deltaY, url, command, deviceId, code, sensitivity, cursorSize, cursorDotSize, cursorGapSize, actions, youtubePopupMode
```

Update the decode branch for `"updateSettings"`. Old:

```swift
case "updateSettings":
    let sensitivity = try container.decode(Double.self, forKey: .sensitivity)
    let cursorSize = try container.decode(Double.self, forKey: .cursorSize)
    let cursorDotSize = try container.decode(Double.self, forKey: .cursorDotSize)
    let cursorGapSize = try container.decode(Double.self, forKey: .cursorGapSize)
    self = .updateSettings(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize)
```

New (uses `decodeIfPresent` with default `"auto"` so older clients without the field still parse):

```swift
case "updateSettings":
    let sensitivity = try container.decode(Double.self, forKey: .sensitivity)
    let cursorSize = try container.decode(Double.self, forKey: .cursorSize)
    let cursorDotSize = try container.decode(Double.self, forKey: .cursorDotSize)
    let cursorGapSize = try container.decode(Double.self, forKey: .cursorGapSize)
    let youtubePopupMode = try container.decodeIfPresent(String.self, forKey: .youtubePopupMode) ?? "auto"
    self = .updateSettings(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize, youtubePopupMode: youtubePopupMode)
```

Update the encode branch. Old:

```swift
case .updateSettings(let sensitivity, let cursorSize, let cursorDotSize, let cursorGapSize):
    try container.encode("updateSettings", forKey: .type)
    try container.encode(sensitivity, forKey: .sensitivity)
    try container.encode(cursorSize, forKey: .cursorSize)
    try container.encode(cursorDotSize, forKey: .cursorDotSize)
    try container.encode(cursorGapSize, forKey: .cursorGapSize)
```

New:

```swift
case .updateSettings(let sensitivity, let cursorSize, let cursorDotSize, let cursorGapSize, let youtubePopupMode):
    try container.encode("updateSettings", forKey: .type)
    try container.encode(sensitivity, forKey: .sensitivity)
    try container.encode(cursorSize, forKey: .cursorSize)
    try container.encode(cursorDotSize, forKey: .cursorDotSize)
    try container.encode(cursorGapSize, forKey: .cursorGapSize)
    try container.encode(youtubePopupMode, forKey: .youtubePopupMode)
```

- [ ] **Step 2: Make the same change to `settingsSync` in `ServerMessage`**

Replace the `settingsSync` case in the `ServerMessage` enum. Old:

```swift
case settingsSync(sensitivity: Double, cursorSize: Double, cursorDotSize: Double, cursorGapSize: Double)
```

New:

```swift
case settingsSync(sensitivity: Double, cursorSize: Double, cursorDotSize: Double, cursorGapSize: Double, youtubePopupMode: String)
```

Add `youtubePopupMode` to `ServerMessage.CodingKeys`. Old:

```swift
case type, actions, connected, hostname, reason, sensitivity, cursorSize, cursorDotSize, cursorGapSize
```

New:

```swift
case type, actions, connected, hostname, reason, sensitivity, cursorSize, cursorDotSize, cursorGapSize, youtubePopupMode
```

Update the decode branch. Old:

```swift
case "settingsSync":
    let sensitivity = try container.decode(Double.self, forKey: .sensitivity)
    let cursorSize = try container.decode(Double.self, forKey: .cursorSize)
    let cursorDotSize = try container.decode(Double.self, forKey: .cursorDotSize)
    let cursorGapSize = try container.decode(Double.self, forKey: .cursorGapSize)
    self = .settingsSync(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize)
```

New:

```swift
case "settingsSync":
    let sensitivity = try container.decode(Double.self, forKey: .sensitivity)
    let cursorSize = try container.decode(Double.self, forKey: .cursorSize)
    let cursorDotSize = try container.decode(Double.self, forKey: .cursorDotSize)
    let cursorGapSize = try container.decode(Double.self, forKey: .cursorGapSize)
    let youtubePopupMode = try container.decodeIfPresent(String.self, forKey: .youtubePopupMode) ?? "auto"
    self = .settingsSync(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize, youtubePopupMode: youtubePopupMode)
```

Update the encode branch. Old:

```swift
case .settingsSync(let sensitivity, let cursorSize, let cursorDotSize, let cursorGapSize):
    try container.encode("settingsSync", forKey: .type)
    try container.encode(sensitivity, forKey: .sensitivity)
    try container.encode(cursorSize, forKey: .cursorSize)
    try container.encode(cursorDotSize, forKey: .cursorDotSize)
    try container.encode(cursorGapSize, forKey: .cursorGapSize)
```

New:

```swift
case .settingsSync(let sensitivity, let cursorSize, let cursorDotSize, let cursorGapSize, let youtubePopupMode):
    try container.encode("settingsSync", forKey: .type)
    try container.encode(sensitivity, forKey: .sensitivity)
    try container.encode(cursorSize, forKey: .cursorSize)
    try container.encode(cursorDotSize, forKey: .cursorDotSize)
    try container.encode(cursorGapSize, forKey: .cursorGapSize)
    try container.encode(youtubePopupMode, forKey: .youtubePopupMode)
```

- [ ] **Step 3: Build to surface broken callers**

Run: `cd MikanProtocol && swift build`
Expected: PASS at the package level (no callers in the package). Server and client will fail to build until later tasks update them — that's expected.

- [ ] **Step 4: Commit**

```bash
git add MikanProtocol/Sources/MikanProtocol/Messages.swift
git commit -m "feat(protocol): add youtubePopupMode to settings sync messages"
```

---

## Task 2: Add MikanProtocol round-trip tests for new field and yt* commands

**Files:**
- Modify: `MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift`

- [ ] **Step 1: Write failing tests**

Append the following test methods to the `MessagesTests` class in `MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift`:

```swift
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
        "ytFullscreen"
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
```

- [ ] **Step 2: Run the tests**

Run: `cd MikanProtocol && swift test`
Expected: All tests PASS (the protocol changes from Task 1 already support these fields).

- [ ] **Step 3: Commit**

```bash
git add MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift
git commit -m "test(protocol): cover youtubePopupMode round-trip and yt* commands"
```

---

## Task 3: Add the 8 YouTube keystroke methods to MouseController

**Files:**
- Modify: `MikanServer/MikanServer/MouseController.swift`

- [ ] **Step 1: Add the 8 methods**

Append the following methods inside the `MouseController` class in `MikanServer/MikanServer/MouseController.swift`, after the existing `sendKeyPress` method:

```swift
// MARK: - YouTube web-player shortcuts

// Virtual key codes (HIToolbox / Carbon):
//   F=3, C=8, P=35, N=45, Comma=43, Period=47, Left=123, Right=124

func sendYouTubePrevVideo() {
    // Shift+P — previous video in playlist
    sendKeyPress(keyCode: 35, flags: [.maskShift])
}

func sendYouTubeNextVideo() {
    // Shift+N — next video in playlist
    sendKeyPress(keyCode: 45, flags: [.maskShift])
}

func sendYouTubePrevChapter() {
    // Option+Left — previous chapter
    sendKeyPress(keyCode: 123, flags: [.maskAlternate])
}

func sendYouTubeNextChapter() {
    // Option+Right — next chapter
    sendKeyPress(keyCode: 124, flags: [.maskAlternate])
}

func sendYouTubeToggleCaptions() {
    // c — toggle captions
    sendKeyPress(keyCode: 8, flags: [])
}

func sendYouTubeSlowDown() {
    // Shift+, produces "<" — slow down playback rate
    sendKeyPress(keyCode: 43, flags: [.maskShift])
}

func sendYouTubeSpeedUp() {
    // Shift+. produces ">" — speed up playback rate
    sendKeyPress(keyCode: 47, flags: [.maskShift])
}

func sendYouTubeFullscreen() {
    // f — toggle YouTube player fullscreen (separate from macOS Ctrl+Cmd+F)
    sendKeyPress(keyCode: 3, flags: [])
}
```

- [ ] **Step 2: Build the server target to confirm it compiles**

Run: `cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build -quiet`
Expected: Build error in `MenuBarManager.swift` for the existing `updateSettings` switch case (signature changed in Task 1) — that's expected and fixed in Task 4. `MouseController.swift` itself must compile cleanly. If `MouseController.swift` shows errors, fix before continuing.

- [ ] **Step 3: Commit**

```bash
git add MikanServer/MikanServer/MouseController.swift
git commit -m "feat(server): add YouTube web-player keystroke methods"
```

---

## Task 4: Wire YouTube commands and `youtubePopupMode` persistence in MenuBarManager

**Files:**
- Modify: `MikanServer/MikanServer/MenuBarManager.swift`

- [ ] **Step 1: Add `youtubePopupMode` state with persistence**

In `MikanServer/MikanServer/MenuBarManager.swift`, add a new stored property after `cursorGapSize`:

```swift
var youtubePopupMode: String {
    didSet {
        UserDefaults.standard.set(youtubePopupMode, forKey: "youtubePopupMode")
        pushSettings()
    }
}
```

In `init()`, after the existing settings restoration (after `self.cursorGapSize = ...`) and before the `cursorOverlay.updateSize(...)` line, add:

```swift
self.youtubePopupMode = UserDefaults.standard.string(forKey: "youtubePopupMode") ?? "auto"
```

(`didSet` does not fire during the property's first assignment inside its own class's init, so the order relative to other settings does not affect broadcasts.)

- [ ] **Step 2: Update `pushSettings` to include the new field**

Replace the existing `pushSettings` body:

```swift
func pushSettings() {
    guard !suppressSettingsSync else { return }
    server.send(.settingsSync(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize))
}
```

With:

```swift
func pushSettings() {
    guard !suppressSettingsSync else { return }
    server.send(.settingsSync(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize, youtubePopupMode: youtubePopupMode))
}
```

- [ ] **Step 3: Update the `updateSettings` handler to read the new field**

Replace the `case .updateSettings(...)` branch in `handleMessage`:

```swift
case .updateSettings(let newSensitivity, let newCursorSize, let newCursorDotSize, let newCursorGapSize):
    suppressSettingsSync = true
    sensitivity = newSensitivity
    cursorSize = newCursorSize
    cursorDotSize = newCursorDotSize
    cursorGapSize = newCursorGapSize
    suppressSettingsSync = false
```

With:

```swift
case .updateSettings(let newSensitivity, let newCursorSize, let newCursorDotSize, let newCursorGapSize, let newYouTubePopupMode):
    suppressSettingsSync = true
    sensitivity = newSensitivity
    cursorSize = newCursorSize
    cursorDotSize = newCursorDotSize
    cursorGapSize = newCursorGapSize
    youtubePopupMode = newYouTubePopupMode
    suppressSettingsSync = false
```

(No re-broadcast at the end — matches the existing pattern. The originating client already has the values, and the server only supports a single connection at a time. The menu bar UI updates automatically via the SwiftUI binding to `manager.youtubePopupMode`.)

- [ ] **Step 4: Add the 8 YouTube command cases to `handleCommand`**

Replace `default:` line in `handleCommand`:

```swift
        default:
            print("Unknown command: \(command)")
```

With:

```swift
        case "ytPrevVideo":
            mouseController.sendYouTubePrevVideo()
        case "ytNextVideo":
            mouseController.sendYouTubeNextVideo()
        case "ytPrevChapter":
            mouseController.sendYouTubePrevChapter()
        case "ytNextChapter":
            mouseController.sendYouTubeNextChapter()
        case "ytToggleCaptions":
            mouseController.sendYouTubeToggleCaptions()
        case "ytSlowDown":
            mouseController.sendYouTubeSlowDown()
        case "ytSpeedUp":
            mouseController.sendYouTubeSpeedUp()
        case "ytFullscreen":
            mouseController.sendYouTubeFullscreen()
        default:
            print("Unknown command: \(command)")
```

- [ ] **Step 5: Build to confirm compile**

Run: `cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build -quiet`
Expected: PASS. Any remaining build errors must be from `MikanServerApp.swift` (the menu bar UI in Task 5).

- [ ] **Step 6: Commit**

```bash
git add MikanServer/MikanServer/MenuBarManager.swift
git commit -m "feat(server): persist youtubePopupMode and dispatch yt* commands"
```

---

## Task 5: Add the YouTube Popup mode picker to the menu bar UI

**Files:**
- Modify: `MikanServer/MikanServer/MikanServerApp.swift`

- [ ] **Step 1: Add the picker row to `MenuBarContentView`**

In `MikanServer/MikanServer/MikanServerApp.swift`, find the `Divider()` line that comes after the `Gap Size` `HStack` and **before** the `Edit Actions...` button. Insert the following block after that `Divider()`:

```swift
            HStack {
                Text("YouTube Popup")
                Spacer()
                Picker("YouTube Popup", selection: $manager.youtubePopupMode) {
                    Text("Auto").tag("auto")
                    Text("On").tag("on")
                    Text("Off").tag("off")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 100)
            }

            Divider()
```

The view body should now have the YouTube Popup row + Divider sitting directly above the existing `Button("Edit Actions...")` block.

- [ ] **Step 2: Build the server**

Run: `cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build -quiet`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add MikanServer/MikanServer/MikanServerApp.swift
git commit -m "feat(server): add YouTube Popup mode picker to menu bar"
```

---

## Task 6: Install the new MikanServer build to /Applications

**Files:** (no source changes — install step)

- [ ] **Step 1: Build Release and copy to /Applications**

Run:
```bash
cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build
APP_PATH=$(xcodebuild -scheme MikanServer -configuration Release -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')
rm -rf /Applications/MikanRemoteServer.app
cp -R "$APP_PATH/MikanRemoteServer.app" /Applications/MikanRemoteServer.app
```

Expected: Build succeeds; `/Applications/MikanRemoteServer.app` is replaced.

- [ ] **Step 2: Quit and relaunch the running server (manual)**

Quit the menu-bar instance (use the menu's "Quit" or `osascript -e 'quit app "MikanRemoteServer"'`), then `open /Applications/MikanRemoteServer.app`. Confirm the menu bar item appears and the new "YouTube Popup" row shows in the menu with the three options.

- [ ] **Step 3: No commit needed for this task**

---

## Task 7: Update ConnectionManager (client) for `youtubePopupMode`

**Files:**
- Modify: `MikanRemote/MikanRemote/ConnectionManager.swift`

- [ ] **Step 1: Add `youtubePopupMode` state and reset paths**

In `MikanRemote/MikanRemote/ConnectionManager.swift`, add a new `private(set)` property after `cursorGapSize`:

```swift
private(set) var youtubePopupMode: String = "auto"
```

In `disconnect()`, after `cursorGapSize = 33.0`, add:

```swift
youtubePopupMode = "auto"
```

In `handleDisconnect()`, after `cursorGapSize = 33.0`, add:

```swift
youtubePopupMode = "auto"
```

- [ ] **Step 2: Update `sendUpdateSettings` signature**

Replace the existing `sendUpdateSettings`:

```swift
func sendUpdateSettings(sensitivity: Double, cursorSize: Double, cursorDotSize: Double, cursorGapSize: Double) {
    self.sensitivity = sensitivity
    self.cursorSize = cursorSize
    self.cursorDotSize = cursorDotSize
    self.cursorGapSize = cursorGapSize
    send(.updateSettings(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize))
}
```

With:

```swift
func sendUpdateSettings(sensitivity: Double, cursorSize: Double, cursorDotSize: Double, cursorGapSize: Double, youtubePopupMode: String) {
    self.sensitivity = sensitivity
    self.cursorSize = cursorSize
    self.cursorDotSize = cursorDotSize
    self.cursorGapSize = cursorGapSize
    self.youtubePopupMode = youtubePopupMode
    send(.updateSettings(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize, youtubePopupMode: youtubePopupMode))
}
```

- [ ] **Step 3: Decode the new field in `handleServerMessage`**

Replace the `settingsSync` branch:

```swift
case .settingsSync(let newSensitivity, let newCursorSize, let newDotSize, let newGapSize):
    sensitivity = newSensitivity
    cursorSize = newCursorSize
    cursorDotSize = newDotSize
    cursorGapSize = newGapSize
```

With:

```swift
case .settingsSync(let newSensitivity, let newCursorSize, let newDotSize, let newGapSize, let newYTMode):
    sensitivity = newSensitivity
    cursorSize = newCursorSize
    cursorDotSize = newDotSize
    cursorGapSize = newGapSize
    youtubePopupMode = newYTMode
```

- [ ] **Step 4: Build will fail until SettingsView is updated**

This is expected. Don't try to build yet — Task 8 fixes the existing `sendUpdateSettings` callers.

- [ ] **Step 5: Commit**

```bash
git add MikanRemote/MikanRemote/ConnectionManager.swift
git commit -m "feat(client): track youtubePopupMode in ConnectionManager"
```

---

## Task 8: Update SettingsView to thread `youtubePopupMode` through and add the picker section

**Files:**
- Modify: `MikanRemote/MikanRemote/SettingsView.swift`

- [ ] **Step 1: Add the `youtubePopupMode:` argument to every existing `sendUpdateSettings` call**

In `MikanRemote/MikanRemote/SettingsView.swift`, the file currently has 8 call sites for `sendUpdateSettings(sensitivity:cursorSize:cursorDotSize:cursorGapSize:)` — one for each ± button across the four numeric settings (sensitivity, cursor size, dot size, gap size). Each one must add a final `youtubePopupMode: connectionManager.youtubePopupMode` argument.

Update each call site so it ends like this (example — Sensitivity decrement; the same pattern applies to the other 7):

```swift
connectionManager.sendUpdateSettings(
    sensitivity: newVal,
    cursorSize: connectionManager.cursorSize,
    cursorDotSize: connectionManager.cursorDotSize,
    cursorGapSize: connectionManager.cursorGapSize,
    youtubePopupMode: connectionManager.youtubePopupMode
)
```

Do this for **all 8** call sites (sensitivity ±, cursor size ±, dot size ±, gap size ±). Verify count by running `grep -c 'sendUpdateSettings(' MikanRemote/MikanRemote/SettingsView.swift` — expected 8 before this change, then 9 after Step 2 adds the picker section.

- [ ] **Step 2: Add the YouTube Controls section**

Add a new section between the existing `Section("Cursor")` and `Section("Action Buttons")`:

```swift
Section("YouTube Controls") {
    Picker("Show button", selection: Binding(
        get: { connectionManager.youtubePopupMode },
        set: { newMode in
            connectionManager.sendUpdateSettings(
                sensitivity: connectionManager.sensitivity,
                cursorSize: connectionManager.cursorSize,
                cursorDotSize: connectionManager.cursorDotSize,
                cursorGapSize: connectionManager.cursorGapSize,
                youtubePopupMode: newMode
            )
        }
    )) {
        Text("Auto").tag("auto")
        Text("Always On").tag("on")
        Text("Always Off").tag("off")
    }
    .pickerStyle(.segmented)

    Text("Auto shows the button when a YouTube link is in your action buttons.")
        .font(.caption2)
        .foregroundStyle(.secondary)
}
```

- [ ] **Step 3: Open the project and verify it builds**

Run:
```bash
cd MikanRemote && xcodegen generate
```

Then in Xcode (or via xcodebuild for iOS Simulator just to check compile — actual deploy is on device per project rules):

```bash
xcodebuild -scheme MikanRemote -configuration Release -destination 'generic/platform=iOS' build -quiet
```

Expected: Compile error in `ContentView.swift` only if Task 9–11 haven't run yet — for this task, only `SettingsView.swift` and `ConnectionManager.swift` should be touched. Other compile errors should be unrelated. (If `xcodebuild` for `generic/platform=iOS` requires a signing identity that's unavailable, skip the build check here and rely on the integrated build at Task 12.)

- [ ] **Step 4: Commit**

```bash
git add MikanRemote/MikanRemote/SettingsView.swift
git commit -m "feat(client): add YouTube Controls picker and thread mode through settings"
```

---

## Task 9: Add the pure visibility function (testable)

**Files:**
- Create: `MikanRemote/MikanRemote/YouTubeVisibility.swift`

- [ ] **Step 1: Create the file**

Create `MikanRemote/MikanRemote/YouTubeVisibility.swift` with the following exact content:

```swift
import Foundation
import MikanProtocol

enum YouTubeVisibility {

    /// Returns true if the YouTube launcher button should be visible
    /// given the current 3-state mode and action button list.
    ///
    /// - mode "on": always visible
    /// - mode "off": always hidden
    /// - mode "auto" (or any unknown value): visible iff any action's URL
    ///   contains "youtube.com" or "youtu.be" (case-insensitive).
    static func effectiveYouTubeButtonVisible(mode: String, actions: [Action]) -> Bool {
        switch mode {
        case "on":
            return true
        case "off":
            return false
        default:
            return actions.contains { action in
                let url = action.url.lowercased()
                return url.contains("youtube.com") || url.contains("youtu.be")
            }
        }
    }
}
```

- [ ] **Step 2: Regenerate the project so xcodegen picks up the new file**

Run: `cd MikanRemote && xcodegen generate`

Expected: file added to the Xcode project. xcodegen auto-discovers sources.

- [ ] **Step 3: Commit**

```bash
git add MikanRemote/MikanRemote/YouTubeVisibility.swift MikanRemote/MikanRemote.xcodeproj
git commit -m "feat(client): pure function for YouTube launcher visibility"
```

> **Note:** the iOS app target does not currently have an XCTest bundle (no `MikanRemoteTests/` directory exists). The visibility function is verified manually during Task 13 device testing using the edge cases listed there. Adding an iOS test bundle solely for this one function is YAGNI — it would require a new target in `project.yml`, code signing, and device-or-simulator runs. If a test bundle is added later, the test cases listed in the spec ("Pure-function tests") translate directly.

---

## Task 10: Build the YouTubePopupView modal sheet

**Files:**
- Create: `MikanRemote/MikanRemote/YouTubePopupView.swift`

- [ ] **Step 1: Create the popup view**

Create `MikanRemote/MikanRemote/YouTubePopupView.swift` with:

```swift
import SwiftUI
import UIKit

struct YouTubePopupView: View {
    let onCommand: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    pairedButton(label: "Prev Video", icon: "backward.end.fill", command: "ytPrevVideo")
                    pairedButton(label: "Next Video", icon: "forward.end.fill", command: "ytNextVideo")
                }

                HStack(spacing: 12) {
                    pairedButton(label: "Prev Chapter", icon: "backward.frame.fill", command: "ytPrevChapter")
                    pairedButton(label: "Next Chapter", icon: "forward.frame.fill", command: "ytNextChapter")
                }

                fullWidthButton(label: "Captions", icon: "captions.bubble", command: "ytToggleCaptions")

                HStack(spacing: 12) {
                    pairedButton(label: "Slower <", icon: "tortoise.fill", command: "ytSlowDown")
                    pairedButton(label: "> Faster", icon: "hare.fill", command: "ytSpeedUp")
                }

                fullWidthButton(label: "Fullscreen", icon: "arrow.up.left.and.arrow.down.right", command: "ytFullscreen")

                Spacer()
            }
            .padding()
            .navigationTitle("YouTube Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func tap(_ command: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onCommand(command)
    }

    private func pairedButton(label: String, icon: String, command: String) -> some View {
        Button {
            tap(command)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    private func fullWidthButton(label: String, icon: String, command: String) -> some View {
        Button {
            tap(command)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }
}
```

- [ ] **Step 2: Regenerate the project**

Run: `cd MikanRemote && xcodegen generate`

- [ ] **Step 3: Commit**

```bash
git add MikanRemote/MikanRemote/YouTubePopupView.swift MikanRemote/MikanRemote.xcodeproj
git commit -m "feat(client): YouTubePopupView modal sheet with 8 command buttons"
```

---

## Task 11: Add the launcher button and sheet presentation in ContentView

**Files:**
- Modify: `MikanRemote/MikanRemote/ContentView.swift`

- [ ] **Step 1: Add a `@State` for the popup**

In `MikanRemote/MikanRemote/ContentView.swift`, after the existing `@State private var showSettings = false`, add:

```swift
@State private var showYouTubePopup = false
```

- [ ] **Step 2: Add the launcher button to the top safe-area inset**

Replace the existing top safe-area `HStack` body. Old (in `.safeAreaInset(edge: .top)`):

```swift
HStack {
    Circle()
        .fill(.green)
        .frame(width: 8, height: 8)
    Text(connectionManager.hostname ?? "Connected")
        .font(.caption)
        .foregroundStyle(.secondary)
    Spacer()
    Button {
        showSettings = true
    } label: {
        Image(systemName: "gearshape")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

New (adds the YouTube launcher between Spacer and the gear, gated on visibility):

```swift
HStack {
    Circle()
        .fill(.green)
        .frame(width: 8, height: 8)
    Text(connectionManager.hostname ?? "Connected")
        .font(.caption)
        .foregroundStyle(.secondary)
    Spacer()
    if YouTubeVisibility.effectiveYouTubeButtonVisible(
        mode: connectionManager.youtubePopupMode,
        actions: connectionManager.actions
    ) {
        Button {
            showYouTubePopup = true
        } label: {
            Image(systemName: "play.rectangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
        .padding(.trailing, 8)
    }
    Button {
        showSettings = true
    } label: {
        Image(systemName: "gearshape")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

- [ ] **Step 3: Present the popup as a sheet**

Find the existing `.sheet(isPresented: $showSettings) { ... }` modifier on the outer `VStack`. Add a second sheet modifier directly after it:

```swift
.sheet(isPresented: $showYouTubePopup) {
    YouTubePopupView(
        onCommand: { connectionManager.send(.performCommand(command: $0)) }
    )
}
```

- [ ] **Step 4: Build to verify**

Run: `cd MikanRemote && xcodegen generate`

Open `MikanRemote.xcodeproj` in Xcode (or trust the next on-device build to surface any error).

- [ ] **Step 5: Commit**

```bash
git add MikanRemote/MikanRemote/ContentView.swift
git commit -m "feat(client): add YouTube launcher button and popup sheet"
```

---

## Task 12: Build and deploy MikanRemote to the physical iPhone

**Files:** (no source changes — deploy step)

Per project rules: **physical iPhone only, Release configuration, no debugger** (the existing scheme is already configured this way; do not change it).

- [ ] **Step 1: Regenerate the project**

Run: `cd MikanRemote && xcodegen generate`

- [ ] **Step 2: Open in Xcode**

Run: `open MikanRemote/MikanRemote.xcodeproj`

- [ ] **Step 3: Build and run to device (manual)**

In Xcode: select the connected iPhone in the device picker, then `Cmd+R`. Confirm the app installs and launches on the device.

If the build fails in Xcode, fix the error (most likely a missed call site for `sendUpdateSettings`) and re-run from Step 1 of this task.

- [ ] **Step 4: No commit needed for this task**

---

## Task 13: On-device verification

**Files:** (no source changes — verification step)

This is the gate before any merge. Per project memory, all of these must pass on a real iPhone with a real macOS server before claiming completion.

- [ ] **Step 1: Default state — launcher visible**

Verify with stock action buttons (default config includes a YouTube action):
- iPhone connects to the Mac.
- The red YouTube `play.rectangle.fill` icon is visible in the top bar (between the hostname and the gear).
- Tapping it presents a modal sheet titled "YouTube Controls" with all 8 buttons in the order: Prev Video / Next Video / Prev Chapter / Next Chapter / Captions (full-width) / Slower / Faster / Fullscreen (full-width).

- [ ] **Step 2: Sheet stays open across multiple taps**

With YouTube playing in Safari/Chrome on the Mac, open the popup and tap `> Faster` 3 times. Confirm:
- Each tap fires a haptic.
- The sheet does not auto-dismiss.
- YouTube's playback rate visibly increases each time.

- [ ] **Step 3: Each command works**

With YouTube open on the Mac, tap each button once and confirm the expected behavior:
- Prev/Next Video (only meaningful inside a playlist — pull up any YouTube playlist for this).
- Prev/Next Chapter (use a video that has chapters; e.g. a long talk).
- Captions toggles CC.
- Slower / Faster shifts playback rate.
- Fullscreen toggles YouTube's player fullscreen (not native macOS fullscreen).

- [ ] **Step 4: Auto mode reacts to actions**

In iPhone Settings sheet, confirm "YouTube Controls" picker is set to **Auto**. Then in the Action Buttons section:
- Delete the YouTube action and tap Done.
- Reopen the main screen — confirm the launcher button is **gone**.
- Reopen Settings, add an action with URL `https://youtube.com`, tap Done.
- Confirm the launcher button **reappears**.
- Repeat with `https://youtu.be/dQw4w9WgXcQ` and `https://m.youtube.com` to spot-check the host matching.

- [ ] **Step 5: Always On / Always Off override actions**

- Set picker to **Always Off** with the YouTube action present — launcher is hidden.
- Set picker to **Always On** with no YouTube action — launcher is visible.
- Set picker back to **Auto** — launcher matches the action list.

- [ ] **Step 6: Server menu bar parity**

- On the Mac, click the menu bar icon. Confirm a "YouTube Popup" row with an Auto/On/Off menu picker.
- Change the picker on the Mac. Open the iPhone Settings sheet — the iPhone picker reflects the new value.
- Change the picker on the iPhone. The Mac menu bar reflects the new value next time it's opened.

- [ ] **Step 7: Persistence**

- Set the mode to **Always Off** on the Mac.
- Quit MikanRemoteServer (`Quit` in the menu).
- Relaunch from `/Applications/MikanRemoteServer.app`.
- Confirm the menu bar still shows **Always Off**.
- Confirm the iPhone, on reconnecting, shows **Always Off** in its picker.

- [ ] **Step 8: Backward compatibility (optional spot check)**

The protocol uses `decodeIfPresent` so the old client could connect to the new server (and vice versa) without crashing. No regression test is required on device; the unit tests added in Task 2 cover this.

- [ ] **Step 9: Trackpad still works while popup is up**

Open the popup, then tap somewhere on the dimmed background — the sheet should dismiss (default sheet behavior). The trackpad below should not have moved the cursor while the sheet was up. (This is incidental but worth a sanity check.)

---

## Final Step: Plan complete

When all 13 tasks are checked off and on-device verification passes:

1. The branch `yt-buttons` contains the full feature.
2. Memory entries should be updated to record that YouTube Controls shipped — the agent executing the plan can do this via the user's auto-memory system once the user has confirmed they're happy with the result.
3. Decide with the user whether to merge to `main` or open a PR.
