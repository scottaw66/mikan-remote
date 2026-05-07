import AppKit
import SwiftUI
import MikanProtocol

@Observable
final class MenuBarManager {
    let server = WebSocketServer()
    let actionStore = ActionStore()
    let pairingStore = PairingStore()
    var sensitivity: Double {
        didSet {
            UserDefaults.standard.set(sensitivity, forKey: "sensitivity")
            pushSettings()
        }
    }
    var cursorSize: Double {
        didSet {
            UserDefaults.standard.set(cursorSize, forKey: "cursorSize")
            cursorOverlay.updateSize(CGFloat(cursorSize))
            pushSettings()
        }
    }
    var cursorDotSize: Double {
        didSet {
            UserDefaults.standard.set(cursorDotSize, forKey: "cursorDotSize")
            cursorOverlay.updateStyle(dotSize: CGFloat(cursorDotSize), gapSize: CGFloat(cursorGapSize))
            pushSettings()
        }
    }
    var cursorGapSize: Double {
        didSet {
            UserDefaults.standard.set(cursorGapSize, forKey: "cursorGapSize")
            cursorOverlay.updateStyle(dotSize: CGFloat(cursorDotSize), gapSize: CGFloat(cursorGapSize))
            pushSettings()
        }
    }
    var youtubePopupMode: String {
        didSet {
            UserDefaults.standard.set(youtubePopupMode, forKey: "youtubePopupMode")
            pushSettings()
        }
    }
    var isAccessibilityGranted: Bool = AccessibilityPermission.isGranted
    var launchAtLogin: Bool = LaunchAtLogin.isEnabled {
        didSet {
            LaunchAtLogin.setEnabled(launchAtLogin)
        }
    }
    private var suppressSettingsSync = false
    private let mouseController = MouseController()
    private let cursorOverlay = CursorOverlayController()
    private var pairingPanel: NSPanel?
    private var accessibilityTimer: Timer?

    init() {
        AccessibilityPermission.requestIfNeeded()
        let stored = UserDefaults.standard.double(forKey: "sensitivity")
        self.sensitivity = stored > 0 ? stored : 10.0
        let storedSize = UserDefaults.standard.double(forKey: "cursorSize")
        self.cursorSize = storedSize > 0 ? storedSize : 140.0
        let storedDotSize = UserDefaults.standard.double(forKey: "cursorDotSize")
        self.cursorDotSize = storedDotSize > 0 ? storedDotSize : 5.0
        let storedGapSize = UserDefaults.standard.double(forKey: "cursorGapSize")
        self.cursorGapSize = storedGapSize > 0 ? storedGapSize : 33.0
        self.youtubePopupMode = UserDefaults.standard.string(forKey: "youtubePopupMode") ?? "auto"
        cursorOverlay.updateSize(CGFloat(self.cursorSize))
        cursorOverlay.updateStyle(dotSize: CGFloat(self.cursorDotSize), gapSize: CGFloat(self.cursorGapSize))
        server.onClientMessage = { [weak self] message in
            self?.handleMessage(message)
        }
        server.onConnectionChanged = { [weak self] connected, _ in
            guard let self else { return }
            if !connected {
                pairingStore.clearPending()
                dismissPairingPanel()
            }
        }
        try? server.start()
        startAccessibilityMonitoring()
    }

    private func startAccessibilityMonitoring() {
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let granted = AccessibilityPermission.isGranted
            if granted != self.isAccessibilityGranted {
                self.isAccessibilityGranted = granted
            }
        }
    }

    func openAccessibilitySettings() {
        AccessibilityPermission.openSettingsAndReveal()
    }

    var statusText: String {
        if server.isClientConnected {
            return "Connected: \(server.clientName ?? "iPhone")"
        }
        return "Waiting for connection..."
    }

    var isConnected: Bool { server.isClientConnected }

    func pushActions() {
        server.send(.actionConfig(actions: actionStore.actions))
    }

    func pushSettings() {
        guard !suppressSettingsSync else { return }
        server.send(.settingsSync(sensitivity: sensitivity, cursorSize: cursorSize, cursorDotSize: cursorDotSize, cursorGapSize: cursorGapSize, youtubePopupMode: youtubePopupMode))
    }

    private func handleMessage(_ message: ClientMessage) {
        switch message {
        case .mouseMove(let dx, let dy):
            mouseController.move(deltaX: dx, deltaY: dy, sensitivity: sensitivity)
            if let pos = CGEvent(source: nil)?.location {
                cursorOverlay.showCursor(at: pos)
            }
        case .mouseClick:
            mouseController.click()
        case .mouseScroll(let dx, let dy):
            mouseController.scroll(deltaX: dx, deltaY: dy)
        case .openURL(let urlString):
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        case .performCommand(let command):
            handleCommand(command)
        case .hello(let deviceId):
            handleHello(deviceId)
        case .pairResponse(let code):
            handlePairResponse(code)
        case .updateSettings(let newSensitivity, let newCursorSize, let newCursorDotSize, let newCursorGapSize, let newYouTubePopupMode):
            suppressSettingsSync = true
            sensitivity = newSensitivity
            cursorSize = newCursorSize
            cursorDotSize = newCursorDotSize
            cursorGapSize = newCursorGapSize
            youtubePopupMode = newYouTubePopupMode
            suppressSettingsSync = false
        case .updateActions(let newActions):
            actionStore.actions = newActions
            try? actionStore.save()
            server.send(.actionConfig(actions: actionStore.actions))
        }
    }

    private func handleHello(_ deviceId: String) {
        if pairingStore.isDevicePaired(deviceId) {
            // Known device — send config immediately
            let hostname = ProcessInfo.processInfo.hostName
            server.send(.serverStatus(connected: true, hostname: hostname))
            server.send(.actionConfig(actions: actionStore.actions))
            pushSettings()
        } else {
            // Unknown device — require pairing
            let code = pairingStore.generateCode(for: deviceId)
            print("Pairing code: \(code)")
            server.send(.pairRequired)
            showPairingPanel(code: code)
        }
    }

    private func handlePairResponse(_ code: String) {
        if pairingStore.validateCode(code) {
            dismissPairingPanel()
            server.send(.pairAccepted)
            let hostname = ProcessInfo.processInfo.hostName
            server.send(.serverStatus(connected: true, hostname: hostname))
            server.send(.actionConfig(actions: actionStore.actions))
            pushSettings()
        } else {
            server.send(.pairRejected(reason: "Invalid code"))
        }
    }

    private func showPairingPanel(code: String) {
        dismissPairingPanel()
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 220),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Pairing Code"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.contentView = NSHostingView(rootView: PairingCodeView(code: code))
        panel.center()
        panel.orderFrontRegardless()
        pairingPanel = panel
    }

    private func dismissPairingPanel() {
        pairingPanel?.close()
        pairingPanel = nil
    }

    private func handleCommand(_ command: String) {
        switch command {
        case "fullscreen":
            // Ctrl+Cmd+F — standard macOS fullscreen toggle
            mouseController.sendKeyPress(keyCode: 3, flags: [.maskCommand, .maskControl])
        case "escape":
            mouseController.sendKeyPress(keyCode: 53, flags: [])
        case "volumeUp":
            mouseController.sendMediaKey(0)
        case "volumeDown":
            mouseController.sendMediaKey(1)
        case "arrowLeft":
            mouseController.sendKeyPress(keyCode: 123, flags: [])
        case "arrowRight":
            mouseController.sendKeyPress(keyCode: 124, flags: [])
        case "closeTab":
            mouseController.sendKeyPress(keyCode: 13, flags: [.maskCommand])
        case "prevTab":
            mouseController.sendKeyPress(keyCode: 33, flags: [.maskCommand, .maskShift])
        case "nextTab":
            mouseController.sendKeyPress(keyCode: 30, flags: [.maskCommand, .maskShift])
        case "playPause":
            mouseController.sendMediaKey(16)
        case "ytPrevVideo":
            mouseController.sendYouTubePrevVideo()
        case "ytNextVideo":
            mouseController.sendYouTubeNextVideo()
        case "ytPrevChapter":
            mouseController.sendYouTubePrevChapter()
        case "ytNextChapter":
            mouseController.sendYouTubeNextChapter()
        case "ytToggleCaptions":
            mouseController.sendYouTubeToggleCaptions()
        case "ytSlowDown":
            mouseController.sendYouTubeSlowDown()
        case "ytSpeedUp":
            mouseController.sendYouTubeSpeedUp()
        case "ytFullscreen":
            mouseController.sendYouTubeFullscreen()
        default:
            print("Unknown command: \(command)")
        }
    }
}
