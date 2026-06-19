import SwiftUI
import SpriteKit

struct GameContainerView: View {
    @Environment(GameState.self) var state
    @State private var scene: GameScene = {
        let s = GameScene()
        s.size = CGSize(width: UIScreen.main.bounds.width,
                        height: UIScreen.main.bounds.height)
        s.scaleMode = .resizeFill
        return s
    }()
    @State private var showLog      = false
    @State private var showMinimap  = false
    @State private var hitFlashAmt: Double = 0
    @State private var turnFlashAmt: Double = 0
    @FocusState private var gameFocused: Bool

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .onAppear {
                    scene.state = state
                    scene.rebuild()
                    state.sceneNeedsRebuild = false  // prevent duplicate rebuild from update()
                    gameFocused = true
                }
                .onChange(of: state.floor) { _, _ in scene.rebuild() }
                // Swipe-to-move on the map area
                .simultaneousGesture(
                    DragGesture(minimumDistance: 22)
                        .onEnded { val in
                            guard state.screen == .playing else { return }
                            let h = val.translation.width
                            let v = val.translation.height
                            if abs(h) > abs(v) {
                                movePlayer(state: state, dx: h > 0 ? 1 : -1, dy: 0)
                            } else {
                                movePlayer(state: state, dx: 0, dy: v > 0 ? 1 : -1)
                            }
                        }
                )

            // Screen-edge flash when player takes a hit (red vignette)
            if hitFlashAmt > 0 {
                RadialGradient(
                    gradient: Gradient(colors: [.clear, Color.red.opacity(hitFlashAmt)]),
                    center: .center, startRadius: 80, endRadius: 280
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // Thin border flash after each enemy turn (subtle turn indicator)
            if turnFlashAmt > 0 {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.white.opacity(turnFlashAmt * 0.15), lineWidth: 3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Game overlays
            VStack(spacing: 0) {
                HUDView(showLog: $showLog, showMinimap: $showMinimap)
                Spacer()
                ControlsView()
            }

            // Minimap overlay (top-right, below HUD)
            if showMinimap {
                MinimapView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 90)
                    .padding(.trailing, 8)
                    .allowsHitTesting(false)
            }

            // Log overlay
            if showLog { logOverlay }

            // Banner
            if let banner = state.banner {
                BannerView(text: banner.text, color: banner.color)
            }

            // Shop / Altar / Equipment / Pause
            if state.screen == .shop    { ShopAltarView(mode: .shop) }
            if state.screen == .altar   { ShopAltarView(mode: .altar) }
            if state.screen == .equipment { EquipmentView() }
            if state.screen == .paused  { PauseView() }
        }
        .focusable()
        .focused($gameFocused)
        // WASD / Arrow key support
        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow,
                           KeyEquivalent("w"), KeyEquivalent("a"),
                           KeyEquivalent("s"), KeyEquivalent("d"),
                           KeyEquivalent(".")]) { press in
            guard state.screen == .playing else { return .ignored }
            switch press.key {
            case .upArrow,    KeyEquivalent("w"): movePlayer(state: state, dx: 0, dy: -1)
            case .downArrow,  KeyEquivalent("s"): movePlayer(state: state, dx: 0, dy: 1)
            case .leftArrow,  KeyEquivalent("a"): movePlayer(state: state, dx: -1, dy: 0)
            case .rightArrow, KeyEquivalent("d"): movePlayer(state: state, dx: 1, dy: 0)
            case KeyEquivalent("."): waitTurn(state: state)
            default: return .ignored
            }
            return .handled
        }
        // Player-hit red flash
        .onChange(of: state.pendingPlayerHit) { _, hit in
            guard hit else { return }
            state.pendingPlayerHit = false
            hitFlashAmt = 0.7
            withAnimation(.easeOut(duration: 0.45)) { hitFlashAmt = 0 }
        }
        // Enemy-turn subtle border flash
        .onChange(of: state.enemyTurnFlash) { _, flash in
            guard flash else { return }
            state.enemyTurnFlash = false
            turnFlashAmt = 1.0
            withAnimation(.easeOut(duration: 0.25)) { turnFlashAmt = 0 }
        }
        // Stairs confirmation alert
        .alert("Descend to floor \(state.floor + 1)?",
               isPresented: Binding(get: { state.stairsPending },
                                    set: { if !$0 { state.stairsPending = false } })) {
            Button("Descend") {
                state.stairsPending = false
                AudioEngine.shared.play(.stairs)
                HapticEngine.medium()
                state.floor += 1
                state.runFloors = state.floor
                enterFloor(state: state)
            }
            Button("Stay", role: .cancel) {
                state.stairsPending = false
                endPlayerTurn(state: state)
            }
        } message: {
            Text("Floor \(state.floor + 1) awaits. You have \(state.player.hp)/\(state.player.maxHp) HP.")
        }
    }

    // MARK: — Log overlay

    private var logOverlay: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Combat Log")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(.gray)
                Spacer()
                Button("×") { showLog = false }
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(state.log.prefix(60))) { entry in
                        Text(entry.text)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(logColor(entry.type))
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .background(Color.black.opacity(0.9))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 120)
    }

    private func logColor(_ type: LogType) -> Color {
        switch type {
        case .normal:  return Color(hex: "#cccccc")
        case .combat:  return Color(hex: "#ff6666")
        case .spell:   return Color(hex: "#aaaaff")
        case .curse:   return Color(hex: "#cc44cc")
        case .trap:    return Color(hex: "#ff8800")
        case .narr:    return Color(hex: "#ffcc44")
        case .info:    return Color(hex: "#888888")
        }
    }
}

// MARK: — Minimap

struct MinimapView: View {
    @Environment(GameState.self) var state

    private let tw: CGFloat = 2.5

    var body: some View {
        Canvas { ctx, _ in
            for y in 0..<GRID_H {
                for x in 0..<GRID_W {
                    guard state.seen[y][x] else { continue }
                    let tile   = state.map[y][x]
                    let vis    = state.vis[y][x]
                    let isSeeker = state.flags.seeker

                    var color: Color
                    switch tile {
                    case .wall:
                        color = vis ? Color(hex: "#445566") : Color(hex: "#222233")
                    case .stairs:
                        color = Color(hex: "#44ff88")
                    case .shop:
                        color = Color(hex: "#ccaa33")
                    case .altar:
                        color = Color(hex: "#9944cc")
                    case .secret:
                        color = isSeeker ? Color(hex: "#0066ff") : (vis ? Color(hex: "#334455") : Color(hex: "#222233"))
                    default:
                        color = vis ? Color(hex: "#7788aa") : Color(hex: "#445566")
                    }

                    let rect = CGRect(x: CGFloat(x) * tw, y: CGFloat(y) * tw, width: tw, height: tw)
                    ctx.fill(Path(rect), with: .color(color))
                }
            }
            // Player dot
            let px = CGFloat(state.player.x) * tw
            let py = CGFloat(state.player.y) * tw
            ctx.fill(Path(CGRect(x: px - 0.5, y: py - 0.5, width: tw + 1, height: tw + 1)), with: .color(.white))
        }
        .frame(width: CGFloat(GRID_W) * tw, height: CGFloat(GRID_H) * tw)
        .background(Color.black.opacity(0.75))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4), lineWidth: 0.5))
        .cornerRadius(3)
    }
}

// MARK: — Banner

struct BannerView: View {
    let text: String
    let color: String

    var body: some View {
        Text(text)
            .font(.system(.headline, design: .monospaced).weight(.bold))
            .foregroundColor(Color(hex: color))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.85))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: color).opacity(0.5), lineWidth: 1))
            .cornerRadius(6)
            .shadow(color: Color(hex: color).opacity(0.4), radius: 8)
            .transition(.opacity)
    }
}

// MARK: — Pause

struct PauseView: View {
    @Environment(GameState.self) var state

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("— PAUSED —")
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundColor(.white)
                Button("Resume") {
                    HapticEngine.light()
                    state.screen = .playing
                }
                .buttonStyle(RPGButtonStyle(color: "#888888"))
                Button("Equipment") {
                    HapticEngine.light()
                    state.screen = .equipment
                }
                .buttonStyle(RPGButtonStyle(color: "#4488cc"))
                Button("Quit to Title") {
                    HapticEngine.medium()
                    AudioEngine.shared.stopMusic()
                    SaveManager.deleteSave()
                    state.screen = .splash
                }
                .buttonStyle(RPGButtonStyle(color: "#cc4444"))
                Toggle("SFX Muted", isOn: Binding(
                    get: { AppSettings.sfxMuted },
                    set: { AppSettings.sfxMuted = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .tint(.red)
                .padding(.horizontal, 32)
                Toggle("Music Muted", isOn: Binding(
                    get: { AppSettings.musicMuted },
                    set: {
                        AppSettings.musicMuted = $0
                        if $0 { AudioEngine.shared.stopMusic() }
                    }
                ))
                .font(.system(.body, design: .monospaced))
                .tint(.purple)
                .padding(.horizontal, 32)
                Toggle("Haptics Off", isOn: Binding(
                    get: { !AppSettings.hapticsEnabled },
                    set: { AppSettings.hapticsEnabled = !$0 }
                ))
                .font(.system(.body, design: .monospaced))
                .tint(.orange)
                .padding(.horizontal, 32)
            }
        }
    }
}
