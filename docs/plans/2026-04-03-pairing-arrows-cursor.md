# Pairing Code, Arrow Keys & Cursor Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add security pairing (one-time code entry per device), left/right arrow key buttons for YouTube seeking, and redesign cursor overlay to solid red with hollow center dot.

**Architecture:** Pairing uses a hello/challenge/response handshake — client sends a persistent device UUID on connect, server checks if it's known. Unknown devices trigger a 4-digit code displayed on the Mac that the user types into the phone. Paired device IDs persist to disk on the server. Arrow keys are two new `performCommand` values. Cursor overlay is a cosmetic change to `CursorView.draw()`.

**Tech Stack:** Swift, Network.framework, SwiftUI, CGEvent, MikanProtocol SPM package

---

### Task 1: Add Pairing Messages to MikanProtocol

**Files:**
- Modify: `MikanProtocol/Sources/MikanProtocol/Messages.swift`
- Modify: `MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift`

- [x] **Step 1: Add `hello` and `pairResponse` cases to `ClientMessage`**

In `Messages.swift`, add to the `ClientMessage` enum:

```swift
case hello(deviceId: String)
case pairResponse(code: String)
```

Add `deviceId` and `code` to `CodingKeys`:

```swift
enum CodingKeys: String, CodingKey {
    case type, deltaX, deltaY, button, url, command, deviceId, code
}
```

Add decoding in `init(from:)`:

```swift
case "hello":
    let deviceId = try container.decode(String.self, forKey: .deviceId)
    self = .hello(deviceId: deviceId)
case "pairResponse":
    let code = try container.decode(String.self, forKey: .code)
    self = .pairResponse(code: code)
```

Add encoding in `encode(to:)`:

```swift
case .hello(let deviceId):
    try container.encode("hello", forKey: .type)
    try container.encode(deviceId, forKey: .deviceId)
case .pairResponse(let code):
    try container.encode("pairResponse", forKey: .type)
    try container.encode(code, forKey: .code)
```

- [x] **Step 2: Add `pairRequired`, `pairAccepted`, `pairRejected` cases to `ServerMessage`**

In `Messages.swift`, add to the `ServerMessage` enum:

```swift
case pairRequired
case pairAccepted
case pairRejected(reason: String)
```

Add `reason` to `CodingKeys`:

```swift
enum CodingKeys: String, CodingKey {
    case type, actions, connected, hostname, reason
}
```

Add decoding in `init(from:)`:

```swift
case "pairRequired":
    self = .pairRequired
case "pairAccepted":
    self = .pairAccepted
case "pairRejected":
    let reason = try container.decode(String.self, forKey: .reason)
    self = .pairRejected(reason: reason)
```

Add encoding in `encode(to:)`:

```swift
case .pairRequired:
    try container.encode("pairRequired", forKey: .type)
case .pairAccepted:
    try container.encode("pairAccepted", forKey: .type)
case .pairRejected(let reason):
    try container.encode("pairRejected", forKey: .type)
    try container.encode(reason, forKey: .reason)
```

- [x] **Step 3: Write tests for new message types**

Add to `MessagesTests.swift`:

```swift
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
```

- [x] **Step 4: Run protocol tests**

Run: `cd MikanProtocol && swift test`
Expected: All tests pass, including the 5 new ones.

- [x] **Step 5: Commit**

```bash
git add MikanProtocol/Sources/MikanProtocol/Messages.swift MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift
git commit -m "feat: add pairing handshake messages to protocol"
```

---

### Task 2: Add PairingStore to MikanServer

**Files:**
- Create: `MikanServer/MikanServer/PairingStore.swift`

This manages the set of paired device IDs and generates pairing codes.

- [x] **Step 1: Create PairingStore**

Create `MikanServer/MikanServer/PairingStore.swift`:

```swift
import Foundation

@Observable
final class PairingStore {
    private(set) var pairedDeviceIds: Set<String> = []
    private(set) var pendingCode: String?
    private(set) var pendingDeviceId: String?

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MikanServer")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("paired-devices.json")
        load()
    }

    func isDevicePaired(_ deviceId: String) -> Bool {
        pairedDeviceIds.contains(deviceId)
    }

    func generateCode(for deviceId: String) -> String {
        let code = String(format: "%04d", Int.random(in: 0...9999))
        pendingCode = code
        pendingDeviceId = deviceId
        return code
    }

    func validateCode(_ code: String) -> Bool {
        guard let pending = pendingCode, let deviceId = pendingDeviceId else { return false }
        if code == pending {
            pairedDeviceIds.insert(deviceId)
            pendingCode = nil
            pendingDeviceId = nil
            save()
            return true
        }
        return false
    }

    func clearPending() {
        pendingCode = nil
        pendingDeviceId = nil
    }

    func unpairAll() {
        pairedDeviceIds.removeAll()
        pendingCode = nil
        pendingDeviceId = nil
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let ids = try? JSONDecoder().decode(Set<String>.self, from: data) else { return }
        pairedDeviceIds = ids
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(pairedDeviceIds) else { return }
        try? data.write(to: fileURL)
    }
}
```

- [x] **Step 2: Commit**

```bash
git add MikanServer/MikanServer/PairingStore.swift
git commit -m "feat: add PairingStore for tracking paired devices"
```

---

### Task 3: Add Pairing Code Window to MikanServer

**Files:**
- Create: `MikanServer/MikanServer/PairingCodeWindow.swift`
- Modify: `MikanServer/MikanServer/MikanServerApp.swift`

A floating window that displays the 4-digit pairing code so the user can read it and type it into the phone.

- [x] **Step 1: Create PairingCodeWindow view**

Create `MikanServer/MikanServer/PairingCodeWindow.swift`:

```swift
import SwiftUI

struct PairingCodeView: View {
    let code: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            Text("Pairing Code")
                .font(.headline)

            Text(code)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .kerning(8)

            Text("Enter this code on your iPhone to pair.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(width: 300)
    }
}
```

- [x] **Step 2: Add pairing code window to MikanServerApp**

In `MikanServerApp.swift`, add a new `Window` scene after the action-editor window:

```swift
Window("Pairing Code", id: "pairing-code") {
    if let code = manager.pairingStore.pendingCode {
        PairingCodeView(code: code)
    } else {
        Text("No pairing in progress.")
            .padding()
    }
}
.defaultSize(width: 300, height: 260)
.windowResizability(.contentSize)
```

- [x] **Step 3: Commit**

```bash
git add MikanServer/MikanServer/PairingCodeWindow.swift MikanServer/MikanServer/MikanServerApp.swift
git commit -m "feat: add pairing code display window"
```

---

### Task 4: Wire Pairing Logic into Server Connection Flow

**Files:**
- Modify: `MikanServer/MikanServer/MenuBarManager.swift`
- Modify: `MikanServer/MikanServer/WebSocketServer.swift`
- Modify: `MikanServer/MikanServer/MikanServerApp.swift`

The server now waits for a `hello` message before sending config. If the device is unknown, it triggers pairing.

- [x] **Step 1: Add PairingStore and pairing state to MenuBarManager**

In `MenuBarManager.swift`, add property:

```swift
let pairingStore = PairingStore()
```

Replace the `onConnectionChanged` handler in `init()` — remove the immediate send of serverStatus/actionConfig. The server now waits for a `hello` first:

```swift
server.onConnectionChanged = { [weak self] connected, _ in
    guard let self else { return }
    if !connected {
        pairingStore.clearPending()
    }
}
```

- [x] **Step 2: Handle hello and pairResponse in MenuBarManager**

Add to `handleMessage()` switch in `MenuBarManager.swift`:

```swift
case .hello(let deviceId):
    handleHello(deviceId)
case .pairResponse(let code):
    handlePairResponse(code)
```

Add these methods to `MenuBarManager`:

```swift
var onShowPairingWindow: (() -> Void)?

private func handleHello(_ deviceId: String) {
    if pairingStore.isDevicePaired(deviceId) {
        // Known device — send config immediately
        let hostname = ProcessInfo.processInfo.hostName
        server.send(.serverStatus(connected: true, hostname: hostname))
        server.send(.actionConfig(actions: actionStore.actions))
    } else {
        // Unknown device — require pairing
        let code = pairingStore.generateCode(for: deviceId)
        print("Pairing code: \(code)")
        server.send(.pairRequired)
        onShowPairingWindow?()
    }
}

private func handlePairResponse(_ code: String) {
    if pairingStore.validateCode(code) {
        server.send(.pairAccepted)
        let hostname = ProcessInfo.processInfo.hostName
        server.send(.serverStatus(connected: true, hostname: hostname))
        server.send(.actionConfig(actions: actionStore.actions))
    } else {
        server.send(.pairRejected(reason: "Invalid code"))
    }
}
```

- [x] **Step 3: Wire up pairing window opening in MikanServerApp**

In `MikanServerApp.swift`, add `@Environment(\.openWindow) private var openWindow` to the app struct (note: for MenuBarExtra apps, we'll use a different approach — set the callback on the manager).

Since `MikanServerApp` is a struct, we need to set the callback after manager is initialized. Add an `.onAppear` or use a helper. The cleanest approach: add to the `MenuBarExtra` content view's `.onAppear`:

In `MenuBarContentView`, add:

```swift
.onAppear {
    manager.onShowPairingWindow = {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "pairing-code")
    }
}
```

Wait — `openWindow` needs to be at the `App` level, not inside the menu bar view. Instead, use `NSApp` and `NSWindow` directly in the callback, or pass `openWindow` through. The simplest: set the callback from the `MenuBarExtra` body using an `.onAppear`:

Actually, the simplest approach for a menu bar app: have `MenuBarManager` open the window directly using `NSApp`:

In `MenuBarManager.handleHello()`, replace `onShowPairingWindow?()` — we'll wire this up at the App level instead. Keep `onShowPairingWindow` as a callback.

In `MikanServerApp.swift`, in the `MenuBarExtra` closure, add a task:

```swift
MenuBarExtra {
    MenuBarContentView(manager: manager)
        .frame(width: 220)
} label: {
    // ...existing...
}
.menuBarExtraStyle(.window)
.onChange(of: manager.pairingStore.pendingCode) { _, newCode in
    if newCode != nil {
        NSApp.activate(ignoringOtherApps: true)
        // openWindow requires @Environment, use from ContentView
    }
}
```

The cleanest solution: use `openWindow` from the `MenuBarContentView` since it has `@Environment(\.openWindow)` already. Set the callback there:

In `MenuBarContentView`, add to the existing `.onAppear` or body:

Add after the VStack's `.padding()`:

```swift
.onAppear {
    manager.onShowPairingWindow = { [openWindow] in
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "pairing-code")
    }
}
```

- [x] **Step 4: Add "Unpair All Devices" button to menu bar**

In `MenuBarContentView` body, add before the "Quit" button:

```swift
if !manager.pairingStore.pairedDeviceIds.isEmpty {
    Button("Unpair All Devices") {
        manager.pairingStore.unpairAll()
    }
}
```

- [x] **Step 5: Build MikanServer to verify compilation**

```bash
cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [x] **Step 6: Commit**

```bash
git add MikanServer/MikanServer/MenuBarManager.swift MikanServer/MikanServer/WebSocketServer.swift MikanServer/MikanServer/MikanServerApp.swift
git commit -m "feat: wire pairing flow into server connection lifecycle"
```

---

### Task 5: Add Pairing Flow to iOS Client

**Files:**
- Modify: `MikanRemote/MikanRemote/ConnectionManager.swift`
- Modify: `MikanRemote/MikanRemote/ContentView.swift`

Client sends `hello` on connect, handles pairing challenge, shows code entry UI.

- [x] **Step 1: Add device ID and pairing state to ConnectionManager**

In `ConnectionManager.swift`, add properties:

```swift
private(set) var pairingRequired = false
private(set) var pairingFailed = false

private var deviceId: String {
    if let id = UserDefaults.standard.string(forKey: "mikan.deviceId") {
        return id
    }
    let id = UUID().uuidString
    UserDefaults.standard.set(id, forKey: "mikan.deviceId")
    return id
}
```

- [x] **Step 2: Send hello on WebSocket ready**

In the `stateUpdateHandler` closure inside `connect(to:)`, in the `.ready` case, add a `hello` send after starting heartbeat:

```swift
case .ready:
    self?.isConnected = true
    self?.startHeartbeat()
    self?.receiveMessage()
    self?.send(.hello(deviceId: self?.deviceId ?? ""))
```

- [x] **Step 3: Handle pairing server messages**

In `handleServerMessage()`, add cases:

```swift
case .pairRequired:
    pairingRequired = true
    pairingFailed = false
case .pairAccepted:
    pairingRequired = false
    pairingFailed = false
case .pairRejected:
    pairingFailed = true
```

- [x] **Step 4: Add submitPairingCode method**

Add to `ConnectionManager`:

```swift
func submitPairingCode(_ code: String) {
    pairingFailed = false
    send(.pairResponse(code: code))
}
```

- [x] **Step 5: Reset pairing state on disconnect**

In `handleDisconnect()` and `disconnect()`, add:

```swift
pairingRequired = false
pairingFailed = false
```

- [x] **Step 6: Add pairing UI to ContentView**

In `ContentView.swift`, add a `@State` for the code text field:

```swift
@State private var pairingCode = ""
```

In the `body`, after the `if !connectionManager.isConnected` block but before the `else` (connected content), add a check for pairing. Replace the structure so it becomes:

```swift
var body: some View {
    VStack(spacing: 0) {
        if !connectionManager.isConnected {
            // ...existing discovery/connecting UI unchanged...
        } else if connectionManager.pairingRequired {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)

                Text("Enter Pairing Code")
                    .font(.headline)

                Text("Check your Mac for the 4-digit code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Code", text: $pairingCode)
                    .keyboardType(.numberPad)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(width: 160)
                    .textFieldStyle(.roundedBorder)

                if connectionManager.pairingFailed {
                    Text("Wrong code. Try again.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("Pair") {
                    connectionManager.submitPairingCode(pairingCode)
                }
                .buttonStyle(.borderedProminent)
                .disabled(pairingCode.count < 4)
            }
            .padding()
            Spacer()
        } else {
            // ...existing connected UI (status bar, trackpad, action buttons)...
        }
    }
}
```

- [x] **Step 7: Build MikanRemote to verify compilation**

```bash
cd MikanRemote && xcodegen generate && xcodebuild -scheme MikanRemote -configuration Debug -destination 'generic/platform=iOS' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [x] **Step 8: Commit**

```bash
git add MikanRemote/MikanRemote/ConnectionManager.swift MikanRemote/MikanRemote/ContentView.swift
git commit -m "feat: add pairing code entry flow to iOS client"
```

---

### Task 6: Add Left/Right Arrow Key Commands

**Files:**
- Modify: `MikanServer/MikanServer/MenuBarManager.swift`
- Modify: `MikanRemote/MikanRemote/ActionButtonsView.swift`

- [x] **Step 1: Add arrow key handling to server**

In `MenuBarManager.swift`, add to the `handleCommand()` switch:

```swift
case "arrowLeft":
    mouseController.sendKeyPress(keyCode: 123, flags: [])
case "arrowRight":
    mouseController.sendKeyPress(keyCode: 124, flags: [])
```

- [x] **Step 2: Add arrow buttons to iOS ActionButtonsView**

In `ActionButtonsView.swift`, add arrow buttons to the command buttons HStack. Insert them between the volume buttons and Fullscreen:

```swift
HStack(spacing: 10) {
    IconButton(icon: "speaker.minus") {
        onCommand("volumeDown")
    }
    IconButton(icon: "speaker.plus") {
        onCommand("volumeUp")
    }
    IconButton(icon: "arrowtriangle.backward.fill") {
        onCommand("arrowLeft")
    }
    IconButton(icon: "arrowtriangle.forward.fill") {
        onCommand("arrowRight")
    }
    CommandButton(label: "Fullscreen", icon: "arrow.up.left.and.arrow.down.right") {
        onCommand("fullscreen")
    }
    CommandButton(label: "Escape", icon: "escape") {
        onCommand("escape")
    }
}
```

- [x] **Step 3: Build both apps to verify**

```bash
cd MikanProtocol && swift test 2>&1 | tail -3
cd ../MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build 2>&1 | tail -5
cd ../MikanRemote && xcodegen generate && xcodebuild -scheme MikanRemote -configuration Debug -destination 'generic/platform=iOS' build 2>&1 | tail -5
```

Expected: All pass/succeed.

- [x] **Step 4: Commit**

```bash
git add MikanServer/MikanServer/MenuBarManager.swift MikanRemote/MikanRemote/ActionButtonsView.swift
git commit -m "feat: add left/right arrow key buttons for video seeking"
```

---

### Task 7: Redesign Cursor Overlay — Solid Red, Hollow Center, Bigger

**Files:**
- Modify: `MikanServer/MikanServer/CursorOverlayController.swift`

- [x] **Step 1: Update CursorView drawing**

Replace the `draw()` method in the `CursorView` class in `CursorOverlayController.swift`:

```swift
private final class CursorView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let red = NSColor.red.cgColor

        // Outer ring — solid red, thick
        let outerRadius: CGFloat = 50
        ctx.setStrokeColor(red)
        ctx.setLineWidth(5.0)
        ctx.addArc(center: center, radius: outerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()

        // Center ring — hollow (stroke only, no fill)
        let dotRadius: CGFloat = 10
        ctx.setStrokeColor(red)
        ctx.setLineWidth(3.0)
        ctx.addArc(center: center, radius: dotRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()

        // White outline on outer ring for contrast on dark backgrounds
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(1.5)
        ctx.addArc(center: center, radius: outerRadius + 4, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()
    }
}
```

- [x] **Step 2: Increase cursor window size**

In `CursorOverlayController`, change the `cursorSize` property:

```swift
private let cursorSize: CGFloat = 140
```

(was 120 — now accommodates the larger 50pt outer radius + contrast outline)

- [x] **Step 3: Build MikanServer**

```bash
cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [x] **Step 4: Commit**

```bash
git add MikanServer/MikanServer/CursorOverlayController.swift
git commit -m "feat: redesign cursor overlay — solid red, hollow center, bigger"
```

---

### Task 8: Build & Install for Testing

- [x] **Step 1: Run full protocol test suite**

```bash
cd MikanProtocol && swift test
```

Expected: All tests pass.

- [x] **Step 2: Build and install MikanServer**

```bash
cd MikanServer && xcodegen generate && xcodebuild -scheme MikanServer -configuration Release build
APP_PATH=$(xcodebuild -scheme MikanServer -configuration Release -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')
rm -rf /Applications/MikanServer.app && cp -R "$APP_PATH/MikanServer.app" /Applications/MikanServer.app
```

**IMPORTANT:** After install, toggle Accessibility OFF then ON for MikanServer in System Settings > Privacy & Security > Accessibility.

- [x] **Step 3: Generate MikanRemote Xcode project**

```bash
cd MikanRemote && xcodegen generate && open MikanRemote.xcodeproj
```

Then build and deploy to physical iPhone from Xcode (Cmd+R).

- [x] **Step 4: Manual test checklist**

1. Launch MikanServer — verify it starts, shows "Waiting for connection..."
2. Launch MikanRemote on iPhone — it should discover server and connect
3. **First connection:** iPhone should show pairing code entry screen. Mac should show floating window with 4-digit code.
4. Enter wrong code — verify "Wrong code" error appears
5. Enter correct code — verify pairing succeeds, normal trackpad/buttons appear
6. Kill MikanRemote and reopen — should auto-reconnect **without** asking for code again
7. Tap left arrow button — verify YouTube video skips back 5s
8. Tap right arrow button — verify YouTube video skips forward 5s
9. Move trackpad — verify cursor overlay is solid red, bigger, with hollow center dot
10. On Mac menu bar, check "Unpair All Devices" button works (next connection should re-prompt for code)
