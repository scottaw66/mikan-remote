import AppKit
import ApplicationServices

enum AccessibilityPermission {
    static var isGranted: Bool { AXIsProcessTrusted() }

    static func requestIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings to the Accessibility pane and reveals the app
    /// in Finder so the user can drag it into the list — the most reliable
    /// way to add the app when macOS doesn't auto-populate it.
    static func openSettingsAndReveal() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        let appURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        NSWorkspace.shared.activateFileViewerSelecting([appURL])
    }
}
