import Foundation

// MARK: — Grid
let GRID_W = 23
let GRID_H = 14
let TILE_SIZE: CGFloat = 48
let MAX_FLOORS = 12
let HERO_NAME = "Valois Belloaris"

// MARK: — Tile
enum Tile: Int, Codable {
    case wall = 0, floor = 1, stairs = 2, shop = 3, altar = 4, secret = 5, door = 6, doorOpen = 7
}

// MARK: — Floor names & colors
let FLOOR_NAMES = [
    "", "Catacomb Entrance", "Ancient Crypts", "The Ossuary",
    "Chamber of the Dead", "Bone Halls", "Abyss of Shadows",
    "Necromancer's Keep", "Margüento's Cemetery", "Abyssal Tombs",
    "Realm of the Damned", "Gates of Eternity", "Margüento's Throne"
]

let FLOOR_HEX = [
    "", "#0d0d18", "#0e0d10", "#0b0d14", "#110a0a", "#0e0b12",
    "#090d16", "#0c0c0a", "#070e07", "#060810", "#080608", "#060606", "#040a04"
]

func floorBgHex(_ f: Int) -> String { FLOOR_HEX[min(f, MAX_FLOORS)] }

// MARK: — Narration
let NARRATIONS = [
    "\"Something moves in the walls.\"",
    "A previous adventurer's boots. Still warm.",
    "The air here smells of old graves.",
    "Margüento's laughter echoes from below.",
    "Runes pulse blood-red as you pass.",
    "A skull rolls across the floor on its own.",
    "You find a note: \"Turn back.\" The ink is wet.",
    "The darkness breathes here. Slowly."
]

// MARK: — Boss lines
let BOSS_LINES = [
    "\"Valois Belloaris... abandon all hope.\"",
    "\"Your bones shall join my collection.\"",
    "\"You cannot destroy what has already died.\"",
    "\"Every hero before you rests here.\"",
    "\"Your light ends here, in my darkness.\""
]

let BOSS_PHASE2_LINES = ["\"Rise, my children!\"", "\"The dead answer!\""]
let BOSS_PHASE3_LINES = ["\"DEATH NOVA!\"", "\"Your flesh burns!\""]
let BOSS_PHASE4_LINES = ["\"I AM ETERNAL!\"", "\"Witness my final form!\""]

// MARK: — Enemy floor pools
let ENEMY_POOLS: [Int: [String]] = [
    1:  ["skeleton"],
    2:  ["skeleton", "zombie"],
    3:  ["zombie", "ghost", "skeleton_archer"],
    4:  ["ghost", "lich", "skeleton_archer", "gargoyle"],
    5:  ["lich", "wraith", "banshee", "gargoyle"],
    6:  ["wraith", "bone_giant", "bone_golem", "vampire", "gargoyle"],
    7:  ["wraith", "bone_golem", "death_knight", "vampire"],
    8:  ["bone_giant", "bone_golem", "death_knight", "bone_mage", "shadow"],
    9:  ["bone_golem", "death_knight", "bone_mage", "shadow"],
    10: ["death_knight", "bone_mage", "shadow"],
    11: ["bone_mage", "shadow"],
    12: ["death_knight"]
]

// MARK: — Log message types
enum LogType: String { case normal, combat, spell, curse, trap, narr, info }

// MARK: — Trap types
enum TrapType: String, Codable, CaseIterable {
    case spike, gas, arrow, teleport, proximity_spike, chain
    var earlyFloorOnly: Bool { self == .teleport || self == .chain || self == .proximity_spike }
}

func availableTraps(floor: Int) -> [TrapType] {
    if floor <= 2 { return [.spike, .gas] }
    if floor <= 5 { return [.spike, .gas, .arrow, .proximity_spike] }
    return TrapType.allCases
}
