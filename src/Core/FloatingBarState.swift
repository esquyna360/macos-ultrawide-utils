import Cocoa
import Foundation

/// Shared state between the SwiftUI FloatingBarView and the AppKit FloatingBarWindow.
/// Lets the window compute the cursor-over-capsule rect without relying on SwiftUI's
/// .onHover (which doesn't fire when the window is ignoring mouse events).
public class FloatingBarState: ObservableObject {
    public static let shared = FloatingBarState()

    @Published public var isHovered: Bool = false

    private init() {}
}
