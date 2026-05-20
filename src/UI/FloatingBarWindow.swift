import Cocoa
import SwiftUI

public class FloatingBarWindow: NSWindow {

    public static var shared: FloatingBarWindow?

    private static let frameDefaultsKey = "FloatingBarFrame"
    private var frameSaveDebouncer: Timer?

    public init() {
        let width: CGFloat = 600
        let height: CGFloat = 80

        let initialFrame = Self.computeInitialFrame(width: width, height: height)
        print("SpaceFlow: FloatingBarWindow init. Frame = \(initialFrame).")

        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false

        // Float above fullscreen apps, ride along on every space.
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Mouse handling starts in "pass-through" mode — HotZoneState flips this when the
        // cursor enters the visible capsule rect, so apps under the rest of our 600×80
        // bounding box remain clickable.
        self.ignoresMouseEvents = true
        self.acceptsMouseMovedEvents = true

        // Lets the user grab the capsule background and drag the bar anywhere; SwiftUI
        // buttons consume their own clicks so they still work normally.
        self.isMovableByWindowBackground = true

        let hostingView = NSHostingView(rootView: FloatingBarView())
        hostingView.frame = NSRect(origin: .zero, size: initialFrame.size)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = hostingView

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidMove),
            name: NSWindow.didMoveNotification,
            object: self
        )
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    @objc private func handleDidMove() {
        // Debounce so we don't spam UserDefaults during every drag pixel.
        frameSaveDebouncer?.invalidate()
        frameSaveDebouncer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            UserDefaults.standard.set(NSStringFromRect(self.frame), forKey: Self.frameDefaultsKey)
            print("SpaceFlow: FloatingBar position persisted at \(self.frame).")
        }
    }

    /// Resets the bar back to bottom-center of the active screen. Useful when the saved
    /// position falls off-screen (resolution change, monitor unplugged, etc).
    public static func resetPosition() {
        UserDefaults.standard.removeObject(forKey: frameDefaultsKey)
        guard let window = shared else { return }
        window.setFrame(computeInitialFrame(width: window.frame.width, height: window.frame.height), display: true, animate: true)
    }

    private static func computeInitialFrame(width: CGFloat, height: CGFloat) -> NSRect {
        // Try to restore the user's saved position first.
        if let saved = UserDefaults.standard.string(forKey: frameDefaultsKey) {
            let rect = NSRectFromString(saved)
            if isFrameValid(rect) { return rect }
        }
        // Fall back to bottom-center of the active screen.
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = visibleFrame.minX + (visibleFrame.width - width) / 2
        let y = visibleFrame.minY + 12
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private static func isFrameValid(_ frame: NSRect) -> Bool {
        guard frame.width > 100, frame.height > 20 else { return false }
        let union = NSScreen.screens.reduce(NSRect.zero) { $0.union($1.frame) }
        return union.intersects(frame)
    }
}
