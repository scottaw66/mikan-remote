import Foundation

public enum ClientMessage: Codable, Sendable {
    case mouseMove(deltaX: Float, deltaY: Float)
    case mouseClick
    case mouseScroll(deltaX: Float, deltaY: Float)
    case openURL(url: String)
    case performCommand(command: String)
    case hello(deviceId: String)
    case pairResponse(code: String)
    case updateSettings(sensitivity: Double, cursorSize: Double, cursorDotSize: Double, cursorGapSize: Double, youtubePopupMode: String)
    case updateActions(actions: [Action])

    enum CodingKeys: String, CodingKey {
        case type, deltaX, deltaY, url, command, deviceId, code, sensitivity, cursorSize, cursorDotSize, cursorGapSize, actions, youtubePopupMode
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
            self = .mouseClick
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
        case "hello":
            let deviceId = try container.decode(String.self, forKey: .deviceId)
            self = .hello(deviceId: deviceId)
        case "pairResponse":
            let code = try container.decode(String.self, forKey: .code)
            self = .pairResponse(code: code)
        case "updateSettings":
            let sensitivity = try container.decode(Double.self, forKey: .sensitivity)
            let cursorSize = try container.decode(Double.self, forKey: .cursorSize)
            let cursorDotSize = try container.decode(Double.self, forKey: .cursorDotSize)
            let cursorGapSize = try container.decode(Double.self, forKey: .cursorGapSize)
            let youtubePopupMode = try container.decodeIfPresent(String.self, forKey: .youtubePopupMode) ?? "auto"
            self = .updateSettings(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize, youtubePopupMode: youtubePopupMode)
        case "updateActions":
            let actions = try container.decode([Action].self, forKey: .actions)
            self = .updateActions(actions: actions)
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
        case .mouseClick:
            try container.encode("mouseClick", forKey: .type)
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
        case .hello(let deviceId):
            try container.encode("hello", forKey: .type)
            try container.encode(deviceId, forKey: .deviceId)
        case .pairResponse(let code):
            try container.encode("pairResponse", forKey: .type)
            try container.encode(code, forKey: .code)
        case .updateSettings(let sensitivity, let cursorSize, let cursorDotSize, let cursorGapSize, let youtubePopupMode):
            try container.encode("updateSettings", forKey: .type)
            try container.encode(sensitivity, forKey: .sensitivity)
            try container.encode(cursorSize, forKey: .cursorSize)
            try container.encode(cursorDotSize, forKey: .cursorDotSize)
            try container.encode(cursorGapSize, forKey: .cursorGapSize)
            try container.encode(youtubePopupMode, forKey: .youtubePopupMode)
        case .updateActions(let actions):
            try container.encode("updateActions", forKey: .type)
            try container.encode(actions, forKey: .actions)
        }
    }
}

public enum ServerMessage: Codable, Sendable {
    case actionConfig(actions: [Action])
    case serverStatus(connected: Bool, hostname: String)
    case pairRequired
    case pairAccepted
    case pairRejected(reason: String)
    case settingsSync(sensitivity: Double, cursorSize: Double, cursorDotSize: Double, cursorGapSize: Double, youtubePopupMode: String)

    enum CodingKeys: String, CodingKey {
        case type, actions, connected, hostname, reason, sensitivity, cursorSize, cursorDotSize, cursorGapSize, youtubePopupMode
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
        case "pairRequired":
            self = .pairRequired
        case "pairAccepted":
            self = .pairAccepted
        case "pairRejected":
            let reason = try container.decode(String.self, forKey: .reason)
            self = .pairRejected(reason: reason)
        case "settingsSync":
            let sensitivity = try container.decode(Double.self, forKey: .sensitivity)
            let cursorSize = try container.decode(Double.self, forKey: .cursorSize)
            let cursorDotSize = try container.decode(Double.self, forKey: .cursorDotSize)
            let cursorGapSize = try container.decode(Double.self, forKey: .cursorGapSize)
            let youtubePopupMode = try container.decodeIfPresent(String.self, forKey: .youtubePopupMode) ?? "auto"
            self = .settingsSync(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize, youtubePopupMode: youtubePopupMode)
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
        case .pairRequired:
            try container.encode("pairRequired", forKey: .type)
        case .pairAccepted:
            try container.encode("pairAccepted", forKey: .type)
        case .pairRejected(let reason):
            try container.encode("pairRejected", forKey: .type)
            try container.encode(reason, forKey: .reason)
        case .settingsSync(let sensitivity, let cursorSize, let cursorDotSize, let cursorGapSize, let youtubePopupMode):
            try container.encode("settingsSync", forKey: .type)
            try container.encode(sensitivity, forKey: .sensitivity)
            try container.encode(cursorSize, forKey: .cursorSize)
            try container.encode(cursorDotSize, forKey: .cursorDotSize)
            try container.encode(cursorGapSize, forKey: .cursorGapSize)
            try container.encode(youtubePopupMode, forKey: .youtubePopupMode)
        }
    }
}
