import Cocoa
import Foundation
import CoreGraphics

public class GestureMonitor: ObservableObject {
    public static let shared = GestureMonitor()

    private var scrollGlobalMonitor: Any?
    private var scrollLocalMonitor: Any?
    private var flagsMonitor: Any?
    private var mouseMoveMonitor: Any?
    private var otherMouseDownMonitor: Any?

    private var lastSwitchTime: Date = Date.distantPast

    // Mouse shake state
    private var lastMouseLoc: NSPoint = NSEvent.mouseLocation
    private var lastSign: Int = 0
    private var shakeFlips: [Date] = []

    // Double-Option warp state
    private var lastOptionPressTime: Date = Date.distantPast

    // Double middle-click state
    private var lastMiddleClickTime: Date = Date.distantPast

    private init() {}

    public func startMonitoring() {
        stopMonitoring()

        scrollGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.handleScrollEvent(event)
        }
        scrollLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.handleScrollEvent(event)
            return event
        }
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.handleMouseMove(event)
        }
        otherMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.otherMouseDown]) { [weak self] event in
            self?.handleOtherMouseDown(event)
        }

        print("SpaceFlow: Gesture monitor running with full gesture set.")
    }

    public func stopMonitoring() {
        for monitor in [scrollGlobalMonitor, scrollLocalMonitor, flagsMonitor, mouseMoveMonitor, otherMouseDownMonitor] {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
        scrollGlobalMonitor = nil
        scrollLocalMonitor = nil
        flagsMonitor = nil
        mouseMoveMonitor = nil
        otherMouseDownMonitor = nil
        print("SpaceFlow: Gesture monitor paused.")
    }

    // MARK: - Scroll gestures

    private func handleScrollEvent(_ event: NSEvent) {
        let engine = SpaceEngine.shared
        let now = Date()
        guard now.timeIntervalSince(lastSwitchTime) >= engine.switchCooldown else { return }

        let deltaY = event.deltaY
        let deltaX = event.deltaX
        let threshold: CGFloat = 0.25
        let isScrollLeft = deltaY > threshold || deltaX > threshold
        let isScrollRight = deltaY < -threshold || deltaX < -threshold
        guard isScrollLeft || isScrollRight else { return }

        // 1. Right-Click + Scroll (chording)
        if engine.isRightClickScrollEnabled {
            let isRightMouseDown = (NSEvent.pressedMouseButtons & (1 << 1)) != 0
            if isRightMouseDown {
                print("SpaceFlow: Right-Click + Scroll chording detected.")
                triggerSwitch(isLeft: isScrollLeft)
                return
            }
        }

        // 2. Direct HUD Scroll (over the floating bar window)
        if engine.isHUDScrollEnabled,
           let hud = FloatingBarWindow.shared,
           hud.isVisible,
           NSPointInRect(NSEvent.mouseLocation, hud.frame) {
            print("SpaceFlow: Direct HUD scroll detected.")
            triggerSwitch(isLeft: isScrollLeft)
            return
        }

        // 3. Modifier (Option) + Scroll, anywhere
        if engine.isModifierScrollEnabled && event.modifierFlags.contains(.option) {
            print("SpaceFlow: Option+Scroll detected.")
            triggerSwitch(isLeft: isScrollLeft)
            return
        }

        // 4. Gravity Edge Scroll (top menu bar OR bottom dock strip)
        if engine.isEdgeScrollEnabled,
           let primary = NSScreen.screens.first {
            let mouseLoc = NSEvent.mouseLocation
            let screenHeight = primary.frame.height
            let isAtTop = mouseLoc.y >= (screenHeight - 24.0)
            let isAtBottom = mouseLoc.y <= 24.0
            if isAtTop || isAtBottom {
                print("SpaceFlow: Gravity edge scroll detected (top=\(isAtTop), bottom=\(isAtBottom)).")
                triggerSwitch(isLeft: isScrollLeft)
                return
            }
        }
    }

    // MARK: - Velocity shake gesture

    private func handleMouseMove(_ event: NSEvent) {
        let engine = SpaceEngine.shared
        guard engine.isShakeSwitchEnabled else { return }

        let currentLoc = NSEvent.mouseLocation
        let deltaX = currentLoc.x - lastMouseLoc.x
        lastMouseLoc = currentLoc

        guard abs(deltaX) > 12 else { return }
        let currentSign = deltaX > 0 ? 1 : -1
        guard lastSign != 0 && currentSign != lastSign else {
            lastSign = currentSign
            return
        }

        let now = Date()
        shakeFlips.append(now)
        shakeFlips = shakeFlips.filter { now.timeIntervalSince($0) < 0.4 }

        if shakeFlips.count >= 4 {
            if now.timeIntervalSince(lastSwitchTime) >= engine.switchCooldown {
                print("SpaceFlow: Mouse shake detected, alternating spaces.")
                let prev = engine.currentSpaceIndex - 1
                if prev >= 1 {
                    engine.switchToSpace(index: prev)
                } else if engine.currentSpaceIndex + 1 <= engine.totalSpacesCount {
                    engine.switchToSpace(index: engine.currentSpaceIndex + 1)
                }
                lastSwitchTime = now
                shakeFlips.removeAll()
            }
        }
        lastSign = currentSign
    }

    // MARK: - Double-Option warp cursor to HUD

    private func handleFlagsChanged(_ event: NSEvent) {
        let engine = SpaceEngine.shared
        guard engine.isDoubleTapWarpEnabled else { return }
        guard event.modifierFlags.contains(.option) else { return }

        let now = Date()
        if now.timeIntervalSince(lastOptionPressTime) < 0.35 {
            teleportCursorToHUD()
            lastOptionPressTime = Date.distantPast
        } else {
            lastOptionPressTime = now
        }
    }

    private func teleportCursorToHUD() {
        guard let hud = FloatingBarWindow.shared,
              let primary = NSScreen.screens.first else { return }
        let frame = hud.frame
        let target = CGPoint(x: frame.midX, y: primary.frame.height - frame.midY)
        let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                           mouseCursorPosition: target, mouseButton: .left)
        move?.post(tap: .cghidEventTap)
        print("SpaceFlow: Cursor warped to HUD center.")
    }

    // MARK: - Double middle-click → Mission Control

    private func handleOtherMouseDown(_ event: NSEvent) {
        let engine = SpaceEngine.shared
        guard engine.isDoubleMiddleClickMCEnabled else { return }
        guard event.buttonNumber == 2 else { return } // middle / scroll-wheel button

        let now = Date()
        if now.timeIntervalSince(lastMiddleClickTime) < 0.35 {
            print("SpaceFlow: Double middle-click detected, toggling Mission Control.")
            engine.toggleMissionControl()
            lastMiddleClickTime = Date.distantPast
        } else {
            lastMiddleClickTime = now
        }
    }

    // MARK: - Helpers

    private func triggerSwitch(isLeft: Bool) {
        lastSwitchTime = Date()
        let engine = SpaceEngine.shared
        let target = isLeft ? engine.currentSpaceIndex - 1 : engine.currentSpaceIndex + 1
        if target >= 1 && target <= engine.totalSpacesCount {
            print("SpaceFlow: Gesture triggered space switch to \(target).")
            engine.switchToSpace(index: target)
        }
    }
}
