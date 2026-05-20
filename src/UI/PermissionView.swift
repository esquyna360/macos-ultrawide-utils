import SwiftUI
import Cocoa

public struct PermissionView: View {
    @State private var isTrusted: Bool = AXIsProcessTrusted()
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    public var onGranted: () -> Void
    
    public init(onGranted: @escaping () -> Void) {
        self.onGranted = onGranted
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Core Identity Icon
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.indigo, .purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .purple.opacity(0.5), radius: 10)
                .padding(.top, 10)
            
            VStack(spacing: 8) {
                Text("Permissões Necessárias")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("O SpaceFlow precisa de acesso à Acessibilidade do macOS para navegar entre áreas de trabalho e criar novos spaces sem complicação.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }
            
            // Sequential Instruction List
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    Text("1")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.purple.opacity(0.6)))
                    
                    Text("Clique no botão abaixo para abrir as Preferências do Sistema diretamente na seção de **Acessibilidade**.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                }
                
                HStack(alignment: .top, spacing: 10) {
                    Text("2")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.purple.opacity(0.6)))
                    
                    Text("Ative o interruptor ao lado do **SpaceFlow** para autorizar o funcionamento do aplicativo.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.all, 16)
            .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06)))
            .padding(.horizontal, 10)
            
            // Primary Call-To-Action Button
            Button(action: openAccessibilitySettings) {
                Text("Abrir Ajustes do Sistema")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                            .shadow(color: .purple.opacity(0.4), radius: 6, x: 0, y: 3)
                    )
            }
            .buttonStyle(.plain)
            
            Text("Aguardando ativação (detectando automaticamente)...")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.all, 24)
        .frame(width: 380, height: 420)
        .background(
            ZStack {
                Color.black.opacity(0.3)
                
                // Deep background neon glows
                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: -80, y: -80)
                
                Circle()
                    .fill(Color.indigo.opacity(0.18))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: 80, y: 80)
            }
        )
        .onReceive(timer) { _ in
            let trusted = AXIsProcessTrusted()
            if trusted != isTrusted {
                isTrusted = trusted
                if trusted {
                    print("SpaceFlow: Accessibility access granted dynamically.")
                    onGranted()
                }
            }
        }
    }
    
    private func openAccessibilitySettings() {
        SpaceEngine.shared.requestAccessibilityPermission()
    }
}
