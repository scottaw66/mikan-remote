// MikanRemote/MikanRemote/ConnectionManager.swift
import Foundation
import Network
import MikanProtocol

@Observable
final class ConnectionManager {
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var reconnectTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?

    private(set) var discoveredServers: [NWBrowser.Result] = []
    private(set) var isConnected = false
    private(set) var hostname: String?
    private(set) var actions: [Action] = []

    var onServerMessage: ((ServerMessage) -> Void)?

    func startBrowsing() {
        guard browser == nil else { return }
        let params = NWParameters()
        params.includePeerToPeer = true
        browser = NWBrowser(for: .bonjour(type: "_mikan._tcp", domain: nil), using: params)

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.discoveredServers = Array(results)
                // Auto-connect if exactly one server found and not already connected
                if results.count == 1, self?.isConnected == false, self?.connection == nil {
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
        reconnectTask?.cancel()
        reconnectTask = nil
        connection?.cancel()
        connection = nil

        let params = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        let conn = NWConnection(to: result.endpoint, using: params)
        connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard self?.connection === conn else { return }
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.startHeartbeat()
                    self?.receiveMessage()
                case .waiting:
                    // Connection is waiting (e.g. network issue) — treat as disconnected
                    self?.handleDisconnect()
                case .cancelled, .failed:
                    self?.handleDisconnect()
                default:
                    break
                }
            }
        }

        conn.start(queue: .main)
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
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
        connection.send(content: data, contentContext: context, completion: .contentProcessed({ _ in }))
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, let connection, isConnected else { break }
                // Send a WebSocket ping to detect dead connections
                let pong = NWProtocolWebSocket.Metadata(opcode: .pong)
                let context = NWConnection.ContentContext(identifier: "ping", metadata: [pong])
                connection.send(content: nil, contentContext: context, completion: .contentProcessed({ [weak self] error in
                    if error != nil {
                        Task { @MainActor in
                            self?.connection?.cancel()
                        }
                    }
                }))
            }
        }
    }

    private func handleDisconnect() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        isConnected = false
        hostname = nil
        actions = []
        connection = nil
        // Let the browser find the server again rather than reconnecting to a stale endpoint
        // The browseResultsChangedHandler will auto-connect when the server reappears
    }

    private func receiveMessage() {
        connection?.receiveMessage { [weak self] content, context, _, error in
            if let data = content,
               let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata {
                if metadata.opcode == .text,
                   let message = try? JSONDecoder().decode(ServerMessage.self, from: data) {
                    Task { @MainActor in
                        self?.handleServerMessage(message)
                    }
                }
                if metadata.opcode == .close {
                    self?.connection?.cancel()
                    return
                }
            }
            if error == nil {
                self?.receiveMessage()
            }
        }
    }

    private func handleServerMessage(_ message: ServerMessage) {
        switch message {
        case .actionConfig(actions: let newActions):
            actions = newActions
        case .serverStatus(connected: _, hostname: let name):
            hostname = name
        }
        onServerMessage?(message)
    }
}
