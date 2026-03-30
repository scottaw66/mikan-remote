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
    case performCommand(command: String)

    enum CodingKeys: String, CodingKey {
        case type, deltaX, deltaY, button, url, command
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
        case "performCommand":
            let command = try container.decode(String.self, forKey: .command)
            self = .performCommand(command: command)
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
        case .performCommand(let command):
            try container.encode("performCommand", forKey: .type)
            try container.encode(command, forKey: .command)
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
