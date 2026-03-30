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
        case .actionConfig(actions: let newActions):
            actions = newActions
        case .serverStatus(connected: _, hostname: let name):
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
