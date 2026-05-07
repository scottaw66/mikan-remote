import Foundation
import MikanProtocol

enum YouTubeVisibility {

    /// Returns true if the YouTube launcher button should be visible
    /// given the current 3-state mode and action button list.
    ///
    /// - mode "on": always visible
    /// - mode "off": always hidden
    /// - mode "auto" (or any unknown value): visible iff any action's URL
    ///   contains "youtube.com" or "youtu.be" (case-insensitive).
    static func effectiveYouTubeButtonVisible(mode: String, actions: [Action]) -> Bool {
        switch mode {
        case "on":
            return true
        case "off":
            return false
        default:
            return actions.contains { action in
                let url = action.url.lowercased()
                return url.contains("youtube.com") || url.contains("youtu.be")
            }
        }
    }
}
