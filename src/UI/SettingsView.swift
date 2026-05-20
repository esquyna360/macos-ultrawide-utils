import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var engine = SpaceEngine.shared

    public init() {}

    public var body: some View {
        TabView {
            gesturesTab
                .tabItem { Label("Gestos", systemImage: "hand.draw") }

            physicsTab
                .tabItem { Label("Física", systemImage: "speedometer") }
        }
        .frame(width: 460, height: 360)
        .padding(20)
    }

    private var gesturesTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Gestos")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.bottom, 2)

            toggleRow(
                label: "Direct HUD Scroll",
                hint: "Scroll do mouse sobre a barra → troca de Space",
                binding: $engine.isHUDScrollEnabled
            )
            toggleRow(
                label: "Gravity Edge Scroll",
                hint: "Scroll no topo (menu bar) ou no rodapé (Dock) → troca de Space",
                binding: $engine.isEdgeScrollEnabled
            )
            toggleRow(
                label: "Option + Scroll",
                hint: "Segura Option e rola, em qualquer lugar → troca de Space",
                binding: $engine.isModifierScrollEnabled
            )
            toggleRow(
                label: "Right-Click + Scroll",
                hint: "Segura o botão direito e rola → troca de Space",
                binding: $engine.isRightClickScrollEnabled
            )
            toggleRow(
                label: "Velocity Shake",
                hint: "Chacoalha o mouse rápido pra esquerda/direita → alterna Spaces",
                binding: $engine.isShakeSwitchEnabled
            )
            toggleRow(
                label: "Double-Option Warp",
                hint: "Toca Option 2× rápido → teleporta o cursor pra HUD",
                binding: $engine.isDoubleTapWarpEnabled
            )
            toggleRow(
                label: "Double Middle-Click → Mission Control",
                hint: "Clique duplo no botão do meio → abre Mission Control",
                binding: $engine.isDoubleMiddleClickMCEnabled
            )

            Spacer()
        }
    }

    private var physicsTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Física")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Switch cooldown")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(String(format: "%.2f s", engine.switchCooldown))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Slider(value: $engine.switchCooldown, in: 0.02...0.50, step: 0.01)
                Text("Tempo mínimo entre trocas sucessivas. Evita que inércia de scroll pule várias Spaces.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private func toggleRow(label: String, hint: String, binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 13, weight: .semibold))
                Text(hint).font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
        .toggleStyle(.switch)
    }
}
