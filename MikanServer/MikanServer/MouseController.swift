import AppKit
import CoreGraphics

final class MouseController {

    func move(deltaX: Float, deltaY: Float, sensitivity: Double) {
        let current = CGEvent(source: nil)?.location ?? .zero
        let newX = current.x + CGFloat(Double(deltaX) * sensitivity)
        let newY = current.y + CGFloat(Double(deltaY) * sensitivity)
        let point = CGPoint(x: newX, y: newY)
        CGWarpMouseCursorPosition(point)
        CGAssociateMouseAndMouseCursorPosition(1)
        // Post a mouseMoved event so apps (video players) detect cursor activity
        if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
            moveEvent.post(tap: .cghidEventTap)
        }
    }

    func click() {
        let current = CGEvent(source: nil)?.location ?? .zero
        if let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: current, mouseButton: .left) {
            down.flags = []  // Clear modifiers so Control never turns this into a right-click
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: current, mouseButton: .left) {
            up.flags = []
            up.post(tap: .cghidEventTap)
        }
    }

    func scroll(deltaX: Float, deltaY: Float) {
        if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(deltaY), wheel2: Int32(deltaX), wheel3: 0) {
            event.post(tap: .cghidEventTap)
        }
    }

    func sendMediaKey(_ keyType: Int32) {
        // NX_KEYTYPE_SOUND_UP = 0, NX_KEYTYPE_SOUND_DOWN = 1, NX_KEYTYPE_MUTE = 7
        func postSystemKey(_ down: Bool) {
            let flags = down ? 0xa00 : 0xb00
            let data1 = Int((Int(keyType) << 16) | flags)
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
        postSystemKey(true)
        postSystemKey(false)
    }

    func sendKeyPress(keyCode: UInt16, flags: CGEventFlags) {
        if let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
            down.flags = flags
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
            up.flags = []  // Clear modifiers on release so they don't leak into subsequent events
            up.post(tap: .cghidEventTap)
        }
    }

    // MARK: - YouTube web-player shortcuts

    // Virtual key codes (HIToolbox / Carbon):
    //   F=3, C=8, P=35, N=45, Comma=43, Period=47, Left=123, Right=124

    func sendYouTubePrevVideo() {
        // Shift+P — previous video in playlist
        sendKeyPress(keyCode: 35, flags: [.maskShift])
    }

    func sendYouTubeNextVideo() {
        // Shift+N — next video in playlist
        sendKeyPress(keyCode: 45, flags: [.maskShift])
    }

    func sendYouTubePrevChapter() {
        // Option+Left — previous chapter
        sendKeyPress(keyCode: 123, flags: [.maskAlternate])
    }

    func sendYouTubeNextChapter() {
        // Option+Right — next chapter
        sendKeyPress(keyCode: 124, flags: [.maskAlternate])
    }

    func sendYouTubeToggleCaptions() {
        // c — toggle captions
        sendKeyPress(keyCode: 8, flags: [])
    }

    func sendYouTubeSlowDown() {
        // Shift+, produces "<" — slow down playback rate
        sendKeyPress(keyCode: 43, flags: [.maskShift])
    }

    func sendYouTubeSpeedUp() {
        // Shift+. produces ">" — speed up playback rate
        sendKeyPress(keyCode: 47, flags: [.maskShift])
    }

    func sendYouTubeFullscreen() {
        // f — toggle YouTube player fullscreen (separate from macOS Ctrl+Cmd+F)
        sendKeyPress(keyCode: 3, flags: [])
    }

    func sendYouTubePlayPause() {
        // k — toggle play/pause in the YouTube web player (keyCode 40)
        sendKeyPress(keyCode: 40, flags: [])
    }
}
