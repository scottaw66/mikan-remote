import AppKit
import MikanProtocol

@Observable
final class MenuBarManager {
    let server = WebSocketServer()
    let actionStore = ActionStore()
    var sensitivity: Double {
        didSet { UserDefaults.standard.set(sensitivity, forKey: "sensitivity") }
    }
    private let mouseController = MouseController()

    init() {
        let stored = UserDefaults.standard.double(forKey: "sensitivity")
        self.sensitivity = stored > 0 ? stored : 10.0
        server.onClientMessage = { [weak self] message in
            self?.handleMessage(message)
        }
        server.onConnectionChanged = { [weak self] connected, _ in
            guard let self, connected else { return }
            let hostname = ProcessInfo.processInfo.hostName
            server.send(.serverStatus(connected: true, hostname: hostname))
            server.send(.actionConfig(actions: actionStore.actions))
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
        }
    }

    private func handleCommand(_ command: String) {
        switch command {
        case "fullscreen":
            // Ctrl+Cmd+F — standard macOS fullscreen toggle
            mouseController.sendKeyPress(keyCode: 3, flags: [.maskCommand, .maskControl])
        case "escape":
            mouseController.sendKeyPress(keyCode: 53, flags: [])
        default:
            print("Unknown command: \(command)")
        }
    }
}
