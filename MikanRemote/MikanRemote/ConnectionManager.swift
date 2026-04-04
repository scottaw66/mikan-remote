// MikanRemote/MikanRemote/ConnectionManager.swift
import Foundation
import Network
import MikanProtocol

@Observable
@MainActor
final class ConnectionManager {
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var heartbeatTimer: Timer?

    private(set) var discoveredServers: [NWBrowser.Result] = []
    private(set) var isConnected = false
    private(set) var hostname: String?
    private(set) var actions: [Action] = []
    private(set) var pairingRequired = false
    private(set) var pairingFailed = false

    private static let networkQueue = DispatchQueue(label: "mikan.network")

    private var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: "mikan.deviceId") {
            return id
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "mikan.deviceId")
        return id
    }

    func startBrowsing() {
        guard browser == nil else { return }
        let params = NWParameters()
        params.includePeerToPeer = true
        browser = NWBrowser(for: .bonjour(type: "_mikan._tcp", domain: nil), using: params)

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.discoveredServers = Array(results)
                if results.count == 1, self?.isConnected == false, self?.connection == nil {
                    self?.connect(to: results.first!)
                }
            }
        }

        browser?.start(queue: Self.networkQueue)
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    func connect(to result: NWBrowser.Result) {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        connection?.cancel()
        connection = nil

        let params = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        let conn = NWConnection(to: result.endpoint, using: params)
        connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard self?.connection === conn else { return }
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.startHeartbeat()
                    self?.receiveMessage()
                    self?.send(.hello(deviceId: self?.deviceId ?? ""))
                case .waiting, .cancelled, .failed:
                    self?.handleDisconnect()
                default:
                    break
                }
            }
        }

        conn.start(queue: Self.networkQueue)
    }

    func disconnect() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        connection?.cancel()
        connection = nil
        isConnected = false
        hostname = nil
        actions = []
        pairingRequired = false
        pairingFailed = false
    }

    func submitPairingCode(_ code: String) {
        pairingFailed = false
        send(.pairResponse(code: code))
    }

    func send(_ message: ClientMessage) {
        guard let connection, isConnected else { return }
        guard let data = try? JSONEncoder().encode(message) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        connection.send(content: data, contentContext: context, completion: .contentProcessed({ _ in }))
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self, let connection = self.connection, self.isConnected else { return }
            let pong = NWProtocolWebSocket.Metadata(opcode: .pong)
            let context = NWConnection.ContentContext(identifier: "ping", metadata: [pong])
            connection.send(content: nil, contentContext: context, completion: .contentProcessed({ error in
                if error != nil {
                    DispatchQueue.main.async {
                        self.connection?.cancel()
                    }
                }
            }))
        }
    }

    func attemptReconnect() {
        guard !isConnected else { return }
        connection?.cancel()
        connection = nil
        if let server = discoveredServers.first, discoveredServers.count == 1 {
            connect(to: server)
        } else {
            stopBrowsing()
            startBrowsing()
        }
    }

    private func handleDisconnect() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        isConnected = false
        hostname = nil
        actions = []
        pairingRequired = false
        pairingFailed = false
        connection = nil
    }

    private func receiveMessage() {
        connection?.receiveMessage { [weak self] content, context, _, error in
            DispatchQueue.main.async {
                if let data = content,
                   let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata {
                    if metadata.opcode == .text,
                       let message = try? JSONDecoder().decode(ServerMessage.self, from: data) {
                        self?.handleServerMessage(message)
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
    }

    private func handleServerMessage(_ message: ServerMessage) {
        switch message {
        case .actionConfig(actions: let newActions):
            actions = newActions
        case .serverStatus(connected: _, hostname: let name):
            hostname = name
        case .pairRequired:
            pairingRequired = true
            pairingFailed = false
        case .pairAccepted:
            pairingRequired = false
            pairingFailed = false
        case .pairRejected:
            pairingFailed = true
        }
    }
}
