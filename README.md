# SpaceFlow

**Um trackpad-substitute para navegação entre Spaces (desktops virtuais) no macOS, feito para quem trocou a vida de trackpad por mouse + teclado.**

---

## Pra quem é isso?

Se você usou trackpad por anos — no MacBook ou num Magic Trackpad standalone — você criou memória muscular pra coisas como:

- **Swipe de 3/4 dedos pra esquerda/direita** → trocar de Space
- **Swipe de 3/4 dedos pra cima** → abrir o Mission Control
- **Spread / Pinch** → ver todas as janelas

Aí veio o setup com **monitor externo + teclado + mouse** (porque ergonomia, porque telão, porque produtividade) e de repente:

- `Ctrl + ←/→` é desconfortável pro punho
- `Ctrl + ↑` pro Mission Control nunca vira instintivo
- Você fica com a sensação que perdeu **fluidez** pra alternar contexto entre apps

O **SpaceFlow** é a muleta que devolve essa fluidez. Ele intercepta eventos globais do mouse e os transforma em gestos rápidos de troca de Space, mais uma **HUD flutuante** (estilo Touch Bar) sempre presente na parte inferior da tela mostrando qual Space tá ativo e permitindo clicar diretamente.

---

## O que ele faz

### HUD flutuante
- Cápsula glassmorphic no rodapé da tela, **em todos os Spaces** (incl. fullscreen)
- Mostra cada Space como pílula numerada (1, 2, 3, …) com a ativa destacada
- Quando colapsada vira pontinhos LED minimalistas; expande no hover ou ao trocar de Space
- Botões inline: **Mission Control**, **Adicionar Space**, **Ajustes**
- Click direto na pílula → vai pra aquela Space

### Ícone na menu bar
- `⎋ N` mostrando o número da Space ativa
- Menu pra recarregar Spaces, toggles dos gestos, abrir Ajustes, sair

### Gestos (todos toggláveis em Ajustes → Gestos)

| Gesto | O que faz |
|------|-----------|
| **Direct HUD Scroll** | Scroll do mouse por cima da cápsula → troca de Space |
| **Gravity Edge Scroll** | Scroll quando o cursor tá no topo (menu bar) ou rodapé (Dock) da tela → troca de Space |
| **Right-Click + Scroll** | Segura botão direito + scroll, em qualquer lugar da tela → troca de Space |
| **Velocity Shake** | Chacoalha o mouse rápido pra esquerda/direita → alterna entre Spaces adjacentes |
| **Double-Option Warp** | Toca `Option` 2× rápido → teleporta o cursor pra HUD |
| **Double Middle-Click → Mission Control** | Clique duplo no botão do meio (scroll-wheel button) → abre Mission Control (equivalente a `Ctrl + ↑`) |

### Otimização de latência
- Listener global de teclado escuta `Ctrl + ←/→` e `Ctrl + 1..0` e faz **update otimista** da HUD antes mesmo do macOS terminar a transição — evita o lag visual entre apertar a tecla e a HUD mudar.

---

## Como funciona por dentro

```
src/
├── main.swift                  # bootstrap NSApplication + status bar item
├── Core/
│   ├── SpaceEngine.swift       # singleton: estado dos Spaces + settings (UserDefaults)
│   │                            # usa APIs privadas do CoreGraphics (_CGSDefaultConnection)
│   ├── GestureMonitor.swift    # NSEvent.addGlobalMonitorForEvents pra scroll/click/key/move
│   └── SpaceAutomator.swift    # cria/remove Spaces via osascript+System Events
└── UI/
    ├── FloatingBarWindow.swift # NSWindow borderless, level=.statusBar, canJoinAllSpaces
    ├── FloatingBarView.swift   # SwiftUI: cápsula glassmorphic + pílulas + ícones
    ├── SettingsWindow.swift    # janela de ajustes
    ├── SettingsView.swift      # tabs: Gestos / Aparência / Física
    └── PermissionView.swift    # wizard de permissão de Acessibilidade
```

### Dependências
- **macOS 13+** (Ventura)
- **Apple Silicon** (build script compila `-arch arm64` implícito pelo SDK)
- **Permissão de Acessibilidade** — obrigatória pros monitors globais de evento. O app abre o wizard automaticamente na 1ª vez.

### Truques internos relevantes
- `_CGSDefaultConnection()` (API privada do CoreGraphics) pra obter o connection ID e listar Spaces
- `NSWorkspace.activeSpaceDidChangeNotification` pra sincronizar a HUD quando outro app/atalho muda Space
- Janela com `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` pra aparecer em qualquer Space, inclusive em apps fullscreen
- `canBecomeKey = false` no `NSWindow` pra não roubar foco do app ativo (ex: IDE)
- `acceptsFirstMouse = true` no hosting view pra clicks na HUD funcionarem mesmo quando o app não tá em foco
- `hitTest` customizado restringe a área clicável a um retângulo central de 500×75 (deixa as bordas passarem clicks pra apps embaixo)

---

## Build & run

```bash
# 1. (opcional, só na 1ª vez) criar certificado local pra permissão de Acessibilidade persistir entre builds
./setup_certs.sh

# 2. compilar
./build.sh

# 3. abrir
open SpaceFlow.app
```

O `build.sh` chama `swiftc` direto (sem Xcode project), gera o `.app` bundle e assina com `SpaceFlow Local Signing` se existir (senão ad-hoc). Sem code-signing estável, o macOS revoga a permissão de Acessibilidade a cada rebuild — daí o `setup_certs.sh`.

### Logs
Stdout e stderr vão pra `debug.log` na raiz do projeto (redirecionado em `main.swift`). Pra debugar:

```bash
tail -f debug.log
```

---

## Ajustes

Acessíveis via:
- Ícone na menu bar → **Ajustes…**
- Ou via botão da engrenagem na HUD expandida

**Tabs:**
- **Gestos** — liga/desliga cada gesto individualmente
- **Aparência** — cor de destaque (Roxo Neon / Ciano Líquido / Verde Esmeralda / Rosa Choque)
- **Física/Ajustes** — `switchCooldown` (cooldown entre trocas sucessivas, 0.02s a 0.50s; default 0.18s — previne que a inércia do scroll pule múltiplas Spaces)

Tudo persiste em `UserDefaults` (`~/Library/Preferences/com.bruno.SpaceFlow.plist`).
