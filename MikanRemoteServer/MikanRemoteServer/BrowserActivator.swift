import AppKit
import ApplicationServices

/// Brings the browser in use to the front, for the iPhone's browser button
/// (`activateBrowser`, since 1.4.0). Every keystroke command lands in the
/// frontmost app, so this is the way back when something else has come
/// forward (2026-11-22: the Watch Later URL was typed into Claude).
///
/// Which browser: the one that was frontmost most recently, tracked from
/// NSWorkspace's activation notifications since the server started (and
/// seeded from whatever is frontmost at launch); failing that the default
/// browser for https; failing that Safari. If it isn't running it's launched.
///
/// Which window: a window of that browser in macOS fullscreen is raised
/// first. An HTML5 video in fullscreen is such a window, on its own Space,
/// so the video comes back rather than the browser's main window; raising
/// through the Accessibility API switches Spaces (the server already holds
/// that permission for CGEvent). With no fullscreen window the app is
/// activated with all its windows, which brings its key window's Space
/// forward. Untested assumption (2026-11-22): Safari reports the video's
/// fullscreen window with AXFullScreen = true like any fullscreen window;
/// if it doesn't, the plain activation still runs.
final class BrowserActivator {
    static let browserBundleIDs: Set<String> = [
        "com.apple.Safari", "com.apple.SafariTechnologyPreview",
        "com.google.Chrome", "com.google.Chrome.canary",
        "org.mozilla.firefox", "company.thebrowser.Browser",
        "com.brave.Browser", "com.microsoft.edgemac",
        "com.kagi.kagimacOS", "com.vivaldi.Vivaldi",
    ]

    private(set) var lastActiveBrowserBundleID: String?
    private var observer: NSObjectProtocol?

    init() {
        if let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           Self.browserBundleIDs.contains(front) {
            lastActiveBrowserBundleID = front
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier, Self.browserBundleIDs.contains(id) else { return }
            self?.lastActiveBrowserBundleID = id
        }
    }

    deinit {
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    /// The bundle id to bring forward: last active running browser, else the
    /// default https handler, else Safari.
    func chosenBundleID() -> String {
        if let id = lastActiveBrowserBundleID,
           !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty {
            return id
        }
        if let url = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!),
           let id = Bundle(url: url)?.bundleIdentifier {
            return id
        }
        return "com.apple.Safari"
    }

    func activate() {
        let id = chosenBundleID()
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first else {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: url, configuration: config)
            }
            return
        }
        if let window = fullscreenWindow(of: app) {
            app.activate(options: [])
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        } else {
            app.activate(options: [.activateAllWindows])
        }
    }

    /// The app's first window whose AXFullScreen is true, or nil.
    private func fullscreenWindow(of app: NSRunningApplication) -> AXUIElement? {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AnyObject] else { return nil }
        for candidate in windows where CFGetTypeID(candidate) == AXUIElementGetTypeID() {
            let window = candidate as! AXUIElement
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value) == .success,
               let flag = value as? Bool, flag {
                return window
            }
        }
        return nil
    }
}
