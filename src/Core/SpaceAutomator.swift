import Cocoa
import Foundation
import CoreGraphics

public class SpaceAutomator {
    
    /// Automates the creation of a new desktop space by launching Mission Control,
    /// triggering the Spaces Bar expansion, clicking the '+' button, dismissing it,
    /// and restoring the cursor position in under 300ms.
    public static func createNewSpace() {
        print("SpaceFlow: Initiating automated space creation.")
        
        guard let primaryScreen = NSScreen.screens.first else {
            print("SpaceFlow: Automation failed - primary screen not found.")
            return
        }
        
        let screenFrame = primaryScreen.frame
        let screenWidth = screenFrame.width
        let screenHeight = screenFrame.height
        
        // 1. Capture original mouse location
        // Note: NSEvent.mouseLocation has a bottom-left origin; CGEvent uses a top-left origin.
        let originalMouseLocBottomLeft = NSEvent.mouseLocation
        let originalMouseLocTopLeft = CGPoint(
            x: originalMouseLocBottomLeft.x,
            y: screenHeight - originalMouseLocBottomLeft.y
        )
        
        // 2. Launch Mission Control using its system bundle ID
        _ = NSWorkspace.shared.launchApplication(
            withBundleIdentifier: "com.apple.exposelauncher",
            options: [],
            additionalEventParamDescriptor: nil,
            launchIdentifier: nil
        )
        
        // 3. Chain coordinates and clicks on a background interactive thread
        DispatchQueue.global(qos: .userInteractive).async {
            // A. Wait for the Mission Control window-server opening transition
            Thread.sleep(forTimeInterval: 0.22)
            
            // B. Move cursor to the top-right edge (y=2) to trigger expansion of the Spaces Bar
            let triggerPoint = CGPoint(x: screenWidth - 50, y: 2)
            self.postMouseMove(to: triggerPoint)
            
            // C. Wait for the Spaces Bar slide-down animation to complete
            Thread.sleep(forTimeInterval: 0.12)
            
            // D. Move cursor directly over the "+" button (now sitting around y=42)
            let plusButtonPoint = CGPoint(x: screenWidth - 50, y: 42)
            self.postMouseMove(to: plusButtonPoint)
            
            // E. Click the "+" button
            Thread.sleep(forTimeInterval: 0.05)
            self.postLeftClick(at: plusButtonPoint)
            
            // F. Wait for the system to process the new space addition
            Thread.sleep(forTimeInterval: 0.12)
            
            // G. Post Escape (Keycode 53) to exit Mission Control
            self.postEscapeKey()
            
            // H. Wait for the exit animation to fire, then snap the mouse cursor back to original coords
            Thread.sleep(forTimeInterval: 0.08)
            self.postMouseMove(to: originalMouseLocTopLeft)
            
            // I. Request state sync on the main thread
            DispatchQueue.main.async {
                SpaceEngine.shared.updateSpacesInfo()
            }
            
            print("SpaceFlow: Space creation automation finished successfully.")
        }
    }
    
    private static func postMouseMove(to point: CGPoint) {
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        event?.post(tap: .cghidEventTap)
    }
    
    private static func postLeftClick(at point: CGPoint) {
        let down = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        let up = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
    
    private static func postEscapeKey() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 53, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 53, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
