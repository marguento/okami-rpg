import SwiftUI

struct GameOverView: View {
    @Environment(GameState.self) var state
    @State private var glowAnim  = false
    @State private var appeared  = false

    private var isVictory: Bool { state.isVictory }
    private var accentHex: String { isVictory ? "#cccc00" : "#cc0000" }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Icon with drop-in animation
                Image(systemName: isVictory ? "trophy.fill" : "skull.fill")
                    .font(.system(size: 72))
                    .foregroundColor(Color(hex: accentHex))
                    .scaleEffect(glowAnim ? 1.06 : 1.0)
                    .shadow(color: Color(hex: accentHex).opacity(glowAnim ? 0.9 : 0.3), radius: 18)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: glowAnim)
                    .offset(y: appeared ? 0 : -40)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.68).delay(0.1), value: appeared)

                // Title
                Text(isVictory ? "VICTORY!" : "YOU DIED")
                    .font(.system(.largeTitle, design: .monospaced).weight(.black))
                    .foregroundColor(Color(hex: accentHex))
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeIn(duration: 0.5).delay(0.35), value: appeared)

                // Cause / tagline
                Group {
                    if !isVictory && !state.deathCause.isEmpty {
                        Text(state.deathCause)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color(hex: "#888888"))
                    } else if isVictory {
                        Text("The catacombs of Margüento have been conquered.")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(Color(hex: "#cccc88"))
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(appeared ? 1 : 0)
                .animation(.easeIn(duration: 0.5).delay(0.55), value: appeared)

                Spacer()

                statsCard
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.5).delay(0.7), value: appeared)

                Spacer()

                Button("Return to Title") {
                    SaveManager.deleteSave()
                    HapticEngine.medium()
                    state.screen = .splash
                    state.isDead = false
                    state.isVictory = false
                }
                .buttonStyle(RPGButtonStyle(color: accentHex))
                .opacity(appeared ? 1 : 0)
                .animation(.easeIn(duration: 0.4).delay(0.9), value: appeared)

                Spacer().frame(height: 48)
            }
        }
        .onAppear {
            glowAnim = true
            appeared = true
            AudioEngine.shared.play(isVictory ? .victory : .death)
        }
    }

    private var statsCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("Run Summary")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundColor(.gray)
                if !state.cls.isEmpty {
                    Text("·  \(state.cls.capitalized)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Color(hex: "#888866"))
                }
            }

            HStack(spacing: 20) {
                statLine("Floors",  "\(state.runFloors)")
                statLine("Kills",   "\(state.kills)")
                statLine("Gold",    "\(state.runGold)")
                statLine("Steps",   "\(state.runSteps)")
            }
            HStack(spacing: 20) {
                statLine("HP",  "\(state.player.hp)/\(state.player.maxHp)")
                statLine("ATK", "\(state.player.atk)")
                statLine("DEF", "\(state.player.def)")
                statLine("Lv",  "\(state.player.level)")
            }
            if !state.relics.isEmpty {
                Text("Relics: " + state.relics.compactMap { relicById($0)?.name }.joined(separator: ", "))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: "#888866"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color(hex: "#0d0d0d"))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: accentHex).opacity(0.15), lineWidth: 1))
        .cornerRadius(8)
        .padding(.horizontal, 24)
    }

    private func statLine(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundColor(.white)
        }
    }
}
