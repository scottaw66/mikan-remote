# Mikan Remote Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iPhone-to-Mac remote control with trackpad-style mouse control and configurable quick-action buttons over the local network.

**Architecture:** Three components — a macOS menu bar app (MikanServer), an iOS app (MikanRemote), and a shared Swift Package (MikanProtocol). The Mac advertises via Bonjour, communicates over WebSocket using Network.framework, and controls the mouse via CGEvent. The iPhone is a thin client with no local state.

**Tech Stack:** Swift, SwiftUI, Network.framework (WebSocket), CGEvent, Bonjour/NetService, Xcode projects with local Swift Package dependency.

---

## File Structure

### MikanProtocol (Swift Package)

```
MikanProtocol/
├── Package.swift
├── Sources/MikanProtocol/
│   ├── Messages.swift          # All Codable message types + JSON coding
│   └── ActionConfig.swift      # Action model + default actions
└── Tests/MikanProtocolTests/
    └── MessagesTests.swift     # Round-trip encoding/decoding tests
```

### MikanServer (macOS app)

```
MikanServer/
├── MikanServer.xcodeproj
├── MikanServer/
│   ├── MikanServerApp.swift    # App entry point, menu bar setup
│   ├── MenuBarManager.swift    # Menu bar icon, dropdown, status
│   ├── WebSocketServer.swift   # NWListener + NWConnection WebSocket server
│   ├── MouseController.swift   # CGEvent mouse move/click/scroll
│   ├── ActionStore.swift       # Load/save/edit actions JSON config
│   ├── ActionEditorView.swift  # SwiftUI settings window for actions
│   ├── Assets.xcassets/        # Menu bar icons
│   └── Info.plist
└── MikanServerTests/
    ├── MouseControllerTests.swift
    └── ActionStoreTests.swift
```

### MikanRemote (iOS app)

```
MikanRemote/
├── MikanRemote.xcodeproj
├── MikanRemote/
│   ├── MikanRemoteApp.swift    # App entry point
│   ├── ContentView.swift       # Main screen: status + trackpad + buttons
│   ├── TrackpadView.swift      # UIKit touch tracking view (UIViewRepresentable)
│   ├── ActionButtonsView.swift # Horizontal scrollable action buttons
│   ├── ConnectionManager.swift # Bonjour browse + WebSocket client + reconnect
│   ├── ServerPickerView.swift  # List of discovered servers (if multiple)
│   ├── Assets.xcassets/
│   └── Info.plist
└── MikanRemoteTests/
    └── ConnectionManagerTests.swift
```

---

## Task 1: MikanProtocol — Shared Message Types

**Files:**
- Create: `MikanProtocol/Package.swift`
- Create: `MikanProtocol/Sources/MikanProtocol/Messages.swift`
- Create: `MikanProtocol/Sources/MikanProtocol/ActionConfig.swift`
- Create: `MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift`

- [ ] **Step 1: Create the Swift Package**

```bash
mkdir -p MikanProtocol
```

```swift
// MikanProtocol/Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MikanProtocol",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "MikanProtocol", targets: ["MikanProtocol"]),
    ],
    targets: [
        .target(name: "MikanProtocol"),
        .testTarget(name: "MikanProtocolTests", dependencies: ["MikanProtocol"]),
    ]
)
```

- [ ] **Step 2: Write failing tests for message encoding/decoding**

```swift
// MikanProtocol/Tests/MikanProtocolTests/MessagesTests.swift
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd MikanProtocol && swift test 2>&1 | head -20`
Expected: Compilation errors — `ClientMessage`, `ServerMessage`, `Action` not defined.

- [ ] **Step 4: Implement the Action model**

```swift
// MikanProtocol/Sources/MikanProtocol/ActionConfig.swift
import Foundation

public struct Action: Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let url: String
    public let icon: String?

    public init(id: String, label: String, url: String, icon: String? = nil) {
        self.id = id
        self.label = label
        self.url = url
        self.icon = icon
    }

    public static let defaults: [Action] = [
        Action(id: "netflix", label: "Netflix", url: "https://netflix.com", icon: "play.tv"),
        Action(id: "youtube", label: "YouTube", url: "https://youtube.com", icon: "play.rectangle"),
    ]
}
```

- [ ] **Step 5: Implement the message types**

```swift
// MikanProtocol/Sources/MikanProtocol/Messages.swift
import Foundation

public enum MouseButton: String, Codable, Sendable {
    case left
    case right
}

public enum ClientMessage: Codable, Sendable {
    case mouseMove(deltaX: Float, deltaY: Float)
    case mouseClick(button: MouseButton)
    case mouseScroll(deltaX: Float, deltaY: Float)
    case openURL(url: String)

    enum CodingKeys: String, CodingKey {
        case type, deltaX, deltaY, button, url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "mouseMove":
            let dx = try container.decode(Float.self, forKey: .deltaX)
            let dy = try container.decode(Float.self, forKey: .deltaY)
            self = .mouseMove(deltaX: dx, deltaY: dy)
        case "mouseClick":
            let button = try container.decode(MouseButton.self, forKey: .button)
            self = .mouseClick(button: button)
        case "mouseScroll":
            let dx = try container.decode(Float.self, forKey: .deltaX)
            let dy = try container.decode(Float.self, forKey: .deltaY)
            self = .mouseScroll(deltaX: dx, deltaY: dy)
        case "openURL":
            let url = try container.decode(String.self, forKey: .url)
            self = .openURL(url: url)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown client message type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .mouseMove(let dx, let dy):
            try container.encode("mouseMove", forKey: .type)
            try container.encode(dx, forKey: .deltaX)
            try container.encode(dy, forKey: .deltaY)
        case .mouseClick(let button):
            try container.encode("mouseClick", forKey: .type)
            try container.encode(button, forKey: .button)
        case .mouseScroll(let dx, let dy):
            try container.encode("mouseScroll", forKey: .type)
            try container.encode(dx, forKey: .deltaX)
            try container.encode(dy, forKey: .deltaY)
        case .openURL(let url):
            try container.encode("openURL", forKey: .type)
            try container.encode(url, forKey: .url)
        }
    }
}

public enum ServerMessage: Codable, Sendable {
    case actionConfig(actions: [Action])
    case serverStatus(connected: Bool, hostname: String)

    enum CodingKeys: String, CodingKey {
        case type, actions, connected, hostname
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "actionConfig":
            let actions = try container.decode([Action].self, forKey: .actions)
            self = .actionConfig(actions: actions)
        case "serverStatus":
            let connected = try container.decode(Bool.self, forKey: .connected)
            let hostname = try container.decode(String.self, forKey: .hostname)
            self = .serverStatus(connected: connected, hostname: hostname)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown server message type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .actionConfig(let actions):
            try container.encode("actionConfig", forKey: .type)
            try container.encode(actions, forKey: .actions)
        case .serverStatus(let connected, let hostname):
            try container.encode("serverStatus", forKey: .type)
            try container.encode(connected, forKey: .connected)
            try container.encode(hostname, forKey: .hostname)
        }
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd MikanProtocol && swift test`
Expected: All 8 tests pass.

- [ ] **Step 7: Commit**

```bash
git add MikanProtocol/
git commit -m "feat: add MikanProtocol shared package with message types and tests"
```

---

## Task 2: MikanServer — Xcode Project Scaffold + Action Store

**Files:**
- Create: `MikanServer/MikanServer.xcodeproj` (via Xcode CLI or manual)
- Create: `MikanServer/MikanServer/MikanServerApp.swift`
- Create: `MikanServer/MikanServer/ActionStore.swift`
- Create: `MikanServer/MikanServerTests/ActionStoreTests.swift`

- [ ] **Step 1: Create the macOS app Xcode project**

Use Xcode command line or create manually. The project must:
- Be a macOS app, Swift, SwiftUI lifecycle
- Deployment target: macOS 13.0
- Add `MikanProtocol` as a local package dependency (path: `../MikanProtocol`)
- Add the `MikanProtocol` library to the app target's frameworks
- Set `LSUIElement` to `YES` in Info.plist (hides from Dock — menu bar app)

Minimal app entry point to verify it builds:

```swift
// MikanServer/MikanServer/MikanServerApp.swift
import SwiftUI

@main
struct MikanServerApp: App {
    var body: some Scene {
        MenuBarExtra("Mikan Server", systemImage: "antenna.radiowaves.left.and.right") {
            Text("Mikan Server")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
```

- [ ] **Step 2: Build the project to verify it compiles**

Run: `xcodebuild -project MikanServer/MikanServer.xcodeproj -scheme MikanServer build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Write failing tests for ActionStore**

```swift
// MikanServer/MikanServerTests/ActionStoreTests.swift
import XCTest
@testable import MikanServer
import MikanProtocol

final class ActionStoreTests: XCTestCase {

    var tempDir: URL!
    var store: ActionStore!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = ActionStore(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testLoadsDefaultsWhenNoFile() {
        XCTAssertEqual(store.actions, Action.defaults)
    }

    func testSaveAndLoad() throws {
        let custom = [Action(id: "test", label: "Test", url: "https://example.com")]
        store.actions = custom
        try store.save()

        let reloaded = ActionStore(directory: tempDir)
        XCTAssertEqual(reloaded.actions, custom)
    }

    func testSaveCreatesFile() throws {
        try store.save()
        let filePath = tempDir.appendingPathComponent("actions.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: filePath.path))
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `xcodebuild test -project MikanServer/MikanServer.xcodeproj -scheme MikanServer -destination 'platform=macOS' 2>&1 | tail -10`
Expected: Compilation error — `ActionStore` not defined.

- [ ] **Step 5: Implement ActionStore**

```swift
// MikanServer/MikanServer/ActionStore.swift
import Foundation
import MikanProtocol

@Observable
final class ActionStore {
    private let fileURL: URL
    var actions: [Action]

    init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("actions.json")
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode([Action].self, from: data) {
            self.actions = loaded
        } else {
            self.actions = Action.defaults
        }
    }

    convenience init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MikanServer")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.init(directory: dir)
    }

    func save() throws {
        let data = try JSONEncoder().encode(actions)
        try data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `xcodebuild test -project MikanServer/MikanServer.xcodeproj -scheme MikanServer -destination 'platform=macOS' 2>&1 | grep -E '(Test Suite|Test Case|BUILD)'`
Expected: All 3 tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 7: Commit**

```bash
git add MikanServer/
git commit -m "feat: scaffold MikanServer macOS app with ActionStore"
```

---

## Task 3: MikanServer — Mouse Controller

**Files:**
- Create: `MikanServer/MikanServer/MouseController.swift`
- Create: `MikanServer/MikanServerTests/MouseControllerTests.swift`

- [ ] **Step 1: Write failing tests for MouseController**

```swift
// MikanServer/MikanServerTests/MouseControllerTests.swift
import XCTest
@testable import MikanServer

final class MouseControllerTests: XCTestCase {

    func testMoveUpdatesPosition() {
        let controller = MouseController()
        let before = CGEvent(source: nil)!.location
        controller.move(deltaX: 10, deltaY: 0, sensitivity: 1.0)
        let after = CGEvent(source: nil)!.location
        // The cursor should have moved right by ~10 points
        XCTAssertEqual(after.x, before.x + 10, accuracy: 2.0)
        XCTAssertEqual(after.y, before.y, accuracy: 2.0)
    }

    func testSensitivityMultiplier() {
        let controller = MouseController()
        let before = CGEvent(source: nil)!.location
        controller.move(deltaX: 10, deltaY: 0, sensitivity: 2.0)
        let after = CGEvent(source: nil)!.location
        XCTAssertEqual(after.x, before.x + 20, accuracy: 2.0)
    }

    func testClickDoesNotCrash() {
        let controller = MouseController()
        // Just verify it doesn't throw/crash — click at current position
        controller.click(button: .left)
        controller.click(button: .right)
    }

    func testScrollDoesNotCrash() {
        let controller = MouseController()
        controller.scroll(deltaX: 0, deltaY: -3)
    }
}
```

Note: These tests require Accessibility permission for the test runner. On CI, they may need to be skipped. They work locally when System Settings > Privacy > Accessibility has the terminal/Xcode allowed.

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project MikanServer/MikanServer.xcodeproj -scheme MikanServer -destination 'platform=macOS' 2>&1 | tail -10`
Expected: Compilation error — `MouseController` not defined.

- [ ] **Step 3: Implement MouseController**

```swift
// MikanServer/MikanServer/MouseController.swift
import CoreGraphics
import MikanProtocol

final class MouseController {

    func move(deltaX: Float, deltaY: Float, sensitivity: Double) {
        let current = CGEvent(source: nil)?.location ?? .zero
        let newX = current.x + CGFloat(Double(deltaX) * sensitivity)
        let newY = current.y + CGFloat(Double(deltaY) * sensitivity)
        let point = CGPoint(x: newX, y: newY)
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    func click(button: MouseButton) {
        let current = CGEvent(source: nil)?.location ?? .zero
        let (down, up): (CGEventType, CGEventType) = button == .left
            ? (.leftMouseDown, .leftMouseUp)
            : (.rightMouseDown, .rightMouseUp)
        let cgButton: CGMouseButton = button == .left ? .left : .right
        CGEvent(mouseEventSource: nil, mouseType: down, mouseCursorPosition: current, mouseButton: cgButton)?.post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: nil, mouseType: up, mouseCursorPosition: current, mouseButton: cgButton)?.post(tap: .cghidEventTap)
    }

    func scroll(deltaX: Float, deltaY: Float) {
        if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(deltaY), wheel2: Int32(deltaX)) {
            event.post(tap: .cghidEventTap)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project MikanServer/MikanServer.xcodeproj -scheme MikanServer -destination 'platform=macOS' 2>&1 | grep -E '(Test Case|BUILD)'`
Expected: All MouseController and ActionStore tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add MikanServer/MikanServer/MouseController.swift MikanServer/MikanServerTests/MouseControllerTests.swift
git commit -m "feat: add MouseController for CGEvent mouse control"
```

---

## Task 4: MikanServer — Bonjour Advertiser

**Files:**
- Create: `MikanServer/MikanServer/BonjourAdvertiser.swift`

- [ ] **Step 1: Implement BonjourAdvertiser**

This is a thin wrapper around `NWListener` for Bonjour advertisement. It's tested indirectly via integration with the WebSocket server (Task 5). Unit testing Bonjour requires real network stack which is better validated end-to-end.

```swift
// MikanServer/MikanServer/BonjourAdvertiser.swift
import Network

final class BonjourAdvertiser {
    private let listener: NWListener
    let port: NWEndpoint.Port

    init() throws {
        let params = NWParameters.tcp
        listener = try NWListener(using: params)
        listener.service = NWListener.Service(name: nil, type: "_mikan._tcp")
        listener.stateUpdateHandler = { state in
            if case .ready = state, let port = self.listener.port {
                print("Bonjour advertising on port \(port)")
            }
        }
        listener.start(queue: .main)
        // Wait briefly for port assignment
        self.port = listener.port ?? .any
    }

    var actualPort: UInt16? {
        listener.port?.rawValue
    }

    func stop() {
        listener.cancel()
    }
}
```

Wait — the Bonjour advertisement and WebSocket server should share the same port. Let me revise: the WebSocket server (Task 5) will own the `NWListener` and advertise Bonjour through it, since `NWListener` supports both. This file is not needed as a separate component.

**Revised approach:** Delete this task's file. Bonjour is handled inside `WebSocketServer` (Task 5) since `NWListener` natively supports setting a Bonjour service on the same listener that handles WebSocket connections. No separate advertiser needed.

- [ ] **Step 2: Commit (skip — no file created)**

This task produces no artifacts. Bonjour is folded into Task 5.

---

## Task 5: MikanServer — WebSocket Server with Bonjour

**Files:**
- Create: `MikanServer/MikanServer/WebSocketServer.swift`

- [ ] **Step 1: Implement WebSocketServer**

This combines WebSocket serving and Bonjour advertisement in one class, since `NWListener` handles both.

```swift
// MikanServer/MikanServer/WebSocketServer.swift
import Foundation
import Network
import MikanProtocol

@Observable
final class WebSocketServer {
    private var listener: NWListener?
    private var activeConnection: NWConnection?
    private(set) var isClientConnected = false
    private(set) var clientName: String?

    var onClientMessage: ((ClientMessage) -> Void)?
    var onConnectionChanged: ((Bool, String?) -> Void)?

    func start() throws {
        let params = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        listener = try NWListener(using: params)
        listener?.service = NWListener.Service(name: nil, type: "_mikan._tcp")

        listener?.stateUpdateHandler = { state in
            if case .ready = state, let port = self.listener?.port {
                print("Mikan server listening on port \(port)")
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: .main)
    }

    func stop() {
        activeConnection?.cancel()
        listener?.cancel()
        activeConnection = nil
        listener = nil
        isClientConnected = false
        clientName = nil
    }

    func send(_ message: ServerMessage) {
        guard let connection = activeConnection else { return }
        guard let data = try? JSONEncoder().encode(message) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        connection.send(content: data, contentContext: context, completion: .idempotent)
    }

    private func handleNewConnection(_ connection: NWConnection) {
        // Single connection — drop existing
        activeConnection?.cancel()

        activeConnection = connection
        let endpoint = connection.endpoint
        if case .hostPort(let host, _) = endpoint {
            clientName = "\(host)"
        }

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isClientConnected = true
                self?.onConnectionChanged?(true, self?.clientName)
                self?.receiveMessage(on: connection)
            case .cancelled, .failed:
                self?.isClientConnected = false
                self?.clientName = nil
                self?.onConnectionChanged?(false, nil)
            default:
                break
            }
        }

        connection.start(queue: .main)
    }

    private func receiveMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self] content, context, _, error in
            if let data = content,
               let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata,
               metadata.opcode == .text {
                if let message = try? JSONDecoder().decode(ClientMessage.self, from: data) {
                    self?.onClientMessage?(message)
                }
            }
            if error == nil {
                self?.receiveMessage(on: connection)
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project MikanServer/MikanServer.xcodeproj -scheme MikanServer build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MikanServer/MikanServer/WebSocketServer.swift
git commit -m "feat: add WebSocketServer with Bonjour advertisement"
```

---

## Task 6: MikanServer — Menu Bar UI + Wiring

**Files:**
- Modify: `MikanServer/MikanServer/MikanServerApp.swift`
- Create: `MikanServer/MikanServer/MenuBarManager.swift`

- [ ] **Step 1: Implement MenuBarManager**

```swift
// MikanServer/MikanServer/MenuBarManager.swift
import Foundation
import MikanProtocol

@Observable
final class MenuBarManager {
    let server = WebSocketServer()
    let actionStore = ActionStore()
    var sensitivity: Double = 1.0
    private let mouseController = MouseController()

    var statusText: String {
        if server.isClientConnected, let name = server.clientName {
            return "Connected: \(name)"
        }
        return "Waiting for connection..."
    }

    var isConnected: Bool { server.isClientConnected }

    func start() throws {
        server.onClientMessage = { [weak self] message in
            self?.handleMessage(message)
        }
        server.onConnectionChanged = { [weak self] connected, _ in
            guard let self, connected else { return }
            let hostname = ProcessInfo.processInfo.hostName
            server.send(.serverStatus(connected: true, hostname: hostname))
            server.send(.actionConfig(actions: actionStore.actions))
        }
        try server.start()
    }

    func pushActions() {
        server.send(.actionConfig(actions: actionStore.actions))
    }

    private func handleMessage(_ message: ClientMessage) {
        switch message {
        case .mouseMove(let dx, let dy):
            mouseController.move(deltaX: dx, deltaY: dy, sensitivity: sensitivity)
        case .mouseClick(let button):
            mouseController.click(button: button)
        case .mouseScroll(let dx, let dy):
            mouseController.scroll(deltaX: dx, deltaY: dy)
        case .openURL(let urlString):
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
```

- [ ] **Step 2: Update the app entry point**

```swift
// MikanServer/MikanServer/MikanServerApp.swift
import SwiftUI

@main
struct MikanServerApp: App {
    @State private var manager = MenuBarManager()

    var body: some Scene {
        MenuBarExtra {
            Text(manager.statusText)
                .font(.caption)
            Divider()
            HStack {
                Text("Sensitivity")
                Slider(value: $manager.sensitivity, in: 0.5...3.0, step: 0.25)
                    .frame(width: 120)
                Text(String(format: "%.1fx", manager.sensitivity))
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            Divider()
            Button("Edit Actions...") {
                NSApp.activate(ignoringOtherApps: true)
                openActionEditor()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: manager.isConnected
                  ? "antenna.radiowaves.left.and.right"
                  : "antenna.radiowaves.left.and.right.slash")
        }
        .onAppear {
            try? manager.start()
        }

        Window("Edit Actions", id: "action-editor") {
            ActionEditorView(store: manager.actionStore, onSave: { manager.pushActions() })
        }
        .defaultSize(width: 500, height: 400)
    }

    private func openActionEditor() {
        NSApp.sendAction(Selector(("showWindow:")), to: nil, from: "action-editor")
        // Alternative: use @Environment(\.openWindow) in a view context
    }
}
```

Note: The `openActionEditor()` approach may need adjustment. A cleaner pattern is to use `@Environment(\.openWindow)` from within the menu content. Adjust during implementation if needed — the key requirement is that "Edit Actions..." opens the action editor window.

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project MikanServer/MikanServer.xcodeproj -scheme MikanServer build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED` (ActionEditorView doesn't exist yet — create a stub to compile)

If ActionEditorView is missing, add a temporary stub:

```swift
// MikanServer/MikanServer/ActionEditorView.swift (stub)
import SwiftUI
import MikanProtocol

struct ActionEditorView: View {
    var store: ActionStore
    var onSave: () -> Void

    var body: some View {
        Text("TODO: Action editor")
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add MikanServer/MikanServer/MenuBarManager.swift MikanServer/MikanServer/MikanServerApp.swift MikanServer/MikanServer/ActionEditorView.swift
git commit -m "feat: add menu bar UI and wire up server + mouse controller"
```

---

## Task 7: MikanServer — Action Editor View

**Files:**
- Modify: `MikanServer/MikanServer/ActionEditorView.swift`

- [ ] **Step 1: Implement the action editor**

Replace the stub with the full implementation:

```swift
// MikanServer/MikanServer/ActionEditorView.swift
import SwiftUI
import MikanProtocol

struct ActionEditorView: View {
    @Bindable var store: ActionStore
    var onSave: () -> Void
    @State private var selection: Action.ID?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach($store.actions, id: \.id) { $action in
                    ActionRow(action: $action)
                }
                .onDelete { indices in
                    store.actions.remove(atOffsets: indices)
                }
                .onMove { source, destination in
                    store.actions.move(fromOffsets: source, toOffset: destination)
                }
            }

            Divider()

            HStack {
                Button {
                    let new = Action(
                        id: UUID().uuidString,
                        label: "New Action",
                        url: "https://example.com"
                    )
                    store.actions.append(new)
                } label: {
                    Image(systemName: "plus")
                }

                Button {
                    if let sel = selection {
                        store.actions.removeAll { $0.id == sel }
                        selection = nil
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)

                Spacer()

                Button("Reset to Defaults") {
                    store.actions = Action.defaults
                }

                Button("Save") {
                    try? store.save()
                    onSave()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(12)
        }
        .frame(minWidth: 450, minHeight: 300)
    }
}

struct ActionRow: View {
    @Binding var action: Action

    var body: some View {
        HStack(spacing: 12) {
            if let icon = action.icon, !icon.isEmpty {
                Image(systemName: icon)
                    .frame(width: 20)
            }
            VStack(alignment: .leading, spacing: 2) {
                TextField("Label", text: Binding(
                    get: { action.label },
                    set: { action = Action(id: action.id, label: $0, url: action.url, icon: action.icon) }
                ))
                .textFieldStyle(.plain)
                .font(.headline)

                TextField("URL", text: Binding(
                    get: { action.url },
                    set: { action = Action(id: action.id, label: action.label, url: $0, icon: action.icon) }
                ))
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            TextField("SF Symbol", text: Binding(
                get: { action.icon ?? "" },
                set: { action = Action(id: action.id, label: action.label, url: action.url, icon: $0.isEmpty ? nil : $0) }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)
        }
        .padding(.vertical, 4)
    }
}
```

Note: `Action` must conform to `Identifiable` for `ForEach` to work. Update `ActionConfig.swift` in MikanProtocol — add `extension Action: Identifiable {}` since `id` already exists.

- [ ] **Step 2: Add Identifiable conformance to Action**

In `MikanProtocol/Sources/MikanProtocol/ActionConfig.swift`, add after the struct closing brace:

```swift
extension Action: Identifiable {}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project MikanServer/MikanServer.xcodeproj -scheme MikanServer build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add MikanServer/MikanServer/ActionEditorView.swift MikanProtocol/Sources/MikanProtocol/ActionConfig.swift
git commit -m "feat: add action editor settings view"
```

---

## Task 8: MikanRemote — Xcode Project Scaffold + Connection Manager

**Files:**
- Create: `MikanRemote/MikanRemote.xcodeproj` (via Xcode)
- Create: `MikanRemote/MikanRemote/MikanRemoteApp.swift`
- Create: `MikanRemote/MikanRemote/ConnectionManager.swift`
- Create: `MikanRemote/MikanRemote/ContentView.swift`

- [ ] **Step 1: Create the iOS app Xcode project**

Create an iOS app project:
- iOS, Swift, SwiftUI lifecycle
- Deployment target: iOS 16.0
- Add `MikanProtocol` as a local package dependency (path: `../MikanProtocol`)
- Add the `MikanProtocol` library to the app target's frameworks
- Add `NSLocalNetworkUsageDescription` to Info.plist: "Mikan Remote needs local network access to find and connect to your Mac."
- Add `NSBonjourServices` array to Info.plist with `_mikan._tcp`

- [ ] **Step 2: Implement ConnectionManager**

```swift
// MikanRemote/MikanRemote/ConnectionManager.swift
import Foundation
import Network
import MikanProtocol

@Observable
final class ConnectionManager {
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var reconnectTask: Task<Void, Never>?

    private(set) var discoveredServers: [NWBrowser.Result] = []
    private(set) var isConnected = false
    private(set) var hostname: String?
    private(set) var actions: [Action] = []

    var onServerMessage: ((ServerMessage) -> Void)?

    func startBrowsing() {
        let params = NWParameters()
        params.includePeerToPeer = true
        browser = NWBrowser(for: .bonjour(type: "_mikan._tcp", domain: nil), using: params)

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.discoveredServers = Array(results)
                // Auto-connect if exactly one server found
                if results.count == 1, self?.connection == nil {
                    self?.connect(to: results.first!)
                }
            }
        }

        browser?.start(queue: .main)
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    func connect(to result: NWBrowser.Result) {
        connection?.cancel()

        let params = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        connection = NWConnection(to: result.endpoint, using: params)

        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.receiveMessage()
                case .cancelled, .failed:
                    self?.isConnected = false
                    self?.hostname = nil
                    self?.scheduleReconnect(to: result)
                default:
                    break
                }
            }
        }

        connection?.start(queue: .main)
    }

    func disconnect() {
        reconnectTask?.cancel()
        connection?.cancel()
        connection = nil
        isConnected = false
        hostname = nil
        actions = []
    }

    func send(_ message: ClientMessage) {
        guard let connection, isConnected else { return }
        guard let data = try? JSONEncoder().encode(message) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        connection.send(content: data, contentContext: context, completion: .idempotent)
    }

    private func receiveMessage() {
        connection?.receiveMessage { [weak self] content, context, _, error in
            if let data = content,
               let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata,
               metadata.opcode == .text {
                if let message = try? JSONDecoder().decode(ServerMessage.self, from: data) {
                    Task { @MainActor in
                        self?.handleServerMessage(message)
                    }
                }
            }
            if error == nil {
                self?.receiveMessage()
            }
        }
    }

    private func handleServerMessage(_ message: ServerMessage) {
        switch message {
        case .actionConfig(let newActions):
            actions = newActions
        case .serverStatus(_, let name):
            hostname = name
        }
        onServerMessage?(message)
    }

    private func scheduleReconnect(to result: NWBrowser.Result) {
        reconnectTask?.cancel()
        reconnectTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            connect(to: result)
        }
    }
}
```

- [ ] **Step 3: Add minimal app entry point and content view**

```swift
// MikanRemote/MikanRemote/MikanRemoteApp.swift
import SwiftUI

@main
struct MikanRemoteApp: App {
    @State private var connectionManager = ConnectionManager()

    var body: some Scene {
        WindowGroup {
            ContentView(connectionManager: connectionManager)
                .onAppear {
                    connectionManager.startBrowsing()
                }
        }
    }
}
```

```swift
// MikanRemote/MikanRemote/ContentView.swift
import SwiftUI
import MikanProtocol

struct ContentView: View {
    @Bindable var connectionManager: ConnectionManager

    var body: some View {
        VStack {
            if connectionManager.isConnected {
                Text("Connected to \(connectionManager.hostname ?? "Mac")")
            } else if connectionManager.discoveredServers.isEmpty {
                ProgressView("Scanning for Mikan servers...")
            } else {
                ServerPickerView(
                    servers: connectionManager.discoveredServers,
                    onSelect: { connectionManager.connect(to: $0) }
                )
            }
        }
    }
}
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild -project MikanRemote/MikanRemote.xcodeproj -scheme MikanRemote -destination 'generic/platform=iOS' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED` (ServerPickerView doesn't exist yet — add stub)

If ServerPickerView is missing, add a stub:

```swift
// MikanRemote/MikanRemote/ServerPickerView.swift
import SwiftUI
import Network

struct ServerPickerView: View {
    let servers: [NWBrowser.Result]
    let onSelect: (NWBrowser.Result) -> Void

    var body: some View {
        List(servers, id: \.endpoint) { server in
            Button(server.endpoint.debugDescription) {
                onSelect(server)
            }
        }
        .navigationTitle("Select Server")
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add MikanRemote/
git commit -m "feat: scaffold MikanRemote iOS app with ConnectionManager and Bonjour browsing"
```

---

## Task 9: MikanRemote — Trackpad View

**Files:**
- Create: `MikanRemote/MikanRemote/TrackpadView.swift`

- [ ] **Step 1: Implement the trackpad view**

This is a UIKit view wrapped in `UIViewRepresentable` for precise multi-touch tracking. SwiftUI gesture recognizers don't provide the continuous delta tracking or multi-finger discrimination needed.

```swift
// MikanRemote/MikanRemote/TrackpadView.swift
import SwiftUI
import UIKit

struct TrackpadView: UIViewRepresentable {
    var onMove: (Float, Float) -> Void
    var onTap: () -> Void
    var onTwoFingerTap: () -> Void
    var onScroll: (Float, Float) -> Void

    func makeUIView(context: Context) -> TrackpadUIView {
        let view = TrackpadUIView()
        view.onMove = onMove
        view.onTap = onTap
        view.onTwoFingerTap = onTwoFingerTap
        view.onScroll = onScroll
        view.isMultipleTouchEnabled = true
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 16
        return view
    }

    func updateUIView(_ uiView: TrackpadUIView, context: Context) {
        uiView.onMove = onMove
        uiView.onTap = onTap
        uiView.onTwoFingerTap = onTwoFingerTap
        uiView.onScroll = onScroll
    }
}

final class TrackpadUIView: UIView {
    var onMove: ((Float, Float) -> Void)?
    var onTap: (() -> Void)?
    var onTwoFingerTap: (() -> Void)?
    var onScroll: ((Float, Float) -> Void)?

    private var previousTouchLocation: CGPoint?
    private var previousScrollCenter: CGPoint?
    private var touchStartTime: Date?
    private var touchStartLocation: CGPoint?
    private var isTwoFingerDrag = false
    private let tapThreshold: TimeInterval = 0.25
    private let tapDistanceThreshold: CGFloat = 10

    private var feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let allTouches = event?.allTouches ?? touches
        if allTouches.count == 1, let touch = touches.first {
            previousTouchLocation = touch.location(in: self)
            touchStartTime = Date()
            touchStartLocation = previousTouchLocation
            isTwoFingerDrag = false
        } else if allTouches.count == 2 {
            isTwoFingerDrag = true
            previousScrollCenter = centerOfTouches(allTouches)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let allTouches = event?.allTouches ?? touches

        if allTouches.count == 2 && isTwoFingerDrag {
            let center = centerOfTouches(allTouches)
            if let prev = previousScrollCenter {
                let dx = Float(center.x - prev.x)
                let dy = Float(center.y - prev.y)
                onScroll?(dx, dy)
            }
            previousScrollCenter = center
        } else if allTouches.count == 1, let touch = allTouches.first {
            let location = touch.location(in: self)
            if let prev = previousTouchLocation {
                let dx = Float(location.x - prev.x)
                let dy = Float(location.y - prev.y)
                onMove?(dx, dy)
            }
            previousTouchLocation = location
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let allTouches = event?.allTouches ?? touches
        let remaining = allTouches.filter { $0.phase != .ended && $0.phase != .cancelled }

        if remaining.isEmpty {
            if let startTime = touchStartTime, let startLoc = touchStartLocation {
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed < tapThreshold {
                    if let touch = touches.first {
                        let endLoc = touch.location(in: self)
                        let dist = hypot(endLoc.x - startLoc.x, endLoc.y - startLoc.y)
                        if dist < tapDistanceThreshold {
                            if allTouches.count >= 2 || isTwoFingerDrag {
                                feedbackGenerator.impactOccurred()
                                onTwoFingerTap?()
                            } else {
                                feedbackGenerator.impactOccurred()
                                onTap?()
                            }
                        }
                    }
                }
            }
            previousTouchLocation = nil
            previousScrollCenter = nil
            touchStartTime = nil
            touchStartLocation = nil
            isTwoFingerDrag = false
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        previousTouchLocation = nil
        previousScrollCenter = nil
        touchStartTime = nil
        touchStartLocation = nil
        isTwoFingerDrag = false
    }

    private func centerOfTouches(_ touches: Set<UITouch>) -> CGPoint {
        var x: CGFloat = 0
        var y: CGFloat = 0
        for touch in touches {
            let loc = touch.location(in: self)
            x += loc.x
            y += loc.y
        }
        let count = CGFloat(touches.count)
        return CGPoint(x: x / count, y: y / count)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project MikanRemote/MikanRemote.xcodeproj -scheme MikanRemote -destination 'generic/platform=iOS' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MikanRemote/MikanRemote/TrackpadView.swift
git commit -m "feat: add TrackpadView with multi-touch gesture support"
```

---

## Task 10: MikanRemote — Action Buttons View

**Files:**
- Create: `MikanRemote/MikanRemote/ActionButtonsView.swift`

- [ ] **Step 1: Implement the action buttons**

```swift
// MikanRemote/MikanRemote/ActionButtonsView.swift
import SwiftUI
import MikanProtocol

struct ActionButtonsView: View {
    let actions: [Action]
    let onAction: (Action) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(actions) { action in
                    Button {
                        onAction(action)
                    } label: {
                        VStack(spacing: 6) {
                            if let icon = action.icon, !icon.isEmpty {
                                Image(systemName: icon)
                                    .font(.title2)
                            }
                            Text(action.label)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(width: 72, height: 64)
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 80)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project MikanRemote/MikanRemote.xcodeproj -scheme MikanRemote -destination 'generic/platform=iOS' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MikanRemote/MikanRemote/ActionButtonsView.swift
git commit -m "feat: add ActionButtonsView for quick actions"
```

---

## Task 11: MikanRemote — Wire Up Main Screen

**Files:**
- Modify: `MikanRemote/MikanRemote/ContentView.swift`

- [ ] **Step 1: Wire up the full main screen**

Replace the stub ContentView with the full implementation:

```swift
// MikanRemote/MikanRemote/ContentView.swift
import SwiftUI
import MikanProtocol

struct ContentView: View {
    @Bindable var connectionManager: ConnectionManager

    var body: some View {
        VStack(spacing: 0) {
            if !connectionManager.isConnected {
                if connectionManager.discoveredServers.isEmpty {
                    Spacer()
                    ProgressView("Scanning for Mikan servers...")
                        .padding()
                    Spacer()
                } else if connectionManager.discoveredServers.count > 1 {
                    ServerPickerView(
                        servers: connectionManager.discoveredServers,
                        onSelect: { connectionManager.connect(to: $0) }
                    )
                } else {
                    Spacer()
                    ProgressView("Connecting...")
                        .padding()
                    Spacer()
                }
            } else {
                // Status bar
                HStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text(connectionManager.hostname ?? "Connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Trackpad
                TrackpadView(
                    onMove: { dx, dy in
                        connectionManager.send(.mouseMove(deltaX: dx, deltaY: dy))
                    },
                    onTap: {
                        connectionManager.send(.mouseClick(button: .left))
                    },
                    onTwoFingerTap: {
                        connectionManager.send(.mouseClick(button: .right))
                    },
                    onScroll: { dx, dy in
                        connectionManager.send(.mouseScroll(deltaX: dx, deltaY: dy))
                    }
                )
                .padding(.horizontal)
                .padding(.vertical, 4)

                // Action buttons
                if !connectionManager.actions.isEmpty {
                    ActionButtonsView(actions: connectionManager.actions) { action in
                        connectionManager.send(.openURL(url: action.url))
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project MikanRemote/MikanRemote.xcodeproj -scheme MikanRemote -destination 'generic/platform=iOS' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MikanRemote/MikanRemote/ContentView.swift
git commit -m "feat: wire up main screen with trackpad, status bar, and action buttons"
```

---

## Task 12: End-to-End Integration Test

**Files:** No new files — manual testing of both apps together.

- [ ] **Step 1: Build both apps**

Run:
```bash
xcodebuild -project MikanServer/MikanServer.xcodeproj -scheme MikanServer build 2>&1 | tail -3
xcodebuild -project MikanRemote/MikanRemote.xcodeproj -scheme MikanRemote -destination 'generic/platform=iOS' build 2>&1 | tail -3
```
Expected: Both `BUILD SUCCEEDED`.

- [ ] **Step 2: Run MikanServer on Mac**

Launch MikanServer from Xcode. Verify:
- Menu bar icon appears (antenna icon)
- Clicking it shows "Waiting for connection..."
- Console shows "Mikan server listening on port XXXXX"

- [ ] **Step 3: Run MikanRemote on iPhone (or simulator)**

Launch MikanRemote on a device or simulator on the same network. Verify:
- Shows "Scanning for Mikan servers..."
- Discovers the Mac and auto-connects
- Status bar shows "Connected" with the Mac's hostname
- Action buttons appear (Netflix, YouTube defaults)
- Menu bar on Mac updates to "Connected: ..."

- [ ] **Step 4: Test trackpad**

- Drag finger on trackpad area → cursor moves on Mac
- Single tap → left click at cursor position
- Two-finger tap → right click
- Two-finger drag → scroll

- [ ] **Step 5: Test action buttons**

- Tap "Netflix" → default browser opens netflix.com on Mac
- Tap "YouTube" → default browser opens youtube.com on Mac

- [ ] **Step 6: Test action editor**

- On Mac, click "Edit Actions..." in menu bar
- Add a new action, save
- Verify the new button appears on iPhone without reconnecting

- [ ] **Step 7: Test reconnection**

- Stop MikanServer (Quit from menu bar)
- Verify iPhone shows scanning/disconnected state
- Restart MikanServer
- Verify iPhone auto-reconnects

- [ ] **Step 8: Commit any fixes**

```bash
git add -A
git commit -m "fix: integration test fixes"
```
(Only if changes were needed during testing.)

---

## Task 13: Update Project Documentation

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update README.md**

```markdown
# Mikan Remote

A simple iPhone app to remote-control a Mac over your local network. Designed for when you're on an exercise bike and want to watch Netflix or YouTube on your Mac's display.

## Features

- Trackpad-style mouse control from your iPhone
- Configurable quick-action buttons (open URLs in default browser)
- Automatic discovery via Bonjour — no IP address needed
- Menu bar app on Mac — stays out of the way

## Requirements

- macOS 13.0+
- iOS 16.0+
- Both devices on the same local network

## Setup

1. Build and run **MikanServer** on your Mac
2. Grant Accessibility permission when prompted (System Settings > Privacy & Security > Accessibility)
3. Build and run **MikanRemote** on your iPhone
4. The iPhone auto-discovers and connects to your Mac

## Customizing Actions

Click the Mikan menu bar icon > "Edit Actions..." to add, remove, or reorder quick-action buttons. Changes sync to connected iPhones instantly.

## Project Structure

- `MikanServer/` — macOS menu bar app (Xcode project)
- `MikanRemote/` — iOS app (Xcode project)
- `MikanProtocol/` — Shared Swift Package (message types)

## License

MIT
```

- [ ] **Step 2: Update CLAUDE.md**

Update CLAUDE.md with build commands and architecture overview now that the codebase exists.

- [ ] **Step 3: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: update README and CLAUDE.md with project details"
```
