import CoreGraphics
import MikanProtocol

final class MouseController {

    func move(deltaX: Float, deltaY: Float, sensitivity: Double) {
        let current = CGEvent(source: nil)?.location ?? .zero
        let newX = current.x + CGFloat(Double(deltaX) * sensitivity)
        let newY = current.y + CGFloat(Double(deltaY) * sensitivity)
        let point = CGPoint(x: newX, y: newY)
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
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
}
