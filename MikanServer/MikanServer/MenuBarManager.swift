import AppKit
import MikanProtocol

@Observable
final class MenuBarManager {
    let server = WebSocketServer()
    let actionStore = ActionStore()
    let pairingStore = PairingStore()
    var onShowPairingWindow: (() -> Void)?
    var sensitivity: Double {
        didSet { UserDefaults.standard.set(sensitivity, forKey: "sensitivity") }
    }
    private let mouseController = MouseController()
    private let cursorOverlay = CursorOverlayController()

    init() {
        let stored = UserDefaults.standard.double(forKey: "sensitivity")
        self.sensitivity = stored > 0 ? stored : 10.0
        server.onClientMessage = { [weak self] message in
            self?.handleMessage(message)
        }
        server.onConnectionChanged = { [weak self] connected, _ in
            guard let self else { return }
            if !connected {
                pairingStore.clearPending()
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

    private func handleMessage(_ message: ClientMessage) {
        switch message {
        case .mouseMove(let dx, let dy):
            mouseController.move(deltaX: dx, deltaY: dy, sensitivity: sensitivity)
            if let pos = CGEvent(source: nil)?.location {
                cursorOverlay.showCursor(at: pos)
            }
        case .mouseClick(let button):
            mouseController.click(button: button)
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
        }
    }

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
        default:
            print("Unknown command: \(command)")
        }
    }
}
