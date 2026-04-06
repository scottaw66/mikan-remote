import AppKit
import SwiftUI
import MikanProtocol

@Observable
final class MenuBarManager {
    let server = WebSocketServer()
    let actionStore = ActionStore()
    let pairingStore = PairingStore()
    var sensitivity: Double {
        didSet {
            UserDefaults.standard.set(sensitivity, forKey: "sensitivity")
            pushSettings()
        }
    }
    var cursorSize: Double {
        didSet {
            UserDefaults.standard.set(cursorSize, forKey: "cursorSize")
            cursorOverlay.updateSize(CGFloat(cursorSize))
            pushSettings()
        }
    }
    private var suppressSettingsSync = false
    private let mouseController = MouseController()
    private let cursorOverlay = CursorOverlayController()
    private var pairingPanel: NSPanel?

    init() {
        let stored = UserDefaults.standard.double(forKey: "sensitivity")
        self.sensitivity = stored > 0 ? stored : 10.0
        let storedSize = UserDefaults.standard.double(forKey: "cursorSize")
        self.cursorSize = storedSize > 0 ? storedSize : 140.0
        cursorOverlay.updateSize(CGFloat(self.cursorSize))
        server.onClientMessage = { [weak self] message in
            self?.handleMessage(message)
        }
        server.onConnectionChanged = { [weak self] connected, _ in
            guard let self else { return }
            if !connected {
                pairingStore.clearPending()
                dismissPairingPanel()
            }
        }
        try? server.start()
    }

    var statusText: String {
        if server.isClientConnected {
            return "Connected: \(server.clientName ?? "iPhone")"
        }
        return "Waiting for connection..."
    }

    var isConnected: Bool { server.isClientConnected }

    func pushActions() {
        server.send(.actionConfig(actions: actionStore.actions))
    }

    func pushSettings() {
        guard !suppressSettingsSync else { return }
        server.send(.settingsSync(sensitivity: sensitivity, cursorSize: cursorSize))
    }

    private func handleMessage(_ message: ClientMessage) {
        switch message {
        case .mouseMove(let dx, let dy):
            mouseController.move(deltaX: dx, deltaY: dy, sensitivity: sensitivity)
            if let pos = CGEvent(source: nil)?.location {
                cursorOverlay.showCursor(at: pos)
            }
        case .mouseClick:
            mouseController.click()
        case .mouseScroll(let dx, let dy):
            mouseController.scroll(deltaX: dx, deltaY: dy)
        case .openURL(let urlString):
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        case .performCommand(let command):
            handleCommand(command)
        case .hello(let deviceId):
            handleHello(deviceId)
        case .pairResponse(let code):
            handlePairResponse(code)
        case .updateSettings(let newSensitivity, let newCursorSize):
            suppressSettingsSync = true
            sensitivity = newSensitivity
            cursorSize = newCursorSize
            suppressSettingsSync = false
        case .updateActions(let newActions):
            actionStore.actions = newActions
            try? actionStore.save()
            server.send(.actionConfig(actions: actionStore.actions))
        }
    }

    private func handleHello(_ deviceId: String) {
        if pairingStore.isDevicePaired(deviceId) {
            // Known device — send config immediately
            let hostname = ProcessInfo.processInfo.hostName
            server.send(.serverStatus(connected: true, hostname: hostname))
            server.send(.actionConfig(actions: actionStore.actions))
            pushSettings()
        } else {
            // Unknown device — require pairing
            let code = pairingStore.generateCode(for: deviceId)
            print("Pairing code: \(code)")
            server.send(.pairRequired)
            showPairingPanel(code: code)
        }
    }

    private func handlePairResponse(_ code: String) {
        if pairingStore.validateCode(code) {
            dismissPairingPanel()
            server.send(.pairAccepted)
            let hostname = ProcessInfo.processInfo.hostName
            server.send(.serverStatus(connected: true, hostname: hostname))
            server.send(.actionConfig(actions: actionStore.actions))
            pushSettings()
        } else {
            server.send(.pairRejected(reason: "Invalid code"))
        }
    }

    private func showPairingPanel(code: String) {
        dismissPairingPanel()
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 220),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Pairing Code"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.contentView = NSHostingView(rootView: PairingCodeView(code: code))
        panel.center()
        panel.orderFrontRegardless()
        pairingPanel = panel
    }

    private func dismissPairingPanel() {
        pairingPanel?.close()
        pairingPanel = nil
    }

    private func handleCommand(_ command: String) {
        switch command {
        case "fullscreen":
            // Ctrl+Cmd+F — standard macOS fullscreen toggle
            mouseController.sendKeyPress(keyCode: 3, flags: [.maskCommand, .maskControl])
        case "escape":
            mouseController.sendKeyPress(keyCode: 53, flags: [])
        case "volumeUp":
            mouseController.sendMediaKey(0)
        case "volumeDown":
            mouseController.sendMediaKey(1)
        case "arrowLeft":
            mouseController.sendKeyPress(keyCode: 123, flags: [])
        case "arrowRight":
            mouseController.sendKeyPress(keyCode: 124, flags: [])
        case "closeTab":
            mouseController.sendKeyPress(keyCode: 13, flags: [.maskCommand])
        default:
            print("Unknown command: \(command)")
        }
    }
}
