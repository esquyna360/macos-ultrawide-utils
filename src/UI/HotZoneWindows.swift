import Cocoa
import SwiftUI

// MARK: - Top-center Mission Control chip

public struct TopCenterChipView: View {
    @ObservedObject private var state = HotZoneState.shared
    @ObservedObject private var engine = SpaceEngine.shared
    @State private var dwellTask: DispatchWorkItem?

    public init() {}

    public var body: some View {
        VStack {
            if state.isInTopCenter {
                Button(action: triggerNow) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.3.group")
                            .font(.system(size: 12, weight: .bold))
                        Text(engine.isMissionControlPresumedOpen ? "Hide All" : "Show All")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .opacity(0.7)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 4)
                    )
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 4)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.isInTopCenter)
        .onChange(of: state.isInTopCenter) { newValue in
            handleZoneChange(inZone: newValue)
        }
    }

    private func triggerNow() {
        dwellTask?.cancel()
        dwellTask = nil
        SpaceEngine.shared.toggleMissionControl()
        state.markTopCenterTriggered()
    }

    private func handleZoneChange(inZone: Bool) {
        dwellTask?.cancel()
        dwellTask = nil
        guard inZone else { return }

        let task = DispatchWorkItem {
            if HotZoneState.shared.isInTopCenter {
                SpaceEngine.shared.toggleMissionControl()
                HotZoneState.shared.markTopCenterTriggered()
            }
        }
        dwellTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: task)
    }
}

// MARK: - Corner prev/next pills

public struct CornerPillView: View {
    public enum Side { case left, right }

    @ObservedObject private var state = HotZoneState.shared
    @ObservedObject private var engine = SpaceEngine.shared
    private let side: Side

    public init(side: Side) {
        self.side = side
    }

    private var isInZone: Bool {
        side == .left ? state.isInBottomLeft : state.isInBottomRight
    }

    private var targetIndex: Int? {
        let candidate = side == .left ? engine.currentSpaceIndex - 1 : engine.currentSpaceIndex + 1
        return (candidate >= 1 && candidate <= engine.totalSpacesCount) ? candidate : nil
    }

    public var body: some View {
        let alignment: Alignment = (side == .left) ? .bottomLeading : .bottomTrailing
        return HStack {
            if side == .right { Spacer(minLength: 0) }
            if isInZone, let target = targetIndex {
                pill(for: target)
                    .transition(.move(edge: side == .left ? .leading : .trailing).combined(with: .opacity))
            }
            if side == .left { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isInZone)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: targetIndex)
    }

    private func pill(for target: Int) -> some View {
        Button(action: { engine.switchToSpace(index: target) }) {
            HStack(spacing: 6) {
                if side == .left {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(target)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                } else {
                    Text("\(target)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
        .help(side == .left ? "Ir para o Desktop anterior" : "Ir para o próximo Desktop")
    }
}

// MARK: - Borderless transparent floating window shared by all hot zones

public class HotZoneWindow: NSWindow {
    public init(frame: NSRect, content: NSView) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        // Defaults to pass-through; HotZoneState flips this to false only while the cursor
        // is inside the corresponding zone, so the window doesn't eat clicks meant for
        // apps that happen to be at the top-center / corners of the screen.
        self.ignoresMouseEvents = true
        self.acceptsMouseMovedEvents = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        content.frame = NSRect(origin: .zero, size: frame.size)
        self.contentView = content
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

// MARK: - Manager that owns the three hot-zone windows

public class HotZoneWindowManager {
    public static let shared = HotZoneWindowManager()

    private var topCenterWindow: HotZoneWindow?
    private var bottomLeftWindow: HotZoneWindow?
    private var bottomRightWindow: HotZoneWindow?
    private var frameObservers: [NSObjectProtocol] = []

    private init() {}

    public func start() {
        HotZoneState.shared.recomputeFrames()
        spawnWindows()

        // Recompute frames if the user plugs/unplugs a monitor or changes resolution.
        let nc = NotificationCenter.default
        frameObservers.append(nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            HotZoneState.shared.recomputeFrames()
            self?.repositionWindows()
        })
    }

    /// Toggles each hot-zone window between pass-through and interactive so they only
    /// capture clicks while the cursor is actually inside the corresponding zone.
    public func setZoneMouseHandling(top: Bool, left: Bool, right: Bool) {
        if let w = topCenterWindow, w.ignoresMouseEvents != !top {
            w.ignoresMouseEvents = !top
        }
        if let w = bottomLeftWindow, w.ignoresMouseEvents != !left {
            w.ignoresMouseEvents = !left
        }
        if let w = bottomRightWindow, w.ignoresMouseEvents != !right {
            w.ignoresMouseEvents = !right
        }
    }

    private func spawnWindows() {
        let state = HotZoneState.shared

        let topHost = NSHostingView(rootView: TopCenterChipView())
        topHost.wantsLayer = true
        topHost.layer?.backgroundColor = NSColor.clear.cgColor
        topCenterWindow = HotZoneWindow(frame: state.topCenterFrame, content: topHost)

        let leftHost = NSHostingView(rootView: CornerPillView(side: .left))
        leftHost.wantsLayer = true
        leftHost.layer?.backgroundColor = NSColor.clear.cgColor
        bottomLeftWindow = HotZoneWindow(frame: state.bottomLeftFrame, content: leftHost)

        let rightHost = NSHostingView(rootView: CornerPillView(side: .right))
        rightHost.wantsLayer = true
        rightHost.layer?.backgroundColor = NSColor.clear.cgColor
        bottomRightWindow = HotZoneWindow(frame: state.bottomRightFrame, content: rightHost)

        topCenterWindow?.orderFrontRegardless()
        bottomLeftWindow?.orderFrontRegardless()
        bottomRightWindow?.orderFrontRegardless()
    }

    private func repositionWindows() {
        let state = HotZoneState.shared
        topCenterWindow?.setFrame(state.topCenterFrame, display: true)
        bottomLeftWindow?.setFrame(state.bottomLeftFrame, display: true)
        bottomRightWindow?.setFrame(state.bottomRightFrame, display: true)
    }
}
