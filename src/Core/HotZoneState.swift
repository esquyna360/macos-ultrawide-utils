import Cocoa
import Foundation

/// Tracks cursor position globally and publishes whether the cursor currently sits in
/// one of the screen-edge hot zones the floating UI cares about.
public class HotZoneState: ObservableObject {
    public static let shared = HotZoneState()

    @Published public var isInTopCenter: Bool = false
    @Published public var isInBottomLeft: Bool = false
    @Published public var isInBottomRight: Bool = false

    /// Window frames the hot zones should anchor to, in screen coordinates.
    @Published public var topCenterFrame: NSRect = .zero
    @Published public var bottomLeftFrame: NSRect = .zero
    @Published public var bottomRightFrame: NSRect = .zero

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pollTimer: Timer?

    // Cooldown after firing the top-center MC trigger so we don't fire repeatedly while
    // the cursor lingers in the zone post-trigger.
    private var topCenterCooldownUntil: Date = .distantPast

    private let topZoneHeight: CGFloat = 6
    private let topZoneXFraction: ClosedRange<CGFloat> = 0.30...0.70
    private let cornerZoneWidth: CGFloat = 240
    private let cornerZoneHeight: CGFloat = 70

    private init() {}

    public func start() {
        stop()
        recomputeFrames()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.update()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.update()
            return event
        }
        // Belt-and-suspenders polling so the state stays accurate if the cursor moves
        // outside any monitor window (e.g. via private API or another app's overlay).
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            self?.update()
        }

        update()
        print("SpaceFlow: HotZoneState monitoring started.")
    }

    public func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Call after the cursor triggers a top-center action so the chip doesn't immediately
    /// re-fire while the cursor lingers there during the post-trigger transition.
    public func markTopCenterTriggered(cooldown: TimeInterval = 1.2) {
        topCenterCooldownUntil = Date().addingTimeInterval(cooldown)
        DispatchQueue.main.async {
            if self.isInTopCenter { self.isInTopCenter = false }
        }
    }

    public func recomputeFrames() {
        guard let screen = NSScreen.screens.first else { return }
        let f = screen.frame
        let topW: CGFloat = 360
        let topH: CGFloat = 56
        let topX = f.minX + (f.width - topW) / 2
        let topY = f.maxY - topH

        let cornerW = cornerZoneWidth
        let cornerH = cornerZoneHeight + 20
        let blX = f.minX
        let blY = f.minY
        let brX = f.maxX - cornerW
        let brY = f.minY

        DispatchQueue.main.async {
            self.topCenterFrame = NSRect(x: topX, y: topY, width: topW, height: topH)
            self.bottomLeftFrame = NSRect(x: blX, y: blY, width: cornerW, height: cornerH)
            self.bottomRightFrame = NSRect(x: brX, y: brY, width: cornerW, height: cornerH)
        }
    }

    private func update() {
        guard let screen = NSScreen.screens.first else { return }
        let f = screen.frame
        let mouse = NSEvent.mouseLocation
        let now = Date()

        let inTopX = mouse.x >= f.minX + f.width * topZoneXFraction.lowerBound &&
                     mouse.x <= f.minX + f.width * topZoneXFraction.upperBound
        let inTopY = mouse.y >= f.maxY - topZoneHeight
        let inTop = inTopX && inTopY && now >= topCenterCooldownUntil

        let inLeft = mouse.x <= f.minX + cornerZoneWidth && mouse.y <= f.minY + cornerZoneHeight
        let inRight = mouse.x >= f.maxX - cornerZoneWidth && mouse.y <= f.minY + cornerZoneHeight

        DispatchQueue.main.async {
            if self.isInTopCenter != inTop { self.isInTopCenter = inTop }
            if self.isInBottomLeft != inLeft { self.isInBottomLeft = inLeft }
            if self.isInBottomRight != inRight { self.isInBottomRight = inRight }
            HotZoneWindowManager.shared.setZoneMouseHandling(top: inTop, left: inLeft, right: inRight)
        }

        updateFloatingBarHit(mouse: mouse)
    }

    /// Toggles FloatingBarWindow.ignoresMouseEvents based on whether the cursor is over the
    /// visible capsule, so clicks pass through to apps below the rest of the window's frame.
    /// Also drives FloatingBarState.isHovered (the bar's own .onHover doesn't fire while the
    /// window is ignoring mouse events).
    private func updateFloatingBarHit(mouse: NSPoint) {
        guard let barWindow = FloatingBarWindow.shared else { return }

        let engine = SpaceEngine.shared
        let bar = FloatingBarState.shared
        let isExpanded = engine.isTemporarilyExpanded || bar.isHovered
        let count = CGFloat(max(engine.totalSpacesCount, 1))

        let capsuleW: CGFloat = isExpanded
            ? max(count * 36 + 30 * 3 + 80, 220)
            : max(count * 18 + 40, 90)
        let capsuleH: CGFloat = isExpanded ? 56 : 40

        let f = barWindow.frame
        let capsuleRect = NSRect(
            x: f.midX - capsuleW / 2,
            y: f.midY - capsuleH / 2,
            width: capsuleW,
            height: capsuleH
        )
        let isOver = capsuleRect.contains(mouse)
        let shouldIgnore = !isOver

        DispatchQueue.main.async {
            if barWindow.ignoresMouseEvents != shouldIgnore {
                barWindow.ignoresMouseEvents = shouldIgnore
            }
            if bar.isHovered != isOver {
                bar.isHovered = isOver
            }
        }
    }
}
