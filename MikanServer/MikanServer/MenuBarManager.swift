import AppKit
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
