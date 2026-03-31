import AppKit

final class CursorOverlayController {
    private var window: NSPanel?
    private var cursorView: CursorView?
    private var hideTimer: Timer?
    private let hideDelay: TimeInterval = 10.0
    private let cursorSize: CGFloat = 120

    func showCursor(at point: CGPoint) {
        if window == nil {
            setupWindow()
        }
        guard let window else { return }

        // Convert from CGEvent coordinates (top-left origin) to screen coordinates (bottom-left origin)
        let screenFrame = NSScreen.main?.frame ?? .zero
        let screenPoint = CGPoint(
            x: point.x - cursorSize / 2,
            y: screenFrame.height - point.y - cursorSize / 2
        )
        window.setFrameOrigin(screenPoint)

        if !window.isVisible {
            window.orderFrontRegardless()
            cursorView?.alphaValue = 1.0
        }

        resetHideTimer()
    }

    func hideCursor() {
        hideTimer?.invalidate()
        hideTimer = nil
        guard let cursorView else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            cursorView.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        })
    }

    private func setupWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: cursorSize, height: cursorSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = CursorView(frame: NSRect(x: 0, y: 0, width: cursorSize, height: cursorSize))
        panel.contentView = view

        self.window = panel
        self.cursorView = view
    }

    private func resetHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: hideDelay, repeats: false) { [weak self] _ in
            self?.hideCursor()
        }
    }
}

private final class CursorView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        // Outer ring — bright orange, thick
        let outerRadius: CGFloat = 45
        ctx.setStrokeColor(NSColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 0.9).cgColor)
        ctx.setLineWidth(5.0)
        ctx.addArc(center: center, radius: outerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()

        // Center dot
        let dotRadius: CGFloat = 8
        ctx.setFillColor(NSColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 0.95).cgColor)
        ctx.addArc(center: center, radius: dotRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.fillPath()

        // White outline on outer ring for contrast on dark backgrounds
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(1.5)
        ctx.addArc(center: center, radius: outerRadius + 4, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()
    }
}
