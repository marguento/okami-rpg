import Foundation

// MARK: — Skill

struct SkillData: Codable, Identifiable {
    let id: String
    let name: String
    let key: String
    let icon: String
    let cd: Int
    var cur: Int = 0
}

// MARK: — Hero class

struct HeroClass: Identifiable {
    let id: String
    let name: String
    let color: String
    let hp: Int
    let atk: Int
    let def: Int
    let crit: Double
    let spell: Int
    let gold: Int
    let classDesc: String
    let stats: String
    let skills: [SkillData]
}

let ALL_CLASSES: [String: HeroClass] = [
    "warrior": HeroClass(
        id: "warrior", name: "Paladin", color: "#e8c870",
        hp: 30, atk: 5, def: 3, crit: 0.10, spell: 0, gold: 12,
        classDesc: "Tank. High DEF and HP.", stats: "HP 30·ATK 5·DEF 3",
        skills: [
            SkillData(id: "brutalStrike", name: "Strike",  key: "Q", icon: "💥", cd: 4),
            SkillData(id: "fortify",      name: "Fortify", key: "W", icon: "🛡️", cd: 5),
            SkillData(id: "warcry",       name: "Warcry",  key: "E", icon: "📣", cd: 6),
        ]
    ),
    "mage": HeroClass(
        id: "mage", name: "Arcanist", color: "#7a8ee8",
        hp: 14, atk: 2, def: 0, crit: 0.10, spell: 14, gold: 12,
        classDesc: "Deadly spells. Fragile.", stats: "HP 14·ATK 2·SPELL 14",
        skills: [
            SkillData(id: "fireball",  name: "Fire",      key: "Q", icon: "🔥", cd: 4),
            SkillData(id: "freeze",    name: "Ice",       key: "W", icon: "❄️", cd: 3),
            SkillData(id: "lightning", name: "Lightning", key: "E", icon: "⚡", cd: 5),
        ]
    ),
    "rogue": HeroClass(
        id: "rogue", name: "Hunter", color: "#70e870",
        hp: 22, atk: 4, def: 0, crit: 0.35, spell: 0, gold: 12,
        classDesc: "Crits. Detects secrets.", stats: "HP 22·ATK 4·CRIT 35%",
        skills: [
            SkillData(id: "poison", name: "Poison", key: "Q", icon: "☠️", cd: 3),
            SkillData(id: "shadow", name: "Shadow", key: "W", icon: "🌑", cd: 5),
            SkillData(id: "ambush", name: "Ambush", key: "E", icon: "🎯", cd: 6),
        ]
    ),
]

// MARK: — Equipment

struct EquipItem: Codable, Identifiable {
    let id: String
    let slot: String
    let name: String
    let icon: String
    var atk: Int = 0
    var def: Int = 0
    var spell: Int = 0
    var hp: Int = 0
    var crit: Double = 0
    let desc: String
}

let EQUIP_SLOTS = ["weapon", "shield", "helmet", "chest", "legs", "amulet", "ring"]

let ALL_EQUIP: [EquipItem] = [
    EquipItem(id: "rusty_sword",    slot: "weapon", name: "Rusted Sword",    icon: "🗡️", atk: 3, desc: "+3 ATK"),
    EquipItem(id: "holy_blade",     slot: "weapon", name: "Holy Blade",      icon: "⚔️", atk: 6, desc: "+6 ATK"),
    EquipItem(id: "death_reaper",   slot: "weapon", name: "Death Reaper",    icon: "🔪", atk: 10, desc: "+10 ATK"),
    EquipItem(id: "arcane_staff",   slot: "weapon", name: "Arcane Staff",    icon: "🪄", spell: 7, desc: "+7 SPELL"),
    EquipItem(id: "death_staff",    slot: "weapon", name: "Necrotic Staff",  icon: "💫", spell: 12, desc: "+12 SPELL"),
    EquipItem(id: "shadow_dagger",  slot: "weapon", name: "Shadow Dagger",   icon: "🔱", atk: 5, crit: 0.10, desc: "+5ATK +10%Crit"),
    EquipItem(id: "wooden_shield",  slot: "shield", name: "Wooden Shield",   icon: "🪵", def: 1, desc: "+1 DEF"),
    EquipItem(id: "iron_shield",    slot: "shield", name: "Iron Shield",     icon: "🛡️", def: 3, desc: "+3 DEF"),
    EquipItem(id: "sacred_shield",  slot: "shield", name: "Sacred Shield",   icon: "✝️", def: 5, hp: 3, desc: "+5DEF +3HP"),
    EquipItem(id: "leather_helm",   slot: "helmet", name: "Leather Helm",    icon: "🪖", def: 1, desc: "+1 DEF"),
    EquipItem(id: "iron_helm",      slot: "helmet", name: "Iron Helm",       icon: "⛑️", def: 2, hp: 3, desc: "+2DEF +3HP"),
    EquipItem(id: "death_crown",    slot: "helmet", name: "Death Crown",     icon: "👑", spell: 4, crit: 0.05, desc: "+4SPELL +5%Crit"),
    EquipItem(id: "light_mail",     slot: "chest",  name: "Light Mail",      icon: "🥋", def: 2, desc: "+2 DEF"),
    EquipItem(id: "chain_mail",     slot: "chest",  name: "Chain Mail",      icon: "🧥", def: 3, hp: 4, desc: "+3DEF +4HP"),
    EquipItem(id: "sacred_plate",   slot: "chest",  name: "Sacred Plate",    icon: "🔶", def: 5, hp: 8, desc: "+5DEF +8HP"),
    EquipItem(id: "necro_robe",     slot: "chest",  name: "Necro Robe",      icon: "👘", def: 1, spell: 5, desc: "+1DEF +5SPELL"),
    EquipItem(id: "leather_legs",   slot: "legs",   name: "Leather Greaves", icon: "🩱", def: 1, desc: "+1 DEF"),
    EquipItem(id: "iron_legs",      slot: "legs",   name: "Iron Greaves",    icon: "👖", def: 2, hp: 2, desc: "+2DEF +2HP"),
    EquipItem(id: "swift_legs",     slot: "legs",   name: "Swift Boots",     icon: "👢", def: 1, crit: 0.05, desc: "+1DEF +5%Crit"),
    EquipItem(id: "bone_amulet",    slot: "amulet", name: "Bone Amulet",     icon: "📿", atk: 2, spell: 2, desc: "+2ATK +2SPELL"),
    EquipItem(id: "blood_amulet",   slot: "amulet", name: "Blood Amulet",    icon: "🩸", hp: 8, desc: "+8 MaxHP"),
    EquipItem(id: "ossuary_amulet", slot: "amulet", name: "Ossuary Amulet",  icon: "💀", def: 1, spell: 5, desc: "+5SPELL +1DEF"),
    EquipItem(id: "life_ring",      slot: "ring",   name: "Life Ring",       icon: "💚", hp: 10, desc: "+10 MaxHP"),
    EquipItem(id: "blood_ring",     slot: "ring",   name: "Blood Ring",      icon: "❤️", atk: 2, crit: 0.15, desc: "+15%Crit +2ATK"),
    EquipItem(id: "shadow_ring",    slot: "ring",   name: "Shadow Ring",     icon: "🌑", atk: 3, crit: 0.08, desc: "+3ATK +8%Crit"),
]

// MARK: — Enemies

struct EnemyTemplate {
    let id: String
    var name: String { id.replacingOccurrences(of: "_", with: " ").capitalized }
    let char: String
    let color: String
    let hp: Int
    let atk: Int
    let xp: Int
    let goldMin: Int
    let goldMax: Int
    var ranged: Bool = false
    var projColor: String = "#ffffff"
    var projSpeed: CGFloat = 1.5
    var projDmg: Int = 2
    var drop: String? = nil
    var isGargoyle: Bool = false
    var slow: Bool = false
    var drainHP: Bool = false
    var invisible: Bool = false
    var paralyzesOnHit: Bool = false
    var keepDistance: Bool = false
    var isBoss: Bool = false
}

let ENEMY_TEMPLATES: [String: EnemyTemplate] = [
    "skeleton":        EnemyTemplate(id: "skeleton",        char: "s", color: "#9a9a8a", hp: 10,  atk: 3,  xp: 3,   goldMin: 0,  goldMax: 3),
    "zombie":          EnemyTemplate(id: "zombie",          char: "z", color: "#5a7a3a", hp: 18,  atk: 5,  xp: 8,   goldMin: 1,  goldMax: 4,  drop: "potion"),
    "ghost":           EnemyTemplate(id: "ghost",           char: "G", color: "#8888cc", hp: 12,  atk: 3,  xp: 7,   goldMin: 0,  goldMax: 2,  ranged: true, projColor: "#9999ee", projSpeed: 1.5, projDmg: 2),
    "lich":            EnemyTemplate(id: "lich",            char: "L", color: "#cc8800", hp: 26,  atk: 7,  xp: 18,  goldMin: 2,  goldMax: 6,  ranged: true, projColor: "#ffcc00", projSpeed: 1.8, projDmg: 3, drop: "scroll"),
    "wraith":          EnemyTemplate(id: "wraith",          char: "W", color: "#cc44cc", hp: 20,  atk: 6,  xp: 14,  goldMin: 1,  goldMax: 4,  ranged: true, projColor: "#ee55ee", projSpeed: 2.0, projDmg: 3),
    "bone_giant":      EnemyTemplate(id: "bone_giant",      char: "B", color: "#aaaaaa", hp: 40,  atk: 9,  xp: 22,  goldMin: 3,  goldMax: 8,  drop: "potion"),
    "death_knight":    EnemyTemplate(id: "death_knight",    char: "K", color: "#4444cc", hp: 34,  atk: 11, xp: 26,  goldMin: 3,  goldMax: 9,  drop: "scroll"),
    "gargoyle":        EnemyTemplate(id: "gargoyle",        char: "R", color: "#888888", hp: 22,  atk: 0,  xp: 12,  goldMin: 2,  goldMax: 5,  projColor: "#aaaaaa", projSpeed: 2.2, projDmg: 3, isGargoyle: true),
    "banshee":         EnemyTemplate(id: "banshee",         char: "N", color: "#44ffaa", hp: 14,  atk: 4,  xp: 10,  goldMin: 1,  goldMax: 4,  ranged: true, projColor: "#44ffaa", projSpeed: 1.6, projDmg: 2, paralyzesOnHit: true),
    "skeleton_archer": EnemyTemplate(id: "skeleton_archer", char: "A", color: "#bbbb88", hp: 8,   atk: 3,  xp: 6,   goldMin: 0,  goldMax: 3,  ranged: true, projColor: "#ddddaa", projSpeed: 2.8, projDmg: 2, keepDistance: true),
    "bone_golem":      EnemyTemplate(id: "bone_golem",      char: "O", color: "#ccccaa", hp: 55,  atk: 12, xp: 30,  goldMin: 4,  goldMax: 10, drop: "potion", slow: true),
    "vampire":         EnemyTemplate(id: "vampire",         char: "V", color: "#cc2244", hp: 18,  atk: 7,  xp: 16,  goldMin: 2,  goldMax: 6,  drainHP: true),
    "shadow":          EnemyTemplate(id: "shadow",          char: "X", color: "#443366", hp: 16,  atk: 8,  xp: 18,  goldMin: 2,  goldMax: 5,  invisible: true),
    "bone_mage":       EnemyTemplate(id: "bone_mage",       char: "C", color: "#cc6600", hp: 20,  atk: 6,  xp: 14,  goldMin: 2,  goldMax: 5,  ranged: true, projColor: "#ff8800", projSpeed: 1.7, projDmg: 3),
    "marguento":       EnemyTemplate(id: "marguento",       char: "M", color: "#cc0000", hp: 160, atk: 16, xp: 150, goldMin: 10, goldMax: 25, ranged: true, projColor: "#ff3300", projSpeed: 1.4, projDmg: 5, drop: "relic", isBoss: true),
]

// MARK: — Curses

struct CurseData: Codable, Identifiable {
    let id: String
    let icon: String
    let name: String
    let desc: String
}

let ALL_CURSES: [CurseData] = [
    CurseData(id: "fragile",    icon: "💔", name: "Fragile",     desc: "Max HP -6 this floor"),
    CurseData(id: "clumsy",     icon: "🌀", name: "Clumsy",      desc: "25% miss chance this floor"),
    CurseData(id: "hungry",     icon: "🦴", name: "Dark Hunger", desc: "-1HP every 5 steps this floor"),
    CurseData(id: "fog",        icon: "🌫️", name: "Blind Fog",   desc: "Vision reduced to 4 tiles this floor"),
    CurseData(id: "cursedgold", icon: "🪙", name: "Cursed Gold", desc: "Items cost +4 gold this floor"),
    CurseData(id: "weakened",   icon: "💢", name: "Weakened",    desc: "ATK-2 and SPELL-2 this floor"),
]

// MARK: — Relics

struct RelicData: Identifiable {
    let id: String
    let icon: String
    let name: String
    let desc: String
}

let ALL_RELICS: [RelicData] = [
    RelicData(id: "vampirism",  icon: "🩸", name: "Vampirism",    desc: "+1HP per kill"),
    RelicData(id: "berserker",  icon: "😤", name: "Berserker",    desc: "+1ATK per kill"),
    RelicData(id: "arcane",     icon: "✨", name: "Arcane Power", desc: "Spell+5"),
    RelicData(id: "quickfeet",  icon: "👟", name: "Quick Feet",   desc: "+1HP/10steps"),
    RelicData(id: "goldlust",   icon: "🏆", name: "Gold Lust",    desc: "Gold drops x2"),
    RelicData(id: "sharpedge",  icon: "🗡️", name: "Holy Edge",    desc: "+3ATK"),
    RelicData(id: "toughskin",  icon: "🪨", name: "Stone Skin",   desc: "+2DEF"),
    RelicData(id: "critring",   icon: "💍", name: "Crit Ring",    desc: "Crit+15%"),
    RelicData(id: "xpboost",    icon: "📚", name: "Grimoire",     desc: "XP x1.5"),
    RelicData(id: "phoenix",    icon: "🦅", name: "Phoenix",      desc: "Revive once at 8HP"),
    RelicData(id: "trapmaster", icon: "🕸️", name: "Trap Master",  desc: "Immune to traps"),
    RelicData(id: "ghoststep",  icon: "👻", name: "Ghost Step",   desc: "Shadow skips traps"),
    RelicData(id: "deflect",    icon: "🔰", name: "Deflect",      desc: "30% block projectiles"),
    RelicData(id: "seeker",     icon: "🔍", name: "Seeker",       desc: "Secret rooms on minimap"),
]

func relicById(_ id: String) -> RelicData? { ALL_RELICS.first { $0.id == id } }
func equipById(_ id: String) -> EquipItem? { ALL_EQUIP.first { $0.id == id } }
func curseById(_ id: String) -> CurseData? { ALL_CURSES.first { $0.id == id } }
