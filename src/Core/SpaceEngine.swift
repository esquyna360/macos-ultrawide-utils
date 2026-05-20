import Cocoa
import Foundation
import CoreGraphics

public class SpaceEngine: ObservableObject {
    @Published public var currentSpaceIndex: Int = 1
    @Published public var totalSpacesCount: Int = 1
    @Published public var spaceIDs: [UInt64] = []

    @Published public var isAccessibilityTrusted: Bool = AXIsProcessTrusted()

    // Gesture-enable settings, persisted via UserDefaults
    @Published public var isHUDScrollEnabled: Bool = UserDefaults.standard.object(forKey: "isHUDScrollEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(isHUDScrollEnabled, forKey: "isHUDScrollEnabled") }
    }
    @Published public var isEdgeScrollEnabled: Bool = UserDefaults.standard.object(forKey: "isEdgeScrollEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(isEdgeScrollEnabled, forKey: "isEdgeScrollEnabled") }
    }
    @Published public var isModifierScrollEnabled: Bool = UserDefaults.standard.object(forKey: "isModifierScrollEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(isModifierScrollEnabled, forKey: "isModifierScrollEnabled") }
    }
    @Published public var isRightClickScrollEnabled: Bool = UserDefaults.standard.object(forKey: "isRightClickScrollEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(isRightClickScrollEnabled, forKey: "isRightClickScrollEnabled") }
    }
    @Published public var isShakeSwitchEnabled: Bool = UserDefaults.standard.object(forKey: "isShakeSwitchEnabled") as? Bool ?? false {
        didSet { UserDefaults.standard.set(isShakeSwitchEnabled, forKey: "isShakeSwitchEnabled") }
    }
    @Published public var isDoubleTapWarpEnabled: Bool = UserDefaults.standard.object(forKey: "isDoubleTapWarpEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(isDoubleTapWarpEnabled, forKey: "isDoubleTapWarpEnabled") }
    }
    @Published public var isDoubleMiddleClickMCEnabled: Bool = UserDefaults.standard.object(forKey: "isDoubleMiddleClickMCEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(isDoubleMiddleClickMCEnabled, forKey: "isDoubleMiddleClickMCEnabled") }
    }
    @Published public var switchCooldown: Double = {
        let stored = UserDefaults.standard.double(forKey: "switchCooldown")
        return stored == 0 ? 0.18 : stored
    }() {
        didSet { UserDefaults.standard.set(switchCooldown, forKey: "switchCooldown") }
    }

    // Auto-expansion state so the HUD can flash open after a space switch
    @Published public var isTemporarilyExpanded: Bool = false
    private var temporaryExpansionTimer: Timer?

    // Track presumed MC state so toggleMissionControl can pick the right key (Ctrl+Up vs Escape).
    // Resets on space change (selecting a space closes MC) and on a 60s timeout.
    @Published public var isMissionControlPresumedOpen: Bool = false
    private var mcResetTimer: Timer?

    public static let shared = SpaceEngine()

    private var connection: Int32 {
        return _CGSDefaultConnection()
    }

    private var permissionTimer: Timer?

    private init() {
        updateSpacesInfo()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSpaceChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            let trusted = AXIsProcessTrusted()
            if self?.isAccessibilityTrusted != trusted {
                self?.isAccessibilityTrusted = trusted
                print("SpaceFlow: Accessibility trust status changed to \(trusted).")
                if trusted {
                    GestureMonitor.shared.startMonitoring()
                }
            }
        }
    }

    @objc private func handleSpaceChange() {
        DispatchQueue.main.async {
            self.updateSpacesInfo()
            self.triggerTemporaryExpansion()
            // Selecting a space inside Mission Control closes it
            if self.isMissionControlPresumedOpen {
                self.isMissionControlPresumedOpen = false
                self.mcResetTimer?.invalidate()
            }
        }
    }

    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    public func triggerTemporaryExpansion() {
        DispatchQueue.main.async {
            self.isTemporarilyExpanded = true
            self.temporaryExpansionTimer?.invalidate()
            self.temporaryExpansionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isTemporarilyExpanded = false
                }
            }
        }
    }

    public func updateSpacesInfo() {
        guard let spacesInfo = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else {
            print("SpaceFlow: Failed to query spaces info from CoreGraphics private API.")
            return
        }
        guard let primaryDisplay = spacesInfo.first else {
            print("SpaceFlow: No display dictionary found in spaces info.")
            return
        }
        guard let spacesArray = primaryDisplay["Spaces"] as? [[String: Any]],
              let currentSpaceDict = primaryDisplay["Current Space"] as? [String: Any] else {
            print("SpaceFlow: Failed to extract spaces list or current active space.")
            return
        }

        let activeSpaceID = currentSpaceDict["ManagedSpaceID"] as? UInt64 ?? 0
        var ids: [UInt64] = []
        var activeIndex = 1
        for (index, spaceDict) in spacesArray.enumerated() {
            if let spaceID = spaceDict["ManagedSpaceID"] as? UInt64 {
                ids.append(spaceID)
                if spaceID == activeSpaceID {
                    activeIndex = index + 1
                }
            }
        }

        self.spaceIDs = ids
        self.totalSpacesCount = ids.count
        self.currentSpaceIndex = activeIndex

        print("SpaceFlow: Updated spaces state. Active Space Index: \(self.currentSpaceIndex) of \(self.totalSpacesCount). Space IDs: \(self.spaceIDs)")
    }

    public func switchToSpace(index targetIndex: Int) {
        guard targetIndex >= 1 && targetIndex <= totalSpacesCount else { return }
        let currentIndex = currentSpaceIndex
        if targetIndex == currentIndex { return }

        // Optimistic UI update + auto-expand to confirm the action visually
        self.currentSpaceIndex = targetIndex
        self.triggerTemporaryExpansion()

        let steps = targetIndex - currentIndex
        let keyCode: CGKeyCode = steps > 0 ? 124 : 123 // 124 = Right Arrow, 123 = Left Arrow
        let absoluteSteps = abs(steps)

        print("SpaceFlow: Switching space relatively from \(currentIndex) to \(targetIndex) (\(absoluteSteps) steps).")

        DispatchQueue.global(qos: .userInteractive).async {
            for _ in 0..<absoluteSteps {
                DispatchQueue.main.async {
                    self.simulateControlArrow(keyCode: keyCode)
                }
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
    }

    /// Simulates pressing Control + Left/Right Arrow by running osascript as a subprocess.
    /// This bypasses parent-app Automation TCC permission checks (error -1743).
    private func simulateControlArrow(keyCode: CGKeyCode) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "tell application \"System Events\" to key code \(keyCode) using control down"]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("SpaceFlow: Failed to execute osascript subprocess: \(error)")
        }
    }

    /// Toggles Mission Control. Open uses Ctrl+Up; close uses Escape because
    /// on most macOS setups Ctrl+Up does not actually toggle MC off.
    public func toggleMissionControl() {
        if isMissionControlPresumedOpen {
            print("SpaceFlow: Closing Mission Control (Escape).")
            sendKey(virtualKey: 53, withControl: false) // Escape
            isMissionControlPresumedOpen = false
            mcResetTimer?.invalidate()
        } else {
            print("SpaceFlow: Opening Mission Control (Ctrl+Up).")
            sendKey(virtualKey: 126, withControl: true) // Up Arrow + Control
            isMissionControlPresumedOpen = true
            mcResetTimer?.invalidate()
            mcResetTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isMissionControlPresumedOpen = false
                }
            }
        }
    }

    private func sendKey(virtualKey: Int, withControl: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        let modifier = withControl ? " using control down" : ""
        process.arguments = ["-e", "tell application \"System Events\" to key code \(virtualKey)\(modifier)"]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("SpaceFlow: Failed to send key \(virtualKey): \(error)")
        }
    }
}

// MARK: - CoreGraphics Services (CGS) Private APIs

@_silgen_name("_CGSDefaultConnection")
func _CGSDefaultConnection() -> Int32

@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray?
