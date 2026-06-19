import SwiftUI

struct RestScreenView: View {
    @Environment(GameState.self) var state
    @State private var rolling   = false
    @State private var rolled    = false
    @State private var diceVals  = [0, 0, 0, 0]
    @State private var timer: Timer?
    @State private var narration = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()

                HStack(spacing: 12) {
                    Image(systemName: "skull").font(.system(size: 22)).foregroundColor(Color(hex: "#cc0000"))
                    Text("REST")
                        .font(.system(.title, design: .monospaced).weight(.black))
                        .foregroundColor(Color(hex: "#cc0000"))
                    Image(systemName: "skull").font(.system(size: 22)).foregroundColor(Color(hex: "#cc0000"))
                }

                Text("Floor \(state.floor) — \(state.floor < MAX_FLOORS ? FLOOR_NAMES[min(state.floor, FLOOR_NAMES.count - 1)] : "The Final Chamber")")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(Color(hex: "#888888"))

                // Narration (computed once on appear, not every render)
                Text(narration)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Color(hex: "#aaaaaa"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Four dice
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { i in
                        DieView(value: diceVals[i], rolling: rolling)
                    }
                }

                if rolled {
                    let total = diceVals.reduce(0, +)
                    VStack(spacing: 6) {
                        Text("Total: \(total)")
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                            .foregroundColor(Color(hex: "#cccc44"))
                        Text(restBonusDesc(total))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color(hex: "#888888"))
                    }
                }

                Spacer()

                Button(rolled ? "Descend" : "Roll the Bones") {
                    if !rolled {
                        rollDice()
                    } else {
                        descend()
                    }
                }
                .buttonStyle(RPGButtonStyle(color: rolled ? "#cc0000" : "#888888"))

                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            diceVals = [1,1,1,1]
            rolled = false
            narration = NARRATIONS.randomElement() ?? ""
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func rollDice() {
        rolling = true; AudioEngine.shared.play(.skillWarcry); HapticEngine.medium()
        var count = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { t in
            diceVals = (0..<4).map { _ in Int.random(in: 1...6) }
            count += 1
            if count >= 18 {
                t.invalidate(); timer = nil
                rolling = false; rolled = true
                applyRestBonus(diceVals.reduce(0, +))
                HapticEngine.heavy()
            }
        }
    }

    private func applyRestBonus(_ total: Int) {
        switch total {
        case 4:
            // Snake eyes — curse
            let avail = ALL_CURSES.filter { !state.hasCurse($0.id) }
            if let curse = avail.randomElement() {
                state.curses.append(curse)
                state.addLog("Snake eyes! Cursed: \(curse.name)", .curse)
                state.applyCurseEffect(curse)
                AudioEngine.shared.play(.trap)
            }
        case 5...8:
            let heal = total
            state.player.hp = min(state.player.maxHp, state.player.hp + heal)
            state.addLog("Rest: +\(heal)HP", .normal)
        case 9...16:
            let heal = total + 4
            state.player.hp = min(state.player.maxHp, state.player.hp + heal)
            state.addLog("Good rest: +\(heal)HP", .normal)
        case 17...23:
            state.player.bonusMaxHp += 2
            state.applyEquipment()
            state.player.hp = min(state.player.maxHp, state.player.hp + 20)
            state.addLog("Deep rest: +20HP, MaxHP+2!", .spell)
        case 24:
            // Perfection — free relic
            state.player.hp = state.player.maxHp
            let avail = ALL_RELICS.filter { !state.hasRelic($0.id) }
            if let rel = avail.randomElement() { state.applyRelic(rel.id) }
            state.addLog("Perfect roll! Full heal + relic!", .narr)
            AudioEngine.shared.play(.relic)
        default:
            state.player.hp = min(state.player.maxHp, state.player.hp + total)
            state.addLog("Rest: +\(total)HP", .normal)
        }
    }

    private func restBonusDesc(_ total: Int) -> String {
        switch total {
        case 4:    return "Snake eyes — Cursed!"
        case 5...8: return "+\(total)HP"
        case 9...16: return "+\(total + 4)HP"
        case 17...23: return "+20HP & MaxHP+2"
        case 24:   return "Perfect! Full heal + Relic!"
        default:   return "+\(total)HP"
        }
    }

    private func descend() {
        AudioEngine.shared.play(.stairs); HapticEngine.heavy()
        // Apply pending curse from altar bargain
        if let pc = state.pendingCurse {
            state.curses.append(pc)
            state.applyCurseEffect(pc)
            state.pendingCurse = nil
            state.addLog("\(pc.name) curse takes hold!", .curse)
        }
        generateFloor(state: state)
        computeVision(state: state)
        state.screen = .playing
    }
}

// MARK: — Die view (number in styled box)

private struct DieView: View {
    let value: Int
    let rolling: Bool

    var body: some View {
        Text("\(max(1, value))")
            .font(.system(size: 40, design: .monospaced).weight(.black))
            .foregroundColor(Color(hex: "#cccc44"))
            .frame(width: 64, height: 64)
            .background(Color(hex: "#1a1a1a"))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#444444"), lineWidth: 2))
            .cornerRadius(10)
            .scaleEffect(rolling ? CGFloat.random(in: 0.92...1.08) : 1.0)
            .animation(
                rolling ? .easeInOut(duration: 0.08).repeatForever(autoreverses: true) : .default,
                value: rolling
            )
    }
}
