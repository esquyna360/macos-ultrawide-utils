# macos-ultrawide-utils

> Um kit de utilitários de menu-bar para quem usa macOS num **monitor ultrawide com teclado + mouse comum** — e sente saudade do trackpad.

[![Download mais recente](https://img.shields.io/github/v/release/esquyna360/macos-ultrawide-utils?label=download&color=blue)](https://github.com/esquyna360/macos-ultrawide-utils/releases/latest)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-lightgrey)
![Apple Silicon](https://img.shields.io/badge/arch-arm64-orange)

---

## A história

Esse projeto nasceu de uma dor concreta:

Comprei um monitor **ultrawide**. Fechei o MacBook. Plug no monitor, **teclado + mouse normais** na mesa. Setup de sonho pra produtividade — telão imenso, postura decente, ergonomia melhor que ficar curvado sobre o laptop.

Aí veio a tomada de consciência: **eu não tinha mais trackpad.**

Anos de memória muscular evaporaram. Coisas que eram instintivas viraram exercício consciente:

- **Swipe de 3 dedos pra trocar de Space** → agora é `Ctrl + ←/→`, desconfortável pro punho
- **Swipe pra cima pro Mission Control** → agora é `Ctrl + ↑`, que nunca grudou na cabeça
- **Spread/pinch** → simplesmente não existe mais

O macOS é desenhado pra trackpad. Quando você tira o trackpad, perde uma camada inteira de fluidez na troca de contexto entre apps. Comprar um Magic Trackpad pra usar do lado do mouse é trapacear — quebra a ergonomia que era o motivo original de migrar pro ultrawide.

A solução foi escrever as muletas. **`macos-ultrawide-utils`** é o repo onde elas vão morar.

## Objetivo do repo

Um conjunto crescente de pequenos utilitários focados em **uma única persona**:

> Usuário macOS que abandonou o trackpad pelo combo monitor ultrawide + teclado + mouse normal — e quer recuperar a fluidez sem ter que decorar atalhos de teclado.

Não é um app monolítico. É um **kit**. Cada utilitário resolve um problema específico, vive como app independente (ou módulo de menu-bar), e pode ser instalado isoladamente.

## Apps disponíveis

### SpaceFlow (v1.0.0)

Navegação entre Spaces (desktops virtuais) sem trackpad. **App de menu-bar com HUD flutuante.**

| Feature | Como funciona |
|---|---|
| **HUD flutuante** | Cápsula glassmorphic no rodapé da tela, em todos os Spaces (incluindo fullscreen). Mostra cada Space como pílula numerada, com a ativa destacada. Click direto pula pra ela. |
| **Direct HUD Scroll** | Scroll do mouse por cima da cápsula → troca de Space. |
| **Gravity Edge Scroll** | Scroll com o cursor encostado no topo (menu bar) ou rodapé (Dock) → troca de Space sem precisar mirar na HUD. |
| **Right-Click + Scroll** | Segura botão direito + scroll em qualquer lugar → troca de Space. |
| **Velocity Shake** | Chacoalha o mouse rápido pra esquerda ou direita → alterna entre Spaces adjacentes. |
| **Double-Option Warp** | Toca a tecla `Option` 2× rápido → cursor teleporta pra HUD. |
| **Double Middle-Click → Mission Control** | Dois cliques rápidos no botão do meio do mouse → abre Mission Control (equivalente a `Ctrl + ↑`). |
| **Menu-bar indicator** | Ícone `⎋ N` na barra superior mostrando em qual Space você tá. |

Todos os gestos são **toggláveis individualmente** em `Ajustes → Gestos` — você liga só os que fazem sentido pra você.

---

## Instalação

### Via release pré-compilada (recomendado)

1. Baixe o `.zip` mais recente em [**Releases**](https://github.com/esquyna360/macos-ultrawide-utils/releases/latest)
2. Descompacte e arraste `SpaceFlow.app` pra `/Applications`
3. **Primeira abertura — importante:** o app é assinado em modo *ad-hoc* (sem Apple Developer Program), então o Gatekeeper vai bloquear. Pra contornar:
   - Botão direito no `SpaceFlow.app` → **Abrir** → confirme no diálogo
   - **ou** Ajustes do Sistema → Privacidade e Segurança → role até a mensagem sobre o SpaceFlow → **Abrir Mesmo Assim**
4. Conceda permissão de **Acessibilidade** quando o wizard pedir:
   - Ajustes do Sistema → Privacidade e Segurança → Acessibilidade → habilite `SpaceFlow`
   - Essa permissão é **obrigatória** — o app intercepta eventos globais de mouse/teclado, e o macOS não permite isso sem a flag explícita
5. Pronto. Ícone `⎋ N` aparece na menu bar e a HUD flutuante no rodapé.

> **Por que tenho que reabrir/recolocar a permissão depois de cada update?**
> Apps ad-hoc signed perdem a identidade criptográfica a cada rebuild, e o macOS revoga a permissão de Acessibilidade. Se você compila local e quer estabilidade, rode `./setup_certs.sh` (cria um cert self-signed permanente no seu keychain). Pra release oficial isso vai mudar quando houver code-signing com Apple Developer ID.

### Compilando do código-fonte

Requisitos:
- macOS 13+ (Ventura) em Apple Silicon
- Xcode Command Line Tools (`xcode-select --install`)

```bash
git clone https://github.com/esquyna360/macos-ultrawide-utils.git
cd macos-ultrawide-utils

# (opcional, só na 1ª vez) — cert self-signed pra permissão de Acessibilidade persistir
./setup_certs.sh

# compila
./build.sh

# abre
open SpaceFlow.app
```

O `build.sh` chama `swiftc` direto (sem Xcode project), gera o `.app` bundle e assina com `SpaceFlow Local Signing` se o cert existir, senão cai em ad-hoc.

---

## Guia de uso — SpaceFlow

### A HUD

A cápsula flutuante no rodapé é seu ponto de controle visual.

- **Colapsada**: pontinhos LED minimalistas, fica fora do caminho
- **Expandida**: mostra todas as Spaces como pílulas numeradas, com a ativa destacada
- **Expande automaticamente**: ao passar o mouse perto, ou quando você troca de Space

Botões inline (na ponta da cápsula expandida):
- **Mission Control** — equivalente a `Ctrl + ↑`
- **+** — adiciona um Space novo
- **⚙** — abre Ajustes

### Os gestos — qual usar?

Você não precisa usar todos. A ideia é experimentar e ficar com o que casa com seu estilo:

- **Quer minimalismo?** → Só **Gravity Edge Scroll** já resolve 80% dos casos. Cursor no topo da tela + scroll = troca de Space. Sem mirar em nada.
- **Quer agressivo?** → **Velocity Shake** é o mais "trackpad-like". Você sacode o mouse rápido pra esquerda/direita e ele alterna. Treina a memória muscular pra ser quase reflexo.
- **Quer preciso?** → **Direct HUD Scroll** + click direto nas pílulas. Você sempre vê pra onde tá indo.
- **Quer Mission Control sem soltar o mouse?** → **Double Middle-Click**. Dois toques no scroll-wheel button = `Ctrl + ↑`.

### Ajustes

Acesse via menu-bar (`⎋ N` → Ajustes...) ou pela engrenagem na HUD.

**Tabs:**
- **Gestos** — liga/desliga cada gesto individualmente
- **Aparência** — cor de destaque (Roxo Neon / Ciano Líquido / Verde Esmeralda / Rosa Choque)
- **Física** — `switchCooldown` (cooldown entre trocas sucessivas, 0.02s a 0.50s; default 0.18s). Útil pra previnir que a inércia do scroll pule múltiplas Spaces de uma vez

Tudo persiste em `UserDefaults` (`~/Library/Preferences/com.bruno.SpaceFlow.plist`).

---

## Como funciona por dentro

Pra quem curte o lado técnico:

```
src/
├── main.swift                    # bootstrap NSApplication + status bar item
├── Core/
│   ├── SpaceEngine.swift         # singleton: estado dos Spaces + settings (UserDefaults)
│   │                             # usa _CGSDefaultConnection() — API privada do CoreGraphics
│   ├── GestureMonitor.swift      # NSEvent.addGlobalMonitorForEvents pra scroll/click/key/move
│   ├── SpaceAutomator.swift      # cria/remove Spaces via osascript + System Events
│   ├── HotZoneState.swift        # estado das edge zones (topo/rodapé)
│   └── FloatingBarState.swift    # estado expandido/colapsado da HUD
└── UI/
    ├── FloatingBarWindow.swift   # NSWindow borderless, level=.statusBar, canJoinAllSpaces
    ├── FloatingBarView.swift     # SwiftUI: cápsula glassmorphic + pílulas + ícones
    ├── HotZoneWindows.swift      # janelas invisíveis nas edges pra detectar hover
    ├── SettingsWindow.swift      # janela de ajustes
    ├── SettingsView.swift        # tabs: Gestos / Aparência / Física
    └── PermissionView.swift      # wizard de permissão de Acessibilidade
```

### Truques internos relevantes

- **`_CGSDefaultConnection()`** (API privada do CoreGraphics) pra obter o connection ID e listar Spaces — necessário porque a API pública não expõe isso
- **`NSWorkspace.activeSpaceDidChangeNotification`** pra sincronizar a HUD quando outro app/atalho muda Space
- **`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`** pra HUD aparecer em qualquer Space, inclusive em apps fullscreen
- **`canBecomeKey = false`** pra HUD não roubar foco do app ativo (ex: IDE em foco fica em foco)
- **`acceptsFirstMouse = true`** pra clicks na HUD funcionarem mesmo quando o app não tá ativo
- **`hitTest` customizado** restringe a área clicável a um retângulo central de 500×75 — deixa as bordas passarem clicks pra apps embaixo
- **Listener otimista de teclado** escuta `Ctrl + ←/→` e `Ctrl + 1..0` e atualiza a HUD **antes** do macOS terminar a transição, evitando o flicker visual

### Logs

`stdout` e `stderr` são redirecionados pra `debug.log` na pasta ao lado do `.app` bundle. Pra debugar:

```bash
tail -f debug.log
```

---

## Roadmap

A ideia é que esse repo cresça com utilitários adicionais voltados pra mesma persona (ultrawide + mouse + teclado).

Ideias que estão no radar (sem ordem nem compromisso):

- **WindowSnap** — snap de janelas em halves/thirds/quarters numa tela ultrawide via gestos do mouse (sem decorar atalhos tipo Rectangle/Magnet)
- **AppCycler** — alternar entre janelas do mesmo app de forma mais fluida que `Cmd+\``
- **EdgeLaunch** — hot corners turbinados que disparam ações arbitrárias (não só Mission Control)
- **CursorFlow** — wrap do cursor entre bordas opostas do ultrawide (ir do extremo direito pro esquerdo sem cruzar a tela toda)

Sugestões? [Abra uma issue.](https://github.com/esquyna360/macos-ultrawide-utils/issues/new)

---

## FAQ

**Funciona em Mac Intel?**
Por enquanto só Apple Silicon (arm64). O `build.sh` herda a arquitetura do SDK ativo — em teoria dá pra compilar Intel localmente, mas não testei e a release oficial é só arm64.

**Funciona com múltiplos monitores?**
Sim. A HUD aparece em todos os Spaces, e o macOS já trata Spaces como conceito por-monitor (depende da sua config em Ajustes do Sistema → Mesa e Dock → "Monitores têm Spaces separados").

**O app consome muita bateria/CPU?**
Não. Listeners globais de evento são leves; o app fica idle quase sempre. Sem polling, tudo event-driven.

**Por que algumas trocas de Space têm um flash branco?**
Limitação do próprio macOS — quando você troca de Space rápido demais, a animação de transição não dá conta. O `switchCooldown` em Ajustes existe pra mitigar isso.

**E privacidade? O que esse app vê?**
A permissão de Acessibilidade dá acesso amplo a eventos do sistema. O SpaceFlow lê **apenas** eventos de mouse (scroll, click, position) e teclas modificadoras (`Ctrl`, `Option`). Não logga conteúdo. Não envia nada pra lugar nenhum (zero código de rede no projeto — pode auditar o source). O único arquivo gerado é `debug.log` local.

---

## Licença

MIT. Use, fork, modifique. Se virar produto comercial, dê os créditos.

## Contribuindo

PRs são bem-vindos. Pra mudanças grandes, abra uma issue antes pra discutir o approach. Mantenha a persona em mente: **usuário de ultrawide + mouse comum, com saudade do trackpad**. Features que só fazem sentido pra outro contexto provavelmente vão pra outro repo.
