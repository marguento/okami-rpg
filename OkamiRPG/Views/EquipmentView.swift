import SwiftUI

struct EquipmentView: View {
    @Environment(GameState.self) var state

    private let slotSymbols: [String: String] = [
        "weapon":"bolt.fill", "shield":"shield.fill", "helmet":"checkerboard.shield",
        "chest":"tshirt.fill", "legs":"figure.walk", "amulet":"circle.hexagongrid.fill", "ring":"circle.fill"
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Equipment")
                        .font(.system(.title3, design: .monospaced).weight(.bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Done") {
                        HapticEngine.light()
                        state.screen = .playing
                    }
                    .foregroundColor(Color(hex: "#888888"))
                    .font(.system(.body, design: .monospaced))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Stats summary
                HStack(spacing: 16) {
                    statView("HP", "\(state.player.hp)/\(state.player.maxHp)")
                    statView("ATK", "\(state.player.atk)")
                    statView("DEF", "\(state.player.def)")
                    if state.player.spell > 0 { statView("SPL", "\(state.player.spell)") }
                    statView("CRT", "\(Int(state.player.crit * 100))%")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                Divider().background(Color.gray.opacity(0.3))

                // Equipment slots
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(EQUIP_SLOTS, id: \.self) { slot in
                            slotRow(slot)
                        }
                    }
                    .padding(16)

                    // Relics with descriptions
                    if !state.relics.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Relics")
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                            VStack(spacing: 6) {
                                ForEach(state.relics, id: \.self) { rid in
                                    if let rel = relicById(rid) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "sparkle")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(hex: "#ccaa44"))
                                                .frame(width: 18)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(rel.name)
                                                    .font(.system(size: 12, design: .monospaced).weight(.semibold))
                                                    .foregroundColor(Color(hex: "#ccaa66"))
                                                Text(rel.desc)
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundColor(Color(hex: "#888877"))
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(hex: "#141410"))
                                        .overlay(RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color(hex: "#886633").opacity(0.3), lineWidth: 1))
                                        .cornerRadius(5)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
        }
    }

    private func slotRow(_ slot: String) -> some View {
        let sym = slotSymbols[slot] ?? "questionmark"
        let equipped = state.equipment[slot].flatMap { equipById($0) }
        return HStack(spacing: 12) {
            Image(systemName: sym)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#888888"))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(slot.capitalized)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
                if let eq = equipped {
                    Text(eq.name)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundColor(.white)
                    Text(eq.desc)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: "#888888"))
                } else {
                    Text("— empty —")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(Color(hex: "#444444"))
                }
            }

            Spacer()

            // Unequip
            if equipped != nil {
                Button("×") {
                    state.equipment.removeValue(forKey: slot)
                    state.applyEquipment()
                    AudioEngine.shared.play(.equip)
                    HapticEngine.light()
                }
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#884444"))
            }
        }
        .padding(10)
        .background(Color(hex: "#0d0d0d"))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(
            equipped != nil ? Color(hex: "#334455") : Color(hex: "#222222"), lineWidth: 1))
        .cornerRadius(6)
    }

    private func statView(_ label: String, _ value: String) -> some View {
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

