import Foundation

enum SaveManager {
    private static let saveKey = "OkamiRPG_save"

    static func save(_ state: GameState) {
        guard !state.isDead && !state.isVictory else { return }
        guard !state.cls.isEmpty && !state.map.isEmpty else { return }
        let snap = SaveSnapshot(state: state)
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    static func load(into state: GameState) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let snap = try? JSONDecoder().decode(SaveSnapshot.self, from: data) else { return false }
        guard !snap.cls.isEmpty && snap.map.count == GRID_H && snap.seen.count == GRID_H else {
            deleteSave()
            return false
        }
        snap.apply(to: state)
        computeVision(state: state)
        return true
    }

    static func deleteSave() {
        UserDefaults.standard.removeObject(forKey: saveKey)
    }

    static var hasSave: Bool {
        UserDefaults.standard.data(forKey: saveKey) != nil
    }
}

// MARK: — Snapshot (Codable subset of GameState)

private struct SaveSnapshot: Codable {
    let floor: Int
    let gold: Int
    let kills: Int
    let steps: Int
    let runGold: Int
    let runFloors: Int
    let runSteps: Int
    let cls: String
    let player: PlayerState
    let equipment: [String: String]
    let relics: [String]
    let curses: [CurseData]
    let skills: [SkillData]
    let flags: GameFlags
    let map: [[Tile]]
    let rooms: [RoomRect]
    let doors: [Point]
    let stairsPos: Point
    let enemies: [Enemy]
    let items: [GameItem]
    let traps: [TrapData]
    let torches: [TorchData]
    let shopItems: [ShopItem]
    let seen: [[Bool]]
    let hasShop: Bool
    let hasAltar: Bool
    let altarUsed: Bool

    init(state: GameState) {
        floor = state.floor; gold = state.gold; kills = state.kills
        steps = state.steps; runGold = state.runGold; runFloors = state.runFloors; runSteps = state.runSteps
        cls = state.cls; player = state.player; equipment = state.equipment
        relics = state.relics; curses = state.curses; skills = state.skills
        flags = state.flags; map = state.map; rooms = state.rooms; doors = state.doors
        stairsPos = state.stairsPos; enemies = state.enemies; items = state.items
        traps = state.traps; torches = state.torches; shopItems = state.shopItems
        seen = state.seen; hasShop = state.hasShop; hasAltar = state.hasAltar
        altarUsed = state.altarUsed
    }

    func apply(to state: GameState) {
        state.floor = floor; state.gold = gold; state.kills = kills
        state.steps = steps; state.runGold = runGold; state.runFloors = runFloors; state.runSteps = runSteps
        state.cls = cls; state.player = player; state.equipment = equipment
        state.relics = relics; state.curses = curses; state.skills = skills
        state.flags = flags; state.map = map; state.rooms = rooms; state.doors = doors
        state.stairsPos = stairsPos; state.enemies = enemies; state.items = items
        state.traps = traps; state.torches = torches; state.shopItems = shopItems
        state.seen = seen; state.hasShop = hasShop; state.hasAltar = hasAltar
        state.altarUsed = altarUsed
        state.vis = Array(repeating: Array(repeating: false, count: GRID_W), count: GRID_H)
        state.screen = .playing
        state.sceneNeedsRebuild = true
    }
}
