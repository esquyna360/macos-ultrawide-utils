import SwiftUI

public struct FloatingBarView: View {
    @ObservedObject private var engine = SpaceEngine.shared
    @ObservedObject private var barState = FloatingBarState.shared

    public init() {}

    private var isExpanded: Bool {
        barState.isHovered || engine.isTemporarilyExpanded
    }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.36, green: 0.32, blue: 0.98), Color(red: 0.65, green: 0.28, blue: 0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var body: some View {
        ZStack {
            // Center the capsule in the wider hosting window
            HStack {
                Spacer()
                capsule
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isExpanded)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: engine.currentSpaceIndex)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: engine.totalSpacesCount)
    }

    private var capsule: some View {
        Group {
            if !engine.isAccessibilityTrusted {
                permissionPill
            } else if isExpanded {
                expandedPills
            } else {
                dotsRow
            }
        }
        .padding(.horizontal, isExpanded ? 12 : 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 6)
        )
        .contentShape(Capsule())
    }

    // MARK: - Standby: dots row

    private var dotsRow: some View {
        HStack(spacing: 8) {
            ForEach(1...max(engine.totalSpacesCount, 1), id: \.self) { index in
                let isActive = index == engine.currentSpaceIndex
                Circle()
                    .fill(isActive ? AnyShapeStyle(accentGradient) : AnyShapeStyle(Color.white.opacity(0.35)))
                    .frame(width: isActive ? 10 : 5, height: isActive ? 10 : 5)
                    .shadow(color: isActive ? Color(red: 0.45, green: 0.3, blue: 0.95).opacity(0.7) : .clear, radius: 4)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Hover/active: numbered pills + action buttons

    private var expandedPills: some View {
        HStack(spacing: 6) {
            ForEach(1...max(engine.totalSpacesCount, 1), id: \.self) { index in
                spacePill(index: index)
            }

            Divider()
                .frame(height: 22)
                .background(Color.white.opacity(0.15))
                .padding(.horizontal, 2)

            actionButton(systemName: "rectangle.3.group", help: "Mission Control") {
                engine.toggleMissionControl()
            }
            actionButton(systemName: "plus", help: "Adicionar Desktop") {
                SpaceAutomator.createNewSpace()
            }
            actionButton(systemName: "gearshape", help: "Ajustes") {
                SettingsWindow.show()
            }
        }
    }

    private func spacePill(index: Int) -> some View {
        let isActive = index == engine.currentSpaceIndex
        return Button(action: { engine.switchToSpace(index: index) }) {
            Text("\(index)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isActive ? .white : .white.opacity(0.7))
                .frame(width: 30, height: 30)
                .background(
                    ZStack {
                        if isActive {
                            Circle()
                                .fill(accentGradient)
                                .shadow(color: Color(red: 0.45, green: 0.3, blue: 0.95).opacity(0.55), radius: 4)
                        } else {
                            Circle().fill(Color.white.opacity(0.08))
                        }
                    }
                )
                .scaleEffect(isActive ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .help("Mudar para o Desktop \(index)")
    }

    private func actionButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Permission warning pill

    private var permissionPill: some View {
        Button(action: { engine.requestAccessibilityPermission() }) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 12, weight: .bold))
                Text("Autorizar Acessibilidade")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.2))
                    .overlay(Capsule().stroke(Color.orange.opacity(0.4), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
