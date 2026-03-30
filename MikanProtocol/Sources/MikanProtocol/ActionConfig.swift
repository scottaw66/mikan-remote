import Foundation

public struct Action: Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let url: String
    public let icon: String?

    public init(id: String, label: String, url: String, icon: String? = nil) {
        self.id = id
        self.label = label
        self.url = url
        self.icon = icon
    }

    public static let defaults: [Action] = [
        Action(id: "netflix", label: "Netflix", url: "https://netflix.com", icon: "play.tv"),
        Action(id: "youtube", label: "YouTube", url: "https://youtube.com", icon: "play.rectangle"),
    ]
}

extension Action: Identifiable {}
