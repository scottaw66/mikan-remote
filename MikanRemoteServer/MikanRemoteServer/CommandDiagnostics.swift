import AppKit
import ApplicationServices
import os

/// Logs each remote `performCommand` together with where the Mac's keyboard
/// focus is aimed at that moment (frontmost app, focused window title, focused
/// UI element role). The yt* commands are bare keystrokes posted to whatever
/// has focus, so when they "stop working" this is the record of where they
/// actually landed. View in Console.app or:
///   log stream --predicate 'category == "commands"' --level default
enum CommandDiagnostics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MikanRemoteServer",
        category: "commands"
    )

    static func logCommand(_ command: String) {
        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName ?? "unknown"
        let focus = focusInfo(for: app)
        logger.log("performCommand '\(command, privacy: .public)' → frontmost: \(appName, privacy: .public), window: \"\(focus.windowTitle, privacy: .public)\", focused: \(focus.elementRole, privacy: .public)")
    }

    /// Reads the app's focused window title and focused UI element role (+subrole)
    /// via the Accessibility API — uses the same permission the app already
    /// holds for CGEvent posting. Returns "unknown" fields rather than failing.
    private static func focusInfo(for app: NSRunningApplication?) -> (windowTitle: String, elementRole: String) {
        guard let app else { return ("unknown", "unknown") }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowTitle = "unknown"
        var windowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
           let windowRef, CFGetTypeID(windowRef) == AXUIElementGetTypeID() {
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(windowRef as! AXUIElement, kAXTitleAttribute as CFString, &titleRef) == .success,
               let title = titleRef as? String {
                windowTitle = title
            }
        }

        var elementRole = "unknown"
        var focusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
           let focusedRef, CFGetTypeID(focusedRef) == AXUIElementGetTypeID() {
            let element = focusedRef as! AXUIElement
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
               let role = roleRef as? String {
                elementRole = role
            }
            var subroleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef) == .success,
               let subrole = subroleRef as? String {
                elementRole += "/\(subrole)"
            }
        }
        return (windowTitle, elementRole)
    }
}
