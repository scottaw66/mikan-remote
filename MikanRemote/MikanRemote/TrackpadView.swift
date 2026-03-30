// MikanRemote/MikanRemote/TrackpadView.swift
import SwiftUI
import UIKit

struct TrackpadView: UIViewRepresentable {
    var onMove: (Float, Float) -> Void
    var onTap: () -> Void
    var onTwoFingerTap: () -> Void
    var onScroll: (Float, Float) -> Void

    func makeUIView(context: Context) -> TrackpadUIView {
        let view = TrackpadUIView()
        view.onMove = onMove
        view.onTap = onTap
        view.onTwoFingerTap = onTwoFingerTap
        view.onScroll = onScroll
        view.isMultipleTouchEnabled = true
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 16
        return view
    }

    func updateUIView(_ uiView: TrackpadUIView, context: Context) {
        uiView.onMove = onMove
        uiView.onTap = onTap
        uiView.onTwoFingerTap = onTwoFingerTap
        uiView.onScroll = onScroll
    }
}

final class TrackpadUIView: UIView {
    var onMove: ((Float, Float) -> Void)?
    var onTap: (() -> Void)?
    var onTwoFingerTap: (() -> Void)?
    var onScroll: ((Float, Float) -> Void)?

    private var previousTouchLocation: CGPoint?
    private var previousScrollCenter: CGPoint?
    private var touchStartTime: Date?
    private var touchStartLocation: CGPoint?
    private var isTwoFingerDrag = false
    private let tapThreshold: TimeInterval = 0.25
    private let tapDistanceThreshold: CGFloat = 10

    private var feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let allTouches = event?.allTouches ?? touches
        if allTouches.count == 1, let touch = touches.first {
            previousTouchLocation = touch.location(in: self)
            touchStartTime = Date()
            touchStartLocation = previousTouchLocation
            isTwoFingerDrag = false
        } else if allTouches.count == 2 {
            isTwoFingerDrag = true
            previousScrollCenter = centerOfTouches(allTouches)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let allTouches = event?.allTouches ?? touches

        if allTouches.count == 2 && isTwoFingerDrag {
            let center = centerOfTouches(allTouches)
            if let prev = previousScrollCenter {
                let dx = Float(center.x - prev.x)
                let dy = Float(center.y - prev.y)
                onScroll?(dx, dy)
            }
            previousScrollCenter = center
        } else if allTouches.count == 1, let touch = allTouches.first {
            let location = touch.location(in: self)
            if let prev = previousTouchLocation {
                let dx = Float(location.x - prev.x)
                let dy = Float(location.y - prev.y)
                onMove?(dx, dy)
            }
            previousTouchLocation = location
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let allTouches = event?.allTouches ?? touches
        let remaining = allTouches.filter { $0.phase != .ended && $0.phase != .cancelled }

        if remaining.isEmpty {
            if let startTime = touchStartTime, let startLoc = touchStartLocation {
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed < tapThreshold {
                    if let touch = touches.first {
                        let endLoc = touch.location(in: self)
                        let dist = hypot(endLoc.x - startLoc.x, endLoc.y - startLoc.y)
                        if dist < tapDistanceThreshold {
                            if allTouches.count >= 2 || isTwoFingerDrag {
                                feedbackGenerator.impactOccurred()
                                onTwoFingerTap?()
                            } else {
                                feedbackGenerator.impactOccurred()
                                onTap?()
                            }
                        }
                    }
                }
            }
            previousTouchLocation = nil
            previousScrollCenter = nil
            touchStartTime = nil
            touchStartLocation = nil
            isTwoFingerDrag = false
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        previousTouchLocation = nil
        previousScrollCenter = nil
        touchStartTime = nil
        touchStartLocation = nil
        isTwoFingerDrag = false
    }

    private func centerOfTouches(_ touches: Set<UITouch>) -> CGPoint {
        var x: CGFloat = 0
        var y: CGFloat = 0
        for touch in touches {
            let loc = touch.location(in: self)
            x += loc.x
            y += loc.y
        }
        let count = CGFloat(touches.count)
        return CGPoint(x: x / count, y: y / count)
    }
}
