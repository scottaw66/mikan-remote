# Client Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the iPhone client control cursor size, mouse sensitivity, and action buttons — with two-way sync to the server menu bar.

**Architecture:** Two new protocol messages (`updateSettings`, `settingsSync`) handle scalar settings; `updateActions` reuses the existing `actionConfig` flow in reverse. The server remains the single source of truth. A new SettingsView on the iPhone is presented as a sheet behind a gear icon.

**Tech Stack:** Swift, SwiftUI, MikanProtocol (shared Codable messages), Network.framework WebSocket.

---

## File Structure

### Modified files

```
MikanProtocol/Sources/MikanProtocol/Messages.swift    # Add updateSettings, updateActions, settingsSync
MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift  # Tests for new message types
MikanServer/MikanServer/MenuBarManager.swift           # Handle new messages, push settingsSync on change
MikanRemote/MikanRemote/ConnectionManager.swift        # New properties + handlers for settings
MikanRemote/MikanRemote/ContentView.swift              # Gear icon + sheet presentation
```

### New files

```
MikanRemote/MikanRemote/SettingsView.swift             # Sensitivity, cursor size, action editor
```

---

## Task 1: Protocol — Add `updateSettings` and `settingsSync` messages

**Files:**
- Modify: `MikanProtocol/Sources/MikanProtocol/Messages.swift`
- Modify: `MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift`

- [ ] **Step 1: Write failing tests for `updateSettings` round-trip**

Add to `MessagesTests.swift` after the `testPairRejectedRoundTrip` test:

```swift
func testUpdateSettingsRoundTrip() throws {
    let msg = ClientMessage.updateSettings(sensitivity: 15.0, cursorSize: 200.0)
    let data = try JSONEncoder().encode(msg)
    let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
    guard case .updateSettings(let sensitivity, let cursorSize) = decoded else {
        XCTFail("Expected updateSettings"); return
    }
    XCTAssertEqual(sensitivity, 15.0)
    XCTAssertEqual(cursorSize, 200.0)
}
```

- [ ] **Step 2: Write failing test for `settingsSync` round-trip**

Add to `MessagesTests.swift` after the new test:

```swift
func testSettingsSyncRoundTrip() throws {
    let msg = ServerMessage.settingsSync(sensitivity: 8.5, cursorSize: 120.0)
    let data = try JSONEncoder().encode(msg)
    let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
    guard case .settingsSync(let sensitivity, let cursorSize) = decoded else {
        XCTFail("Expected settingsSync"); return
    }
    XCTAssertEqual(sensitivity, 8.5)
    XCTAssertEqual(cursorSize, 120.0)
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd MikanProtocol && swift test 2>&1 | tail -20`
Expected: Compilation errors — `updateSettings` and `settingsSync` don't exist yet.

- [ ] **Step 4: Add `updateSettings` case to `ClientMessage`**

In `Messages.swift`, add the case to the enum (after `pairResponse`):

```swift
case updateSettings(sensitivity: Double, cursorSize: Double)
```

Add `sensitivity` and `cursorSize` to `CodingKeys` (line 13):

```swift
enum CodingKeys: String, CodingKey {
    case type, deltaX, deltaY, url, command, deviceId, code, sensitivity, cursorSize
}
```

Add decoding in `init(from:)` (before the `default` case):

```swift
case "updateSettings":
    let sensitivity = try container.decode(Double.self, forKey: .sensitivity)
    let cursorSize = try container.decode(Double.self, forKey: .cursorSize)
    self = .updateSettings(sensitivity: sensitivity, cursorSize: cursorSize)
```

Add encoding in `encode(to:)` (at the end of the switch):

```swift
case .updateSettings(let sensitivity, let cursorSize):
    try container.encode("updateSettings", forKey: .type)
    try container.encode(sensitivity, forKey: .sensitivity)
    try container.encode(cursorSize, forKey: .cursorSize)
```

- [ ] **Step 5: Add `settingsSync` case to `ServerMessage`**

Add the case (after `pairRejected`):

```swift
case settingsSync(sensitivity: Double, cursorSize: Double)
```

Add `sensitivity` and `cursorSize` to the ServerMessage `CodingKeys` (line 87):

```swift
enum CodingKeys: String, CodingKey {
    case type, actions, connected, hostname, reason, sensitivity, cursorSize
}
```

Add decoding in `init(from:)` (before the `default` case):

```swift
case "settingsSync":
    let sensitivity = try container.decode(Double.self, forKey: .sensitivity)
    let cursorSize = try container.decode(Double.self, forKey: .cursorSize)
    self = .settingsSync(sensitivity: sensitivity, cursorSize: cursorSize)
```

Add encoding in `encode(to:)` (at the end of the switch):

```swift
case .settingsSync(let sensitivity, let cursorSize):
    try container.encode("settingsSync", forKey: .type)
    try container.encode(sensitivity, forKey: .sensitivity)
    try container.encode(cursorSize, forKey: .cursorSize)
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd MikanProtocol && swift test 2>&1 | tail -20`
Expected: All tests pass including the two new ones.

- [ ] **Step 7: Commit**

```bash
git add MikanProtocol/Sources/MikanProtocol/Messages.swift MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift
git commit -m "feat(protocol): add updateSettings, settingsSync messages"
```

---

## Task 2: Protocol — Add `updateActions` client message

**Files:**
- Modify: `MikanProtocol/Sources/MikanProtocol/Messages.swift`
- Modify: `MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift`

- [ ] **Step 1: Write failing test for `updateActions` round-trip**

Add to `MessagesTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd MikanProtocol && swift test 2>&1 | tail -20`
Expected: Compilation error — `updateActions` doesn't exist.

- [ ] **Step 3: Add `updateActions` case to `ClientMessage`**

Add the case (after `updateSettings`):

```swift
case updateActions(actions: [Action])
```

Add `actions` to the ClientMessage `CodingKeys` (line 13, which now has sensitivity and cursorSize):

```swift
enum CodingKeys: String, CodingKey {
    case type, deltaX, deltaY, url, command, deviceId, code, sensitivity, cursorSize, actions
}
```

Add decoding in `init(from:)` (before the `default` case):

```swift
case "updateActions":
    let actions = try container.decode([Action].self, forKey: .actions)
    self = .updateActions(actions: actions)
```

Add encoding in `encode(to:)`:

```swift
case .updateActions(let actions):
    try container.encode("updateActions", forKey: .type)
    try container.encode(actions, forKey: .actions)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd MikanProtocol && swift test 2>&1 | tail -20`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add MikanProtocol/Sources/MikanProtocol/Messages.swift MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift
git commit -m "feat(protocol): add updateActions client message"
```

---

## Task 3: Server — Handle `updateSettings` and `updateActions`

**Files:**
- Modify: `MikanServer/MikanServer/MenuBarManager.swift`

- [ ] **Step 1: Add `updateSettings` handler to `handleMessage`**

In `MenuBarManager.swift`, add two new cases to the `switch message` in `handleMessage` (after the `.pairResponse` case, line 75):

```swift
case .updateSettings(let newSensitivity, let newCursorSize):
    sensitivity = newSensitivity
    cursorSize = newCursorSize
case .updateActions(let newActions):
    actionStore.actions = newActions
    try? actionStore.save()
    server.send(.actionConfig(actions: actionStore.actions))
```

Note: Setting `sensitivity` and `cursorSize` triggers their existing `didSet` handlers which persist to UserDefaults and update the CursorOverlayController. The `@Observable` annotation ensures the menu bar UI updates.

For `updateActions`, we push `actionConfig` back so the client's action button bar updates immediately (the settings sheet edits a local copy; the confirmed list comes back via `actionConfig`).

- [ ] **Step 2: Build the server to verify compilation**

Run: `cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add MikanServer/MikanServer/MenuBarManager.swift
git commit -m "feat(server): handle updateSettings and updateActions from client"
```

---

## Task 4: Server — Push `settingsSync` on connect and on local change

**Files:**
- Modify: `MikanServer/MikanServer/MenuBarManager.swift`

- [ ] **Step 1: Add a `pushSettings` helper method**

Add after the existing `pushActions()` method (line 53):

```swift
func pushSettings() {
    server.send(.settingsSync(sensitivity: sensitivity, cursorSize: cursorSize))
}
```

- [ ] **Step 2: Push `settingsSync` on connect**

In `handleHello` (line 84), add `pushSettings()` after the existing `server.send(.actionConfig(...))`:

```swift
server.send(.actionConfig(actions: actionStore.actions))
pushSettings()
```

In `handlePairResponse` (line 100), add the same after `actionConfig`:

```swift
server.send(.actionConfig(actions: actionStore.actions))
pushSettings()
```

- [ ] **Step 3: Push `settingsSync` when settings change via menu bar**

Update the `sensitivity` `didSet` to also push to client:

```swift
var sensitivity: Double {
    didSet {
        UserDefaults.standard.set(sensitivity, forKey: "sensitivity")
        pushSettings()
    }
}
```

Update the `cursorSize` `didSet` to also push to client:

```swift
var cursorSize: Double {
    didSet {
        UserDefaults.standard.set(cursorSize, forKey: "cursorSize")
        cursorOverlay.updateSize(CGFloat(cursorSize))
        pushSettings()
    }
}
```

Note: When the client sends `updateSettings`, the server sets these properties which triggers `didSet` → `pushSettings()`. This creates a harmless echo (client overwrites with same values). To suppress the echo, add a private flag:

Add a property to `MenuBarManager`:

```swift
private var suppressSettingsSync = false
```

Update the `updateSettings` handler to use it:

```swift
case .updateSettings(let newSensitivity, let newCursorSize):
    suppressSettingsSync = true
    sensitivity = newSensitivity
    cursorSize = newCursorSize
    suppressSettingsSync = false
```

And guard in `pushSettings`:

```swift
func pushSettings() {
    guard !suppressSettingsSync else { return }
    server.send(.settingsSync(sensitivity: sensitivity, cursorSize: cursorSize))
}

- [ ] **Step 4: Build the server to verify compilation**

Run: `cd MikanServer && xcodebuild -scheme MikanServer -configuration Release build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add MikanServer/MikanServer/MenuBarManager.swift
git commit -m "feat(server): push settingsSync on connect and menu bar changes"
```

---

## Task 5: iOS Client — Handle `settingsSync` in ConnectionManager

**Files:**
- Modify: `MikanRemote/MikanRemote/ConnectionManager.swift`

- [ ] **Step 1: Add published properties for settings**

Add after the existing `actions` property (line 16):

```swift
private(set) var sensitivity: Double = 10.0
private(set) var cursorSize: Double = 140.0
```

- [ ] **Step 2: Handle `settingsSync` in `handleServerMessage`**

Add a new case in `handleServerMessage` (after `.actionConfig`, line 175):

```swift
case .settingsSync(let newSensitivity, let newCursorSize):
    sensitivity = newSensitivity
    cursorSize = newCursorSize
```

- [ ] **Step 3: Reset settings on disconnect**

In `disconnect()` (line 94), add resets after `actions = []`:

```swift
actions = []
sensitivity = 10.0
cursorSize = 140.0
```

In `handleDisconnect()` (line 145), add the same after `actions = []`:

```swift
actions = []
sensitivity = 10.0
cursorSize = 140.0
```

- [ ] **Step 4: Add `sendUpdateSettings` method**

Add after the existing `send` method (line 110):

```swift
func sendUpdateSettings(sensitivity: Double, cursorSize: Double) {
    self.sensitivity = sensitivity
    self.cursorSize = cursorSize
    send(.updateSettings(sensitivity: sensitivity, cursorSize: cursorSize))
}
```

- [ ] **Step 5: Add `sendUpdateActions` method**

Add after `sendUpdateSettings`:

```swift
func sendUpdateActions(_ actions: [Action]) {
    send(.updateActions(actions: actions))
}
```

- [ ] **Step 6: Build to verify compilation**

Run: `cd MikanRemote && xcodegen generate && xcodebuild -scheme MikanRemote -configuration Release -destination 'generic/platform=iOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add MikanRemote/MikanRemote/ConnectionManager.swift
git commit -m "feat(client): handle settingsSync and add settings send methods"
```

---

## Task 6: iOS Client — Create SettingsView

**Files:**
- Create: `MikanRemote/MikanRemote/SettingsView.swift`

- [ ] **Step 1: Create SettingsView with sensitivity and cursor size controls**

Create `MikanRemote/MikanRemote/SettingsView.swift`:

```swift
// MikanRemote/MikanRemote/SettingsView.swift
import SwiftUI
import MikanProtocol

struct SettingsView: View {
    @Bindable var connectionManager: ConnectionManager
    @Environment(\.dismiss) private var dismiss
    @State private var editingActions: [Action] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Mouse") {
                    HStack {
                        Text("Sensitivity")
                        Spacer()
                        Button {
                            let newVal = max(3.0, connectionManager.sensitivity - 0.5)
                            connectionManager.sendUpdateSettings(
                                sensitivity: newVal,
                                cursorSize: connectionManager.cursorSize
                            )
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .disabled(connectionManager.sensitivity <= 3.0)

                        Text(String(format: "%.1fx", connectionManager.sensitivity))
                            .monospacedDigit()
                            .frame(width: 46)

                        Button {
                            let newVal = min(20.0, connectionManager.sensitivity + 0.5)
                            connectionManager.sendUpdateSettings(
                                sensitivity: newVal,
                                cursorSize: connectionManager.cursorSize
                            )
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .disabled(connectionManager.sensitivity >= 20.0)
                    }

                    HStack {
                        Text("Cursor Size")
                        Spacer()
                        Button {
                            let newVal = max(60.0, connectionManager.cursorSize - 20)
                            connectionManager.sendUpdateSettings(
                                sensitivity: connectionManager.sensitivity,
                                cursorSize: newVal
                            )
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .disabled(connectionManager.cursorSize <= 60)

                        Text("\(Int(connectionManager.cursorSize))pt")
                            .monospacedDigit()
                            .frame(width: 50)

                        Button {
                            let newVal = min(300.0, connectionManager.cursorSize + 20)
                            connectionManager.sendUpdateSettings(
                                sensitivity: connectionManager.sensitivity,
                                cursorSize: newVal
                            )
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .disabled(connectionManager.cursorSize >= 300)
                    }
                }

                Section("Action Buttons") {
                    ForEach($editingActions, id: \.id) { $action in
                        ActionEditorRow(action: $action)
                    }
                    .onDelete { indices in
                        editingActions.remove(atOffsets: indices)
                    }
                    .onMove { source, destination in
                        editingActions.move(fromOffsets: source, toOffset: destination)
                    }

                    Button {
                        editingActions.append(
                            Action(id: UUID().uuidString, label: "New Shortcut", url: "https://example.com")
                        )
                    } label: {
                        Label("Add Action", systemImage: "plus.circle")
                    }
                }

                Section {
                    Button("Reset Actions to Defaults") {
                        editingActions = Action.defaults
                        connectionManager.sendUpdateActions(editingActions)
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .onAppear {
                editingActions = connectionManager.actions
            }
            .onChange(of: editingActions) {
                connectionManager.sendUpdateActions(editingActions)
            }
        }
    }
}

private struct ActionEditorRow: View {
    @Binding var action: Action

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Label", text: Binding(
                get: { action.label },
                set: { action = Action(id: action.id, label: $0, url: action.url, icon: action.icon) }
            ))
            .font(.body.bold())

            TextField("URL", text: Binding(
                get: { action.url },
                set: { action = Action(id: action.id, label: action.label, url: $0, icon: action.icon) }
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)

            TextField("SF Symbol (optional)", text: Binding(
                get: { action.icon ?? "" },
                set: { action = Action(id: action.id, label: action.label, url: action.url, icon: $0.isEmpty ? nil : $0) }
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `cd MikanRemote && xcodegen generate && xcodebuild -scheme MikanRemote -configuration Release -destination 'generic/platform=iOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add MikanRemote/MikanRemote/SettingsView.swift
git commit -m "feat(client): add SettingsView with sensitivity, cursor size, and action editor"
```

---

## Task 7: iOS Client — Add gear icon to ContentView

**Files:**
- Modify: `MikanRemote/MikanRemote/ContentView.swift`

- [ ] **Step 1: Add state and gear icon**

Add a `@State` property to `ContentView` (after the `connectionManager` property, line 7):

```swift
@State private var showSettings = false
```

Replace the status bar `HStack` (lines 63–71) with a version that includes the gear icon:

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
.padding(.horizontal)
.padding(.top, 8)
.padding(.bottom, 2)
```

Add the `.sheet` modifier to the outermost `VStack` (after the closing brace of `VStack`, before the end of `body`):

```swift
.sheet(isPresented: $showSettings) {
    SettingsView(connectionManager: connectionManager)
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `cd MikanRemote && xcodebuild -scheme MikanRemote -configuration Release -destination 'generic/platform=iOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add MikanRemote/MikanRemote/ContentView.swift
git commit -m "feat(client): add gear icon to open settings sheet"
```

---

## Task 8: Build and install server for testing

**Files:** None (build/install only)

- [ ] **Step 1: Build and install MikanServer**

```bash
cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build 2>&1 | tail -5
APP_PATH=$(xcodebuild -scheme MikanServer -configuration Release -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')
rm -rf /Applications/MikanServer.app && cp -R "$APP_PATH/MikanServer.app" /Applications/MikanServer.app
```

- [ ] **Step 2: Build MikanRemote for device**

```bash
cd MikanRemote && xcodegen generate && open MikanRemote.xcodeproj
```

Then build and run to device from Xcode (Cmd+R) in Release configuration.

- [ ] **Step 3: Test checklist**

Verify on device:
1. Connect iPhone to server — settings sync: sensitivity and cursor size show correct current server values
2. Gear icon visible in status bar, tap opens settings sheet
3. Adjust sensitivity on iPhone — mouse speed changes on Mac immediately
4. Adjust cursor size on iPhone — cursor overlay resizes on Mac immediately
5. Change sensitivity via Mac menu bar — iPhone settings sheet updates (if open)
6. Edit action label/URL on iPhone — action button bar updates, URL opens correctly
7. Add new action on iPhone — appears in button bar
8. Delete action on iPhone — removed from button bar
9. Reorder actions on iPhone — button bar order changes
10. Reset to defaults on iPhone — button bar resets
11. Disconnect and reconnect — settings resync correctly
12. Trackpad, tapping, scrolling, command buttons all still work normally
