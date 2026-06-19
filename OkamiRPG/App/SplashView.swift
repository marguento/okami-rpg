import SwiftUI

struct SplashView: View {
    @Environment(GameState.self) var state
    @State private var glowAnim  = false
    @State private var appeared  = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch state.screen {
            case .splash:      titleScreen
            case .classSelect: classSelectScreen
            case .dante:       danteScreen
            default: EmptyView()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glowAnim = true }
            withAnimation(.easeIn(duration: 0.9)) { appeared = true }
        }
        .onChange(of: state.screen) { _, _ in appeared = false; withAnimation(.easeIn(duration: 0.5)) { appeared = true } }
    }

    // MARK: — Title

    private var titleScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("†")
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -12)
                .animation(.easeOut(duration: 0.8), value: appeared)
                .font(.system(size: 80, design: .serif).weight(.black))
                .foregroundColor(Color(hex: "#ff3333"))
                .frame(width: 100, height: 100)
                .background(Color(hex: "#220000"), in: Circle())
                .scaleEffect(glowAnim ? 1.08 : 1.0)
                .shadow(color: Color(hex: "#ff0000").opacity(glowAnim ? 0.9 : 0.4), radius: 18)

            Text("THE CATACOMBS")
                .font(.system(.title, design: .monospaced).weight(.black))
                .foregroundColor(Color(hex: "#cc0000"))
                .shadow(color: Color(hex: "#ff0000").opacity(glowAnim ? 0.9 : 0.3), radius: 8)

            Text("of Margüento")
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundColor(Color(hex: "#996666"))

            Spacer()

            if SaveManager.hasSave {
                Button("Continue") {
                    AudioEngine.shared.play(.door)
                    HapticEngine.medium()
                    _ = SaveManager.load(into: state)
                }
                .buttonStyle(RPGButtonStyle(color: "#888888"))
            }

            Button("New Game") {
                AudioEngine.shared.play(.stairs)
                HapticEngine.light()
                state.screen = .classSelect
            }
            .buttonStyle(RPGButtonStyle(color: "#cc0000"))

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 32)
        .opacity(appeared ? 1 : 0)
        .animation(.easeIn(duration: 0.9), value: appeared)
    }

    // MARK: — Class select

    private var classSelectScreen: some View {
        VStack(spacing: 16) {
            Text("Choose Your Fate")
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .foregroundColor(Color(hex: "#cccccc"))
                .padding(.top, 48)

            ForEach(["warrior", "rogue", "mage"], id: \.self) { clsId in
                let cls = ALL_CLASSES[clsId]!
                Button {
                    AudioEngine.shared.play(.pickup)
                    HapticEngine.medium()
                    state.startGame(cls: clsId)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(cls.name)
                                .font(.system(.headline, design: .monospaced).weight(.bold))
                                .foregroundColor(Color(hex: cls.color))
                            Spacer()
                            Text(cls.stats)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                        Text(cls.classDesc)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color(hex: "#aaaaaa"))
                        HStack(spacing: 12) {
                            ForEach(cls.skills) { sk in
                                Label(sk.name, systemImage: "bolt")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color(hex: "#777777"))
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(hex: "#111111"))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: cls.color).opacity(0.4), lineWidth: 1))
                    .cornerRadius(6)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: — Dante screen

    private var danteScreen: some View {
        let narr = NARRATIONS.randomElement()!
        return VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(hex: "#330000"))
                    .frame(width: 70, height: 70)
                Image(systemName: "skull.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "#ff3333"))
            }
            .shadow(color: Color(hex: "#ff0000").opacity(0.5), radius: 10)
            Text(narr)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(Color(hex: "#cccccc"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Descend") {
                AudioEngine.shared.play(.stairs)
                HapticEngine.heavy()
                state.screen = .rest
            }
            .buttonStyle(RPGButtonStyle(color: "#cc0000"))
            .padding(.bottom, 48)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: — Button style

struct RPGButtonStyle: ButtonStyle {
    let color: String
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .monospaced).weight(.bold))
            .foregroundColor(Color(hex: color))
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color(hex: color).opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: color).opacity(0.5), lineWidth: 1))
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
