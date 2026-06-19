import SwiftUI

enum ShopMode { case shop, altar }

struct ShopAltarView: View {
    @Environment(GameState.self) var state
    let mode: ShopMode

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Divider().background(Color.gray.opacity(0.3))
                ScrollView { content.padding(16) }
            }
        }
    }

    // MARK: — Header

    private var header: some View {
        HStack {
            Text(mode == .shop ? "Merchant" : "Dark Altar")
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundColor(mode == .shop ? Color(hex: "#cccc44") : Color(hex: "#cc0000"))
            Spacer()
            if mode == .shop {
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#cccc44"))
                    Text("\(state.gold)")
                        .font(.system(.body, design: .monospaced).weight(.bold))
                        .foregroundColor(Color(hex: "#cccc44"))
                }
            }
            Button("Leave") {
                HapticEngine.light()
                state.screen = .playing
            }
            .foregroundColor(Color(hex: "#888888"))
            .font(.system(.body, design: .monospaced))
            .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: — Content

    @ViewBuilder
    private var content: some View {
        if mode == .shop {
            shopContent
        } else {
            altarContent
        }
    }

    private var shopContent: some View {
        VStack(spacing: 10) {
            ForEach(state.shopItems) { item in
                shopRow(item)
            }
            if state.shopItems.isEmpty {
                Text("Sold out!")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
    }

    private func shopRow(_ item: ShopItem) -> some View {
        let canAfford = state.gold >= item.price
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.label)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundColor(canAfford ? .white : .gray)
                Text(item.desc)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: "#888888"))
            }
            Spacer()
            Button {
                buyItem(item)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(canAfford ? Color(hex: "#cccc44") : .gray)
                    Text("\(item.price)")
                        .font(.system(.body, design: .monospaced).weight(.bold))
                        .foregroundColor(canAfford ? Color(hex: "#cccc44") : .gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(canAfford ? Color(hex: "#1a1a00") : Color(hex: "#111111"))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                    canAfford ? Color(hex: "#666600") : Color.gray.opacity(0.3), lineWidth: 1))
                .cornerRadius(6)
            }
            .disabled(!canAfford)
        }
        .padding(12)
        .background(Color(hex: "#0d0d0d"))
        .cornerRadius(8)
    }

    private var altarContent: some View {
        VStack(spacing: 12) {
            Text("Sacrifice your blood for power. Choose wisely.")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Color(hex: "#888888"))
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            let options = [
                ("Blood Pact", "Pay 8HP — Gain a random Relic", 0),
                ("Steal Power", "Pay 6HP — ATK+3", 1),
                ("Dark Bargain", "Gain Relic — Next floor cursed", 2),
            ]

            ForEach(options, id: \.2) { opt in
                altarOption(label: opt.0, desc: opt.1, index: opt.2)
            }

            if state.altarUsed {
                Text("The altar is spent.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
        }
    }

    private func altarOption(label: String, desc: String, index: Int) -> some View {
        Button {
            openAltarOption(state: state, option: index)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .foregroundColor(Color(hex: "#cc4444"))
                    Text(desc)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "#888888"))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(hex: "#444444"))
            }
            .padding(14)
            .background(Color(hex: "#0d0d0d"))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#441111"), lineWidth: 1))
            .cornerRadius(8)
        }
        .disabled(state.altarUsed)
        .opacity(state.altarUsed ? 0.4 : 1.0)
    }

    // MARK: — Buy logic

    private func buyItem(_ item: ShopItem) {
        guard state.gold >= item.price else { return }
        state.gold -= item.price
        AudioEngine.shared.play(.goldDrop); HapticEngine.medium()

        switch item.type {
        case "potion":
            let heal = 8 + state.floor * 2
            state.player.hp = min(state.player.maxHp, state.player.hp + heal)
            state.addLog("Potion: +\(heal)HP", .normal)
        case "elixir":
            state.player.bonusMaxHp += 5
            state.applyEquipment()
            state.addLog("Elixir: MaxHP+5", .normal)
        case "weapon":
            state.player.bonusAtk += 3; state.player.bonusSpell += 3
            state.applyEquipment()
            state.addLog("Weapon upgrade: ATK+3, SPELL+3", .normal)
        case "armor":
            state.player.bonusDef += 2
            state.applyEquipment()
            state.addLog("Armor upgrade: DEF+2", .normal)
        case "relic":
            if let rid = item.relicId { state.applyRelic(rid) }
        case "equip":
            if let eid = item.equipId, let eq = equipById(eid) { equipItem(state: state, eq: eq) }
        default: break
        }

        // Remove from shop
        state.shopItems.removeAll { $0.uid == item.uid }
    }
}
