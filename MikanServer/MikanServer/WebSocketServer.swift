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
