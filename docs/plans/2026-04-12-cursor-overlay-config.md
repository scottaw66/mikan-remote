# Cursor Overlay Configurability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add configurable center dot size and transparent gap size to the cursor overlay, alongside the existing overall size setting.

**Architecture:** Two new `Double` parameters (`cursorDotSize`, `cursorGapSize`) flow through the same bidirectional settings pipeline as the existing `sensitivity` and `cursorSize`. Protocol messages gain two fields, server persists to UserDefaults, overlay controller receives the values and passes them to the drawing view. Both server menu bar and iPhone settings get a "Cursor" section grouping all three cursor controls.

**Tech Stack:** Swift, SwiftUI, MikanProtocol (Swift Package), CGContext drawing, UserDefaults

---

### Task 1: Update Protocol Messages

**Files:**
- Modify: `MikanProtocol/Sources/MikanProtocol/Messages.swift:11` (updateSettings case)
- Modify: `MikanProtocol/Sources/MikanProtocol/Messages.swift:14-16` (CodingKeys)
- Modify: `MikanProtocol/Sources/MikanProtocol/Messages.swift:44-47` (updateSettings decoder)
- Modify: `MikanProtocol/Sources/MikanProtocol/Messages.swift:84-87` (updateSettings encoder)
- Modify: `MikanProtocol/Sources/MikanProtocol/Messages.swift:101` (settingsSync case)
- Modify: `MikanProtocol/Sources/MikanProtocol/Messages.swift:103-104` (CodingKeys)
- Modify: `MikanProtocol/Sources/MikanProtocol/Messages.swift:125-128` (settingsSync decoder)
- Modify: `MikanProtocol/Sources/MikanProtocol/Messages.swift:154-157` (settingsSync encoder)
- Modify: `MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift:138-158` (update existing tests)

- [ ] **Step 1: Update the tests first**

In `MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift`, update the two existing test functions to include the new parameters:

Replace `testUpdateSettingsRoundTrip` (lines 138-147):

```swift
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
```

Replace `testSettingsSyncRoundTrip` (lines 149-158):

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd MikanProtocol && swift test 2>&1 | tail -20`
Expected: Compilation errors — `updateSettings` and `settingsSync` don't accept the new parameters yet.

- [ ] **Step 3: Add new CodingKeys and update ClientMessage**

In `MikanProtocol/Sources/MikanProtocol/Messages.swift`:

Update the `ClientMessage` enum case (line 11):
```swift
case updateSettings(sensitivity: Double, cursorSize: Double, cursorDotSize: Double, cursorGapSize: Double)
```

Update `CodingKeys` (line 15) to add the new keys:
```swift
enum CodingKeys: String, CodingKey {
    case type, deltaX, deltaY, url, command, deviceId, code, sensitivity, cursorSize, cursorDotSize, cursorGapSize, actions
}
```

Update the `updateSettings` decoder block (lines 44-47):
```swift
case "updateSettings":
    let sensitivity = try container.decode(Double.self, forKey: .sensitivity)
    let cursorSize = try container.decode(Double.self, forKey: .cursorSize)
    let cursorDotSize = try container.decode(Double.self, forKey: .cursorDotSize)
    let cursorGapSize = try container.decode(Double.self, forKey: .cursorGapSize)
    self = .updateSettings(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize)
```

Update the `updateSettings` encoder block (lines 84-87):
```swift
case .updateSettings(let sensitivity, let cursorSize, let cursorDotSize, let cursorGapSize):
    try container.encode("updateSettings", forKey: .type)
    try container.encode(sensitivity, forKey: .sensitivity)
    try container.encode(cursorSize, forKey: .cursorSize)
    try container.encode(cursorDotSize, forKey: .cursorDotSize)
    try container.encode(cursorGapSize, forKey: .cursorGapSize)
```

- [ ] **Step 4: Update ServerMessage**

In the same file, update `ServerMessage`:

Update the `settingsSync` case (line 101):
```swift
case settingsSync(sensitivity: Double, cursorSize: Double, cursorDotSize: Double, cursorGapSize: Double)
```

Update `ServerMessage.CodingKeys` (lines 103-104):
```swift
enum CodingKeys: String, CodingKey {
    case type, actions, connected, hostname, reason, sensitivity, cursorSize, cursorDotSize, cursorGapSize
}
```

Update the `settingsSync` decoder block (lines 125-128):
```swift
case "settingsSync":
    let sensitivity = try container.decode(Double.self, forKey: .sensitivity)
    let cursorSize = try container.decode(Double.self, forKey: .cursorSize)
    let cursorDotSize = try container.decode(Double.self, forKey: .cursorDotSize)
    let cursorGapSize = try container.decode(Double.self, forKey: .cursorGapSize)
    self = .settingsSync(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize)
```

Update the `settingsSync` encoder block (lines 154-157):
```swift
case .settingsSync(let sensitivity, let cursorSize, let cursorDotSize, let cursorGapSize):
    try container.encode("settingsSync", forKey: .type)
    try container.encode(sensitivity, forKey: .sensitivity)
    try container.encode(cursorSize, forKey: .cursorSize)
    try container.encode(cursorDotSize, forKey: .cursorDotSize)
    try container.encode(cursorGapSize, forKey: .cursorGapSize)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd MikanProtocol && swift test 2>&1 | tail -20`
Expected: All tests pass, including the updated `testUpdateSettingsRoundTrip` and `testSettingsSyncRoundTrip`.

- [ ] **Step 6: Commit**

```bash
git add MikanProtocol/Sources/MikanProtocol/Messages.swift MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift
git commit -m "feat: add cursorDotSize and cursorGapSize to protocol messages"
```

---

### Task 2: Update CursorOverlayController

**Files:**
- Modify: `MikanServer/MikanServer/CursorOverlayController.swift:3-16` (add properties, updateStyle method)
- Modify: `MikanServer/MikanServer/CursorOverlayController.swift:52-71` (pass params to CursorView)
- Modify: `MikanServer/MikanServer/CursorOverlayController.swift:81-95` (update draw() to use params)

- [ ] **Step 1: Add dot/gap properties and updateStyle method to CursorOverlayController**

In `MikanServer/MikanServer/CursorOverlayController.swift`, add two new properties alongside `cursorSize` (line 8):

```swift
private var cursorSize: CGFloat = 140
private var dotSizePercent: CGFloat = 5
private var gapSizePercent: CGFloat = 33
```

Add a new method after `updateSize` (after line 16):

```swift
func updateStyle(dotSize: CGFloat, gapSize: CGFloat) {
    dotSizePercent = dotSize
    gapSizePercent = gapSize
    window?.orderOut(nil)
    window = nil
    cursorView = nil
}
```

- [ ] **Step 2: Pass dot/gap to CursorView**

Update `CursorView` to accept the parameters. Replace the class definition (lines 81-95) with:

```swift
private final class CursorView: NSView {
    var dotSizePercent: CGFloat = 5
    var gapSizePercent: CGFloat = 33

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let outerRadius = min(bounds.width, bounds.height) / 2 - 2
        let gapRadius = outerRadius * (gapSizePercent * 2 / 100)
        let dotRadius = outerRadius * (dotSizePercent / 100)

        let red = NSColor(red: 0.9, green: 0.25, blue: 0.15, alpha: 1.0).cgColor
        ctx.setFillColor(red)

        // Outer ring
        ctx.addArc(center: center, radius: outerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.addArc(center: center, radius: gapRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.fillPath(using: .evenOdd)

        // Center dot
        ctx.addArc(center: center, radius: dotRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.fillPath()
    }
}
```

- [ ] **Step 3: Wire up setupWindow to pass values to CursorView**

In `setupWindow()`, after creating the view (line 66), set the parameters:

```swift
let view = CursorView(frame: NSRect(x: 0, y: 0, width: cursorSize, height: cursorSize))
view.dotSizePercent = dotSizePercent
view.gapSizePercent = gapSizePercent
panel.contentView = view
```

- [ ] **Step 4: Build to verify compilation**

Run: `cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (will have warnings about unused parameters in MenuBarManager until Task 3)

- [ ] **Step 5: Commit**

```bash
git add MikanServer/MikanServer/CursorOverlayController.swift
git commit -m "feat: cursor overlay accepts dot size and gap size percentages"
```

---

### Task 3: Update MenuBarManager (Server State)

**Files:**
- Modify: `MikanServer/MikanServer/MenuBarManager.swift:10-22` (add properties)
- Modify: `MikanServer/MikanServer/MenuBarManager.swift:28-33` (init)
- Modify: `MikanServer/MikanServer/MenuBarManager.swift:60-63` (pushSettings)
- Modify: `MikanServer/MikanServer/MenuBarManager.swift:86-90` (handleMessage updateSettings)

- [ ] **Step 1: Add cursorDotSize and cursorGapSize properties**

In `MikanServer/MikanServer/MenuBarManager.swift`, add two new properties after `cursorSize` (after line 22):

```swift
var cursorDotSize: Double {
    didSet {
        UserDefaults.standard.set(cursorDotSize, forKey: "cursorDotSize")
        cursorOverlay.updateStyle(dotSize: CGFloat(cursorDotSize), gapSize: CGFloat(cursorGapSize))
        pushSettings()
    }
}
var cursorGapSize: Double {
    didSet {
        UserDefaults.standard.set(cursorGapSize, forKey: "cursorGapSize")
        cursorOverlay.updateStyle(dotSize: CGFloat(cursorDotSize), gapSize: CGFloat(cursorGapSize))
        pushSettings()
    }
}
```

- [ ] **Step 2: Update init to load from UserDefaults**

In `init()` (lines 28-33), add after the `cursorSize` initialization:

```swift
let storedDotSize = UserDefaults.standard.double(forKey: "cursorDotSize")
self.cursorDotSize = storedDotSize > 0 ? storedDotSize : 5.0
let storedGapSize = UserDefaults.standard.double(forKey: "cursorGapSize")
self.cursorGapSize = storedGapSize > 0 ? storedGapSize : 33.0
```

And after the existing `cursorOverlay.updateSize(CGFloat(self.cursorSize))` call (line 33), add:

```swift
cursorOverlay.updateStyle(dotSize: CGFloat(self.cursorDotSize), gapSize: CGFloat(self.cursorGapSize))
```

- [ ] **Step 3: Update pushSettings**

Update `pushSettings()` (line 62) to include the new parameters:

```swift
server.send(.settingsSync(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize))
```

- [ ] **Step 4: Update handleMessage for updateSettings**

Update the `.updateSettings` case in `handleMessage` (lines 86-90):

```swift
case .updateSettings(let newSensitivity, let newCursorSize, let newDotSize, let newGapSize):
    suppressSettingsSync = true
    sensitivity = newSensitivity
    cursorSize = newCursorSize
    cursorDotSize = newDotSize
    cursorGapSize = newGapSize
    suppressSettingsSync = false
```

- [ ] **Step 5: Build to verify compilation**

Run: `cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add MikanServer/MikanServer/MenuBarManager.swift
git commit -m "feat: server persists and syncs cursor dot/gap size settings"
```

---

### Task 4: Update Server Menu Bar UI

**Files:**
- Modify: `MikanServer/MikanServer/MikanServerApp.swift:38-85` (restructure cursor controls into section)

- [ ] **Step 1: Replace the Cursor Size control with a Cursor section**

In `MikanServer/MikanServer/MikanServerApp.swift`, replace the `HStack` for "Cursor Size" (lines 63-85, from the start of the Cursor Size HStack through its closing brace) with a "Cursor" group containing all three controls. Also move the Divider that was after Sensitivity to after the new Cursor section. The result should replace lines 62-87 (from the Divider before Cursor Size through the Divider after it):

Replace the block from the existing Cursor Size HStack (lines 63-85) with:

```swift
Text("Cursor")
    .font(.caption)
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, alignment: .leading)

HStack {
    Text("Size")
    Spacer()
    Button {
        manager.cursorSize = max(60, manager.cursorSize - 20)
    } label: {
        Image(systemName: "minus.circle")
    }
    .buttonStyle(.borderless)
    .disabled(manager.cursorSize <= 60)

    Text("\(Int(manager.cursorSize))pt")
        .monospacedDigit()
        .frame(width: 46)

    Button {
        manager.cursorSize = min(300, manager.cursorSize + 20)
    } label: {
        Image(systemName: "plus.circle")
    }
    .buttonStyle(.borderless)
    .disabled(manager.cursorSize >= 300)
}

HStack {
    Text("Dot Size")
    Spacer()
    Button {
        manager.cursorDotSize = max(1, manager.cursorDotSize - 1)
    } label: {
        Image(systemName: "minus.circle")
    }
    .buttonStyle(.borderless)
    .disabled(manager.cursorDotSize <= 1)

    Text("\(Int(manager.cursorDotSize))%")
        .monospacedDigit()
        .frame(width: 36)

    Button {
        manager.cursorDotSize = min(15, manager.cursorDotSize + 1)
    } label: {
        Image(systemName: "plus.circle")
    }
    .buttonStyle(.borderless)
    .disabled(manager.cursorDotSize >= 15)
}

HStack {
    Text("Gap Size")
    Spacer()
    Button {
        manager.cursorGapSize = max(10, manager.cursorGapSize - 1)
    } label: {
        Image(systemName: "minus.circle")
    }
    .buttonStyle(.borderless)
    .disabled(manager.cursorGapSize <= 10)

    Text("\(Int(manager.cursorGapSize))%")
        .monospacedDigit()
        .frame(width: 36)

    Button {
        manager.cursorGapSize = min(45, manager.cursorGapSize + 1)
    } label: {
        Image(systemName: "plus.circle")
    }
    .buttonStyle(.borderless)
    .disabled(manager.cursorGapSize >= 45)
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Install to /Applications**

```bash
APP_PATH=$(xcodebuild -scheme MikanServer -configuration Release -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')
rm -rf /Applications/MikanServer.app && cp -R "$APP_PATH/MikanServer.app" /Applications/MikanServer.app
```

- [ ] **Step 4: Commit**

```bash
git add MikanServer/MikanServer/MikanServerApp.swift
git commit -m "feat: server menu bar groups cursor controls with dot/gap size"
```

---

### Task 5: Update iPhone Client (ConnectionManager + SettingsView)

**Files:**
- Modify: `MikanRemote/MikanRemote/ConnectionManager.swift:17-18` (add properties)
- Modify: `MikanRemote/MikanRemote/ConnectionManager.swift:97-98` (disconnect reset)
- Modify: `MikanRemote/MikanRemote/ConnectionManager.swift:116-120` (sendUpdateSettings)
- Modify: `MikanRemote/MikanRemote/ConnectionManager.swift:159-160` (handleDisconnect reset)
- Modify: `MikanRemote/MikanRemote/ConnectionManager.swift:192-194` (handleServerMessage settingsSync)
- Modify: `MikanRemote/MikanRemote/SettingsView.swift:13-77` (restructure cursor controls)

- [ ] **Step 1: Add properties to ConnectionManager**

In `MikanRemote/MikanRemote/ConnectionManager.swift`, add after the `cursorSize` property (line 18):

```swift
private(set) var cursorDotSize: Double = 5.0
private(set) var cursorGapSize: Double = 33.0
```

- [ ] **Step 2: Update disconnect() reset**

In `disconnect()` (lines 89-101), add after `cursorSize = 140.0` (line 98):

```swift
cursorDotSize = 5.0
cursorGapSize = 33.0
```

- [ ] **Step 3: Update handleDisconnect() reset**

In `handleDisconnect()` (lines 154-165), add after `cursorSize = 140.0` (line 160):

```swift
cursorDotSize = 5.0
cursorGapSize = 33.0
```

- [ ] **Step 4: Update sendUpdateSettings**

Replace `sendUpdateSettings` (lines 116-120) with:

```swift
func sendUpdateSettings(sensitivity: Double, cursorSize: Double, cursorDotSize: Double, cursorGapSize: Double) {
    self.sensitivity = sensitivity
    self.cursorSize = cursorSize
    self.cursorDotSize = cursorDotSize
    self.cursorGapSize = cursorGapSize
    send(.updateSettings(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize))
}
```

- [ ] **Step 5: Update handleServerMessage for settingsSync**

Replace the `.settingsSync` case (lines 192-194) with:

```swift
case .settingsSync(let newSensitivity, let newCursorSize, let newDotSize, let newGapSize):
    sensitivity = newSensitivity
    cursorSize = newCursorSize
    cursorDotSize = newDotSize
    cursorGapSize = newGapSize
```

- [ ] **Step 6: Restructure SettingsView with Cursor section**

In `MikanRemote/MikanRemote/SettingsView.swift`, replace the entire `Section("Mouse")` block (lines 13-77) with two sections — "Mouse" for sensitivity only, and "Cursor" for the three cursor controls:

```swift
Section("Mouse") {
    HStack {
        Text("Sensitivity")
        Spacer()
        Button {
            let newVal = max(3.0, connectionManager.sensitivity - 0.5)
            connectionManager.sendUpdateSettings(
                sensitivity: newVal,
                cursorSize: connectionManager.cursorSize,
                cursorDotSize: connectionManager.cursorDotSize,
                cursorGapSize: connectionManager.cursorGapSize
            )
        } label: {
            Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
        .disabled(connectionManager.sensitivity <= 3.0)

        Text(String(format: "%.1fx", connectionManager.sensitivity))
            .monospacedDigit()
            .frame(width: 46)

        Button {
            let newVal = min(20.0, connectionManager.sensitivity + 0.5)
            connectionManager.sendUpdateSettings(
                sensitivity: newVal,
                cursorSize: connectionManager.cursorSize,
                cursorDotSize: connectionManager.cursorDotSize,
                cursorGapSize: connectionManager.cursorGapSize
            )
        } label: {
            Image(systemName: "plus.circle")
        }
        .buttonStyle(.borderless)
        .disabled(connectionManager.sensitivity >= 20.0)
    }
}

Section("Cursor") {
    HStack {
        Text("Size")
        Spacer()
        Button {
            let newVal = max(60.0, connectionManager.cursorSize - 20)
            connectionManager.sendUpdateSettings(
                sensitivity: connectionManager.sensitivity,
                cursorSize: newVal,
                cursorDotSize: connectionManager.cursorDotSize,
                cursorGapSize: connectionManager.cursorGapSize
            )
        } label: {
            Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
        .disabled(connectionManager.cursorSize <= 60)

        Text("\(Int(connectionManager.cursorSize))pt")
            .monospacedDigit()
            .frame(width: 50)

        Button {
            let newVal = min(300.0, connectionManager.cursorSize + 20)
            connectionManager.sendUpdateSettings(
                sensitivity: connectionManager.sensitivity,
                cursorSize: newVal,
                cursorDotSize: connectionManager.cursorDotSize,
                cursorGapSize: connectionManager.cursorGapSize
            )
        } label: {
            Image(systemName: "plus.circle")
        }
        .buttonStyle(.borderless)
        .disabled(connectionManager.cursorSize >= 300)
    }

    HStack {
        Text("Dot Size")
        Spacer()
        Button {
            let newVal = max(1.0, connectionManager.cursorDotSize - 1)
            connectionManager.sendUpdateSettings(
                sensitivity: connectionManager.sensitivity,
                cursorSize: connectionManager.cursorSize,
                cursorDotSize: newVal,
                cursorGapSize: connectionManager.cursorGapSize
            )
        } label: {
            Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
        .disabled(connectionManager.cursorDotSize <= 1)

        Text("\(Int(connectionManager.cursorDotSize))%")
            .monospacedDigit()
            .frame(width: 40)

        Button {
            let newVal = min(15.0, connectionManager.cursorDotSize + 1)
            connectionManager.sendUpdateSettings(
                sensitivity: connectionManager.sensitivity,
                cursorSize: connectionManager.cursorSize,
                cursorDotSize: newVal,
                cursorGapSize: connectionManager.cursorGapSize
            )
        } label: {
            Image(systemName: "plus.circle")
        }
        .buttonStyle(.borderless)
        .disabled(connectionManager.cursorDotSize >= 15)
    }

    HStack {
        Text("Gap Size")
        Spacer()
        Button {
            let newVal = max(10.0, connectionManager.cursorGapSize - 1)
            connectionManager.sendUpdateSettings(
                sensitivity: connectionManager.sensitivity,
                cursorSize: connectionManager.cursorSize,
                cursorDotSize: connectionManager.cursorDotSize,
                cursorGapSize: newVal
            )
        } label: {
            Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
        .disabled(connectionManager.cursorGapSize <= 10)

        Text("\(Int(connectionManager.cursorGapSize))%")
            .monospacedDigit()
            .frame(width: 40)

        Button {
            let newVal = min(45.0, connectionManager.cursorGapSize + 1)
            connectionManager.sendUpdateSettings(
                sensitivity: connectionManager.sensitivity,
                cursorSize: connectionManager.cursorSize,
                cursorDotSize: connectionManager.cursorDotSize,
                cursorGapSize: newVal
            )
        } label: {
            Image(systemName: "plus.circle")
        }
        .buttonStyle(.borderless)
        .disabled(connectionManager.cursorGapSize >= 45)
    }
}
```

- [ ] **Step 7: Build iOS app to verify compilation**

Run: `cd MikanRemote && xcodegen generate && xcodebuild -scheme MikanRemote -configuration Release -destination 'generic/platform=iOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add MikanRemote/MikanRemote/ConnectionManager.swift MikanRemote/MikanRemote/SettingsView.swift
git commit -m "feat: iPhone client supports cursor dot/gap size settings"
```

---

### Task 6: Run Protocol Tests

**Files:** None (verification only)

- [ ] **Step 1: Run MikanProtocol tests**

Run: `cd MikanProtocol && swift test 2>&1 | tail -20`
Expected: All tests pass.

- [ ] **Step 2: Build both apps**

Run server build:
```bash
cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build 2>&1 | tail -5
```

Run client build:
```bash
cd MikanRemote && xcodegen generate && xcodebuild -scheme MikanRemote -configuration Release -destination 'generic/platform=iOS' build 2>&1 | tail -5
```

Expected: Both BUILD SUCCEEDED.

- [ ] **Step 3: Install server to /Applications**

```bash
APP_PATH=$(cd MikanServer && xcodebuild -scheme MikanServer -configuration Release -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')
rm -rf /Applications/MikanServer.app && cp -R "$APP_PATH/MikanServer.app" /Applications/MikanServer.app
```
