import SwiftUI

struct ControlsView: View {
    @Environment(GameState.self) var state

    // SF Symbol names per skill ID
    private let skillSymbol: [String: String] = [
        "brutalStrike": "burst.fill",
        "fortify":      "shield.fill",
        "warcry":       "megaphone.fill",
        "fireball":     "flame.fill",
        "freeze":       "snowflake",
        "lightning":    "bolt.fill",
        "poison":       "cross.vial.fill",
        "shadow":       "moon.fill",
        "ambush":       "scope",
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            dpad
                .padding(.leading, 16)
                .padding(.bottom, 24)

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                // Skill buttons row
                HStack(spacing: 8) {
                    ForEach(Array(state.skills.enumerated()), id: \.offset) { i, sk in
                        skillButton(sk, index: i)
                    }
                }
                // Utility row
                HStack(spacing: 8) {
                    utilButton(symbol: "arrow.up.right", label: "Shoot", color: "#aa8844") {
                        shootProjectile(state: state)
                    }
                    utilButton(symbol: "clock", label: "Wait", color: "#8888aa") {
                        waitTurn(state: state)
                    }
                    utilButton(symbol: "bag", label: "Equip", color: "#4466aa") {
                        HapticEngine.light()
                        state.screen = state.screen == .equipment ? .playing : .equipment
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.6).ignoresSafeArea(edges: .bottom))
    }

    // MARK: — D-Pad

    private var dpad: some View {
        ZStack {
            // Cross-shaped background
            VStack(spacing: 0) {
                Color.clear.frame(width: 60, height: 60)
                Color(hex: "#1a1a1a").frame(width: 60, height: 60).cornerRadius(6)
                Color.clear.frame(width: 60, height: 60)
            }
            HStack(spacing: 0) {
                Color(hex: "#1a1a1a").frame(width: 60, height: 60).cornerRadius(6)
                Color.clear.frame(width: 60, height: 60)
                Color(hex: "#1a1a1a").frame(width: 60, height: 60).cornerRadius(6)
            }

            VStack(spacing: 0) {
                dpadBtn(systemName: "arrowtriangle.up.fill", dx: 0, dy: -1)
                HStack(spacing: 0) {
                    dpadBtn(systemName: "arrowtriangle.left.fill", dx: -1, dy: 0)
                    Color.black.opacity(0.5).frame(width: 60, height: 60)
                    dpadBtn(systemName: "arrowtriangle.right.fill", dx: 1, dy: 0)
                }
                dpadBtn(systemName: "arrowtriangle.down.fill", dx: 0, dy: 1)
            }
        }
        .frame(width: 180, height: 180)
    }

    private func dpadBtn(systemName: String, dx: Int, dy: Int) -> some View {
        Button {
            HapticEngine.light()
            movePlayer(state: state, dx: dx, dy: dy)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "#bbbbbb"))
                .frame(width: 60, height: 60)
                .contentShape(Rectangle())
        }
    }

    // MARK: — Skill button

    private func skillButton(_ sk: SkillData, index: Int) -> some View {
        let onCd  = sk.cur > 0
        let sym   = skillSymbol[sk.id] ?? "questionmark"
        return Button {
            useSkill(state: state, index: index)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: sym)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(onCd ? Color(hex: "#555555") : Color(hex: "#ccaa66"))
                if onCd {
                    Text("\(sk.cur)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.red)
                } else {
                    Text(sk.name)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Color(hex: "#777777"))
                }
            }
            .frame(width: 52, height: 52)
            .background(onCd ? Color(hex: "#1a1a1a") : Color(hex: "#222222"))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                onCd ? Color.gray.opacity(0.2) : Color(hex: "#554433"), lineWidth: 1))
            .cornerRadius(8)
            .opacity(onCd ? 0.5 : 1.0)
        }
        .disabled(onCd)
    }

    // MARK: — Utility button

    private func utilButton(symbol: String, label: String, color: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: color))
                Text(label)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Color(hex: "#777777"))
            }
            .frame(width: 52, height: 52)
            .background(Color(hex: "#222222"))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: color).opacity(0.35), lineWidth: 1))
            .cornerRadius(8)
        }
    }
}
