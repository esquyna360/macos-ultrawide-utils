import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var permissionWindow: NSWindow?
    private var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("SpaceFlow: applicationDidFinishLaunching called. Starting app directly.")
        // 1. Setup Status Item in the system menu bar
        setupStatusItem()
        
        // 2. Launch the core processes immediately!
        startApp()
        
        // 3. Listen to space changes to synchronize status item indicator
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(syncStatusItem),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }
    
    private func startApp() {
        print("SpaceFlow: Launching core processes.")

        // Start gesture monitors
        GestureMonitor.shared.startMonitoring()

        // Start hot-zone cursor tracking
        HotZoneState.shared.start()

        // Instantiate and overlay the glassmorphic HUD bar + hot-zone overlays
        DispatchQueue.main.async {
            FloatingBarWindow.shared = FloatingBarWindow()
            FloatingBarWindow.shared?.orderFrontRegardless()
            HotZoneWindowManager.shared.start()
            self.syncStatusItem()
        }
    }
    
    private func showPermissionWizard() {
        let width: CGFloat = 380
        let height: CGFloat = 420
        
        let screenFrame = NSScreen.screens.first?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = (screenFrame.width - width) / 2
        let y = (screenFrame.height - height) / 2
        
        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "SpaceFlow Setup"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        
        let permissionView = PermissionView(onGranted: { [weak self] in
            guard let self = self else { return }
            print("SpaceFlow: Setup complete. Transitioning to active state.")
            self.permissionWindow?.close()
            self.permissionWindow = nil
            self.startApp()
        })
        
        window.contentView = NSHostingView(rootView: permissionView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        self.permissionWindow = window
        
        // Bring permission wizard to absolute front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "⎋ 1"
            button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        }
        
        buildMenu()
    }
    
    @objc private func syncStatusItem() {
        DispatchQueue.main.async {
            if let button = self.statusItem?.button {
                let active = SpaceEngine.shared.currentSpaceIndex
                button.title = "⎋ \(active)"
            }
            self.buildMenu() // Rebuild menu to sync checkboxes states
        }
    }
    
    private func buildMenu() {
        let menu = NSMenu()
        let engine = SpaceEngine.shared

        let header = NSMenuItem(title: "SpaceFlow 🖥️", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        menu.addItem(NSMenuItem.separator())

        // Open Mission Control
        menu.addItem(NSMenuItem(
            title: "Abrir Mission Control",
            action: #selector(openMissionControl),
            keyEquivalent: ""
        ))

        // Open Settings
        menu.addItem(NSMenuItem(
            title: "Ajustes…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))

        menu.addItem(NSMenuItem.separator())

        // Gesture toggles (mirror SettingsView state)
        let gestureToggles: [(String, ReferenceWritableKeyPath<SpaceEngine, Bool>, Selector)] = [
            ("Direct HUD Scroll", \.isHUDScrollEnabled, #selector(toggleHUDScroll)),
            ("Gravity Edge Scroll", \.isEdgeScrollEnabled, #selector(toggleEdgeScroll)),
            ("Option + Scroll", \.isModifierScrollEnabled, #selector(toggleModifierScroll)),
            ("Right-Click + Scroll", \.isRightClickScrollEnabled, #selector(toggleRightClickScroll)),
            ("Velocity Shake", \.isShakeSwitchEnabled, #selector(toggleShake)),
            ("Double-Option Warp", \.isDoubleTapWarpEnabled, #selector(toggleDoubleOption)),
            ("Double Middle-Click → MC", \.isDoubleMiddleClickMCEnabled, #selector(toggleDoubleMiddle)),
        ]
        for (title, keyPath, selector) in gestureToggles {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.state = engine[keyPath: keyPath] ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Recarregar Diagnósticos de Spaces",
            action: #selector(reindexSpaces),
            keyEquivalent: "r"
        ))
        menu.addItem(NSMenuItem(
            title: "Mostrar/Ocultar Barra Flutuante",
            action: #selector(toggleHUD),
            keyEquivalent: "h"
        ))
        menu.addItem(NSMenuItem(
            title: "Recentralizar Barra Flutuante",
            action: #selector(resetBarPosition),
            keyEquivalent: ""
        ))

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Sair do SpaceFlow", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func openMissionControl() { SpaceEngine.shared.toggleMissionControl() }
    @objc private func openSettings() { SettingsWindow.show() }
    @objc private func toggleHUDScroll() { SpaceEngine.shared.isHUDScrollEnabled.toggle(); syncStatusItem() }
    @objc private func toggleEdgeScroll() { SpaceEngine.shared.isEdgeScrollEnabled.toggle(); syncStatusItem() }
    @objc private func toggleModifierScroll() { SpaceEngine.shared.isModifierScrollEnabled.toggle(); syncStatusItem() }
    @objc private func toggleRightClickScroll() { SpaceEngine.shared.isRightClickScrollEnabled.toggle(); syncStatusItem() }
    @objc private func toggleShake() { SpaceEngine.shared.isShakeSwitchEnabled.toggle(); syncStatusItem() }
    @objc private func toggleDoubleOption() { SpaceEngine.shared.isDoubleTapWarpEnabled.toggle(); syncStatusItem() }
    @objc private func toggleDoubleMiddle() { SpaceEngine.shared.isDoubleMiddleClickMCEnabled.toggle(); syncStatusItem() }
    
    @objc private func reindexSpaces() {
        SpaceEngine.shared.updateSpacesInfo()
        syncStatusItem()
    }
    
    @objc private func toggleHUD() {
        guard let hud = FloatingBarWindow.shared else { return }
        if hud.isVisible {
            hud.orderOut(nil)
        } else {
            hud.orderFrontRegardless()
        }
    }

    @objc private func resetBarPosition() {
        FloatingBarWindow.resetPosition()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// Bootstrapping — write debug.log next to the .app bundle so the path follows the
// project folder if it ever gets renamed.
let logURL = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("debug.log")
let logPath = logURL.path
freopen(logPath, "w", stdout)
freopen(logPath, "w", stderr)
setbuf(stdout, nil)
setbuf(stderr, nil)

print("SpaceFlow: Logging started successfully.")

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
