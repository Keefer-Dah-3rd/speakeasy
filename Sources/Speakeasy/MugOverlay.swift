import AppKit
import SwiftUI

/// A see-through window that shows the dancing mug beside the mouse pointer,
/// with a speech bubble of the words you are saying. It never takes focus and
/// never intercepts clicks, so the app you are dictating into stays active.
@MainActor
final class MugOverlay {
    static let mugSide: CGFloat = 150
    /// Room beside the mug for the speech bubble.
    static let bubbleZone: CGFloat = 290
    static var width: CGFloat { mugSide + bubbleZone }

    private let panel: NSPanel
    private let model = MugModel()
    private let caption = CaptionModel()
    private var timer: Timer?
    private var origin: CGPoint = .zero
    private var hideWork: DispatchWorkItem?

    init() {
        let frame = NSRect(x: 0, y: 0, width: Self.width, height: Self.mugSide)
        panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let mugModel = model
        let host = NSHostingView(
            rootView: OverlayView(caption: caption) {
                MugLiveView(model: mugModel)
            })
        host.frame = frame
        panel.contentView = host
    }

    func show() {
        hideWork?.cancel()
        hideWork = nil

        model.restart()
        caption.reset()

        let place = placement()
        caption.bubbleOnLeft = place.bubbleOnLeft
        origin = place.origin
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()

        timer?.invalidate()
        let tick = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(tick, forMode: .common)
        timer = tick
    }

    func setLevel(_ level: Double) {
        model.targetLevel = level
    }

    /// The words heard so far. `settled` ones are final; `tentative` may change.
    func setWords(settled: String, tentative: String) {
        guard panel.isVisible, hideWork == nil else { return }
        caption.update(settled: settled, tentative: tentative)
    }

    /// Switch from dancing to "bottoms up" while the last words are processed.
    func showProcessing() {
        model.targetLevel = 0
        model.setPhase(.processing)
    }

    func hide() {
        guard panel.isVisible, hideWork == nil else { return }
        model.setPhase(.leaving)
        caption.dismiss()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.timer?.invalidate()
            self.timer = nil
            self.model.stop()
            self.caption.reset()
            self.panel.orderOut(nil)
            self.hideWork = nil
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
    }

    private func tick() {
        model.easeLevel()

        let target = placement()
        if target.bubbleOnLeft != caption.bubbleOnLeft {
            // The mug moves to the other end of the window. Shift the window by
            // the same amount at once, so the mug itself doesn't jump.
            origin.x += target.bubbleOnLeft ? -Self.bubbleZone : Self.bubbleZone
            caption.bubbleOnLeft = target.bubbleOnLeft
        }

        // Trail the pointer with a little lag so the mug feels alive.
        origin.x += (target.origin.x - origin.x) * 0.28
        origin.y += (target.origin.y - origin.y) * 0.28
        panel.setFrameOrigin(origin)
    }

    /// The mug sits just below and to the right of the pointer, and the bubble
    /// to the right of the mug. Near a screen edge each flips to the other side
    /// so nothing is cut off.
    private func placement() -> (origin: CGPoint, bubbleOnLeft: Bool) {
        let mouse = NSEvent.mouseLocation
        let side = Self.mugSide
        var mugX = mouse.x - 6
        var y = mouse.y - side + 2
        var bubbleOnLeft = false

        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let frame = screen?.frame {
            if mugX + side > frame.maxX { mugX = mouse.x - side + 6 }
            if y < frame.minY { y = mouse.y + 10 }
            mugX = min(max(mugX, frame.minX), frame.maxX - side)
            y = min(max(y, frame.minY), frame.maxY - side)

            // A little stickiness stops the bubble flickering between sides
            // when the pointer hovers right at the switching point.
            let slack: CGFloat = caption.bubbleOnLeft ? 28 : 0
            bubbleOnLeft = mugX + Self.width + slack > frame.maxX
        }

        let x = bubbleOnLeft ? mugX - Self.bubbleZone : mugX
        return (CGPoint(x: x, y: y), bubbleOnLeft)
    }
}
