import SwiftUI

struct HUDView: View {
    @Environment(GameState.self) var state
    @Binding var showLog: Bool
    @Binding var showMinimap: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(alignment: .center, spacing: 8) {
                // Floor
                Text("F\(state.floor)")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundColor(Color(hex: "#888888"))

                // HP bar
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                        Text("\(state.player.hp)/\(state.player.maxHp)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    GeometryReader { g in
                        let pct = CGFloat(state.player.hp) / CGFloat(max(1, state.player.maxHp))
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(hex: "#333333"))
                            Capsule().fill(hpColor(pct)).frame(width: g.size.width * pct)
                        }
                    }
                    .frame(height: 5)
                }
                .frame(width: 90)

                // XP bar
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "#cccc44"))
                        Text("Lv\(state.player.level)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "#cccc44"))
                    }
                    GeometryReader { g in
                        let next = state.player.xpNext
                        let pct = next > 0 ? CGFloat(state.player.xp) / CGFloat(next) : 1
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(hex: "#333333"))
                            Capsule().fill(Color(hex: "#888800")).frame(width: g.size.width * min(1, pct))
                        }
                    }
                    .frame(height: 5)
                }
                .frame(width: 70)

                Spacer()

                // Gold
                HStack(spacing: 3) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundColor(Color(hex: "#cccc44"))
                    Text("\(state.gold)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#cccc44"))
                }

                // Minimap toggle
                Button {
                    showMinimap.toggle()
                } label: {
                    Image(systemName: showMinimap ? "map.fill" : "map")
                        .font(.system(size: 15))
                        .foregroundColor(showMinimap ? Color(hex: "#44aaff") : .gray)
                }

                // Log button
                Button {
                    showLog.toggle()
                } label: {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }

                // Pause button
                Button {
                    HapticEngine.light()
                    state.screen = .paused
                } label: {
                    Image(systemName: "pause.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.75))

            // Status row (curses, relics, active stats)
            if !state.curses.isEmpty || !state.relics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(state.curses) { curse in
                            HStack(spacing: 2) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9)).foregroundColor(.purple)
                                Text(curse.name)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.purple)
                            }
                        }
                        ForEach(state.relics.prefix(6), id: \.self) { rid in
                            if let rel = relicById(rid) {
                                Text(rel.name)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Color(hex: "#888844"))
                            }
                        }
                        statBadge(symbol: "bolt.fill", color: "#cc6644", val: "\(state.player.atk)")
                        statBadge(symbol: "shield.fill", color: "#4488cc", val: "\(state.player.def)")
                        if state.player.spell > 0 {
                            statBadge(symbol: "wand.and.stars", color: "#8866cc", val: "\(state.player.spell)")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                }
                .background(Color.black.opacity(0.6))
            }

            // Latest log line (log[0] is newest due to insert-at-0 in addLog)
            if let first = state.log.first {
                Text(first.text)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(logLineColor(first.type))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.5))
            }
        }
    }

    private func hpColor(_ pct: CGFloat) -> Color {
        if pct > 0.5 { return Color(hex: "#22cc22") }
        if pct > 0.25 { return Color(hex: "#cccc22") }
        return Color(hex: "#cc2222")
    }

    private func statBadge(symbol: String, color: String, val: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 8))
                .foregroundColor(Color(hex: color))
            Text(val)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    private func logLineColor(_ type: LogType) -> Color {
        switch type {
        case .combat:  return Color(hex: "#ff8888")
        case .spell:   return Color(hex: "#8888ff")
        case .curse:   return Color(hex: "#cc44cc")
        case .trap:    return Color(hex: "#ff8800")
        case .narr:    return Color(hex: "#ffcc44")
        default:       return Color(hex: "#aaaaaa")
        }
    }
}
