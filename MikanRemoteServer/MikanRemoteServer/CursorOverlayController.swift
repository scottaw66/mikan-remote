import AppKit

final class CursorOverlayController {
    private var window: NSPanel?
    private var cursorView: CursorView?
    private var hideTimer: Timer?
    private let hideDelay: TimeInterval = 10.0
    private var cursorSize: CGFloat = 140
    private var dotSizePercent: CGFloat = 5
    private var gapSizePercent: CGFloat = 33

    func updateSize(_ size: CGFloat) {
        cursorSize = size
        // Tear down existing window so it rebuilds at new size
        window?.orderOut(nil)
        window = nil
        cursorView = nil
    }

    func updateStyle(dotSize: CGFloat, gapSize: CGFloat) {
        dotSizePercent = dotSize
        gapSizePercent = gapSize
        window?.orderOut(nil)
        window = nil
        cursorView = nil
    }

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
        view.dotSizePercent = dotSizePercent
        view.gapSizePercent = gapSizePercent
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
    var dotSizePercent: CGFloat = 5
    var gapSizePercent: CGFloat = 33

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let outerRadius = min(bounds.width, bounds.height) / 2 - 2
        let gapRadius = outerRadius * (gapSizePercent * 2 / 100)
        let dotRadius = outerRadius * (dotSizePercent / 100)

        let red = NSColor(red: 0.9, green: 0.25, blue: 0.15, alpha: 1.0).cgColor
        ctx.setFillColor(red)

        // Outer ring
        ctx.addArc(center: center, radius: outerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.addArc(center: center, radius: gapRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.fillPath(using: .evenOdd)

        // Center dot
        ctx.addArc(center: center, radius: dotRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.fillPath()
    }
}
