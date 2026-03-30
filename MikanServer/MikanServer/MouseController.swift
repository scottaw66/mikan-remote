import CoreGraphics
import MikanProtocol

final class MouseController {

    func move(deltaX: Float, deltaY: Float, sensitivity: Double) {
        let current = CGEvent(source: nil)?.location ?? .zero
        let newX = current.x + CGFloat(Double(deltaX) * sensitivity)
        let newY = current.y + CGFloat(Double(deltaY) * sensitivity)
        let point = CGPoint(x: newX, y: newY)
        CGWarpMouseCursorPosition(point)
        // Re-associate mouse to prevent cursor freeze after warp
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    func click(button: MouseButton) {
        let current = CGEvent(source: nil)?.location ?? .zero
        let (down, up): (CGEventType, CGEventType) = button == .left
            ? (.leftMouseDown, .leftMouseUp)
            : (.rightMouseDown, .rightMouseUp)
        let cgButton: CGMouseButton = button == .left ? .left : .right
        CGEvent(mouseEventSource: nil, mouseType: down, mouseCursorPosition: current, mouseButton: cgButton)?.post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: nil, mouseType: up, mouseCursorPosition: current, mouseButton: cgButton)?.post(tap: .cghidEventTap)
    }

    func scroll(deltaX: Float, deltaY: Float) {
        if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(deltaY), wheel2: Int32(deltaX), wheel3: 0) {
            event.post(tap: .cghidEventTap)
        }
    }

    func sendKeyPress(keyCode: UInt16, flags: CGEventFlags) {
        if let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
            down.flags = flags
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
            up.flags = flags
            up.post(tap: .cghidEventTap)
        }
    }
}
