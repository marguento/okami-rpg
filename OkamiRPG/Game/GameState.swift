import Foundation
import Observation

// MARK: — Supporting types

struct Point: Codable, Equatable, Hashable {
    var x: Int
    var y: Int
    func distance(to other: Point) -> Int { abs(x - other.x) + abs(y - other.y) }
}

struct GameFlags: Codable {
    var vampirism   = false
    var berserker   = false
    var quickfeet   = false
    var goldlust    = false
    var xpboost     = false
    var phoenix     = false
    var phoenixUsed = false
    var trapmaster  = false
    var ghoststep   = false
    var shadowActive = false
    var deflect     = false
    var seeker      = false
}

struct PlayerState: Codable {
    var x: Int = 1
    var y: Int = 1
    var hp: Int = 20
    var maxHp: Int = 20
    var atk: Int = 4
    var def: Int = 0
    var crit: Double = 0.10
    var spell: Int = 0
    var xp: Int = 0
    var xpNext: Int = 14
    var level: Int = 1
    var dodgeNext: Bool = false
    var fortifyTurns: Int = 0
    var stunned: Int = 0
    var brutalkStrike: Bool = false
    var ambushReady: Bool = false
    var poisonedTurns: Int = 0
    // Permanent stat bonuses (levels, scrolls, shop, relics) — survive applyEquipment
    var bonusAtk:   Int    = 0
    var bonusDef:   Int    = 0
    var bonusSpell: Int    = 0
    var bonusCrit:  Double = 0
    var bonusMaxHp: Int    = 0
}

struct Enemy: Codable, Identifiable {
    let uid: UUID
    var templateId: String
    var x: Int
    var y: Int
    var hp: Int
    var maxHp: Int
    var atk: Int
    var poisonedTurns: Int = 0
    var frozenTurns: Int = 0
    var stunTurns: Int = 0
    var revealed: Bool = true
    var moveCounter: Int = 0
    var shootTimer: Int = 0
    var phase: Int = 1           // boss only
    var talked: Bool = false
    var warcryDebuffTurns: Int = 0
    var warcryAtk: Int = 0       // saved original atk during warcry

    var id: UUID { uid }
    var template: EnemyTemplate { ENEMY_TEMPLATES[templateId] ?? ENEMY_TEMPLATES["skeleton"]! }
    var pos: Point { Point(x: x, y: y) }
}

struct GameItem: Codable, Identifiable {
    let uid: UUID
    var type: String        // "potion", "scroll", "gold", "equipment", "relic"
    var x: Int
    var y: Int
    var identified: Bool = true
    var equipId: String? = nil
    var relicId: String? = nil
    var goldAmount: Int = 0

    var id: UUID { uid }
    var pos: Point { Point(x: x, y: y) }
}

struct TrapData: Codable, Identifiable {
    let uid: UUID
    var type: String
    var x: Int
    var y: Int
    var triggered: Bool = false
    var revealed: Bool = false
    var warnTimer: Int = 0

    var id: UUID { uid }
    var pos: Point { Point(x: x, y: y) }
}

struct Projectile: Codable, Identifiable {
    let uid: UUID
    var px: CGFloat
    var py: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var color: String
    var dmg: Int
    var isPlayer: Bool
    var maxRange: CGFloat = 440
    var traveled: CGFloat = 0
    var paralyzes: Bool = false

    var id: UUID { uid }
}

struct TorchData: Codable {
    var x: Int
    var y: Int
    var flicker: Double = 0
    var speed: Double = 0.02
}

struct LogEntry: Identifiable {
    let id = UUID()
    var text: String
    var type: LogType
    var timer: Int = 520
}

struct ShopItem: Codable, Identifiable {
    let uid: UUID
    var label: String
    var desc: String
    var price: Int
    var sold: Bool = false
    var type: String
    var equipId: String? = nil
    var relicId: String? = nil

    var id: UUID { uid }
}

// MARK: — Screen state

enum GameScreen {
    case splash, classSelect, dante, rest, playing, equipment, shop, altar, death, victory, paused
}

// MARK: — GameState (@Observable)

@Observable
final class GameState {

    // Navigation
    var screen: GameScreen = .splash
    var selectedClass: String = ""

    // Floor / run
    var cls: String = ""
    var floor: Int = 1
    var kills: Int = 0
    var steps: Int = 0
    var gold: Int = 12
    var relics: [String] = []
    var curses: [CurseData] = []
    var pendingCurse: CurseData? = nil
    var flags: GameFlags = GameFlags()
    var equipment: [String: String] = [:]   // slot -> equipId
    var skills: [SkillData] = []

    // Map
    var map: [[Tile]] = []
    var vis: [[Bool]] = []
    var seen: [[Bool]] = []
    var rooms: [RoomRect] = []
    var doors: [Point] = []
    var stairsPos: Point = Point(x: 1, y: 1)
    var torches: [TorchData] = []

    // Entities
    var player: PlayerState = PlayerState()
    var enemies: [Enemy] = []
    var items: [GameItem] = []
    var traps: [TrapData] = []
    var projectiles: [Projectile] = []

    // Floor dice rolls
    var hasShop: Bool = false
    var hasAltar: Bool = false
    var altarUsed: Bool = false
    var floorEnemyCount: Int = 3
    var shopItems: [ShopItem] = []

    // UI state
    var log: [LogEntry] = []
    var banner: (text: String, color: String)? = nil
    var isDead: Bool = false
    var isVictory: Bool = false
    var deathCause: String = ""

    // Aim direction
    var aimDx: Int = 1
    var aimDy: Int = 0

    // Animation hint for scene
    var pendingDamageFloats: [(x: Int, y: Int, text: String, color: String)] = []
    var pendingFlashes: [(x: Int, y: Int, color: String)] = []
    var pendingEntityFlashUIDs:   [UUID]   = []   // entity hit flash targets
    var pendingEntityFlashColors: [String] = []   // corresponding overlay colors
    var pendingPlayerLunge: Point? = nil           // attack lunge direction (dx,dy as x,y)
    var sceneNeedsRebuild: Bool = false
    var levelUpPending: Bool = false
    var pendingPlayerHit: Bool = false
    var enemyTurnFlash: Bool = false
    var stairsPending: Bool = false

    // Run stats (for death/victory screen)
    var runFloors: Int = 1
    var runGold: Int = 0
    var runSteps: Int = 0

    // MARK: — Computed helpers

    func hasCurse(_ id: String) -> Bool { curses.contains { $0.id == id } }
    func hasRelic(_ id: String) -> Bool { relics.contains(id) }
    var playerPos: Point { Point(x: player.x, y: player.y) }
    var sightRadius: Int { hasCurse("fog") ? 3 : 5 }

    func enemy(at pos: Point) -> Enemy? {
        enemies.first { e in
            e.x == pos.x && e.y == pos.y && e.hp > 0 && (!e.template.invisible || e.revealed)
        }
    }
    func enemyReal(at pos: Point) -> Enemy? {
        enemies.first { $0.x == pos.x && $0.y == pos.y && $0.hp > 0 }
    }
    func item(at pos: Point) -> GameItem? {
        items.first { $0.x == pos.x && $0.y == pos.y }
    }
    func trap(at pos: Point) -> TrapData? {
        traps.first { $0.x == pos.x && $0.y == pos.y && !$0.triggered }
    }
    func isWalkable(_ pos: Point) -> Bool {
        guard pos.x >= 0, pos.y >= 0, pos.x < GRID_W, pos.y < GRID_H else { return false }
        let t = map[pos.y][pos.x]
        return t != .wall
    }
    func isVisible(_ pos: Point) -> Bool {
        guard pos.x >= 0, pos.y >= 0, pos.x < GRID_W, pos.y < GRID_H else { return false }
        return vis[pos.y][pos.x]
    }
    func isSeen(_ pos: Point) -> Bool {
        guard pos.x >= 0, pos.y >= 0, pos.x < GRID_W, pos.y < GRID_H else { return false }
        return seen[pos.y][pos.x]
    }

    // MARK: — Log

    func addLog(_ msg: String, _ type: LogType = .normal) {
        log.insert(LogEntry(text: msg, type: type), at: 0)
        if log.count > 80 { log.removeLast() }
    }

    func showBanner(_ text: String, color: String = "#c0a060") {
        banner = (text: text, color: color)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.banner = nil }
    }

    // MARK: — Start game

    func startGame(cls classId: String) {
        guard let heroClass = ALL_CLASSES[classId] else { return }
        self.cls = classId
        floor = 1; kills = 0; steps = 0; gold = heroClass.gold
        relics = []; curses = []; pendingCurse = nil
        flags = GameFlags()
        equipment = [:]
        skills = heroClass.skills.map { SkillData(id: $0.id, name: $0.name, key: $0.key, icon: $0.icon, cd: $0.cd) }
        isDead = false; isVictory = false; deathCause = ""
        runFloors = 1; runGold = 0; runSteps = 0
        pendingPlayerHit = false; enemyTurnFlash = false; stairsPending = false
        pendingEntityFlashUIDs = []; pendingEntityFlashColors = []; pendingPlayerLunge = nil

        player = PlayerState()
        player.hp = heroClass.hp; player.maxHp = heroClass.hp
        player.atk = heroClass.atk; player.def = heroClass.def
        player.crit = heroClass.crit; player.spell = heroClass.spell
        player.xp = 0; player.xpNext = 14; player.level = 1

        enemies = []; items = []; traps = []; projectiles = []
        log = []; banner = nil
        aimDx = 1; aimDy = 0
        hasShop = false; hasAltar = false; altarUsed = false
        floorEnemyCount = 3; shopItems = []

        sceneNeedsRebuild = true
        screen = .dante
    }

    // MARK: — Apply relic

    func applyRelic(_ relicId: String) {
        guard !relics.contains(relicId) else { return }
        relics.append(relicId)
        switch relicId {
        case "vampirism":  flags.vampirism  = true
        case "berserker":  flags.berserker  = true
        case "quickfeet":  flags.quickfeet  = true
        case "goldlust":   flags.goldlust   = true
        case "xpboost":    flags.xpboost    = true
        case "phoenix":    flags.phoenix    = true
        case "trapmaster": flags.trapmaster = true
        case "ghoststep":  flags.ghoststep  = true
        case "deflect":    flags.deflect    = true
        case "seeker":     flags.seeker     = true
        case "arcane":     player.bonusSpell += 5; applyEquipment()
        case "sharpedge":  player.bonusAtk += 3;   applyEquipment()
        case "toughskin":  player.bonusDef += 2;   applyEquipment()
        case "critring":   player.bonusCrit += 0.15; applyEquipment()
        default: break
        }
        addLog("Relic: \(relicById(relicId)?.name ?? relicId)", .spell)
        AudioEngine.shared.play(.relic)
    }

    // MARK: — Apply curse

    func applyCurseEffect(_ curse: CurseData) {
        addLog("Curse: \(curse.name)", .curse)
        applyEquipment()  // recalculates stats and applies all active curse penalties
    }

    // MARK: — Equipment

    func applyEquipment() {
        guard let heroClass = ALL_CLASSES[cls] else { return }
        player.atk   = heroClass.atk   + player.bonusAtk
        player.def   = heroClass.def   + player.bonusDef
        player.spell = heroClass.spell + player.bonusSpell
        player.crit  = heroClass.crit  + player.bonusCrit
        var equipBonusMaxHp = 0
        for (_, eid) in equipment {
            guard let eq = equipById(eid) else { continue }
            player.atk   += eq.atk
            player.def   += eq.def
            player.spell += eq.spell
            player.crit  += eq.crit
            equipBonusMaxHp += eq.hp
        }
        let oldMax = player.maxHp
        player.maxHp = heroClass.hp + equipBonusMaxHp + player.bonusMaxHp
        if player.maxHp > oldMax { player.hp += (player.maxHp - oldMax) }
        player.hp = min(player.hp, player.maxHp)
        // Re-apply active temporary buffs so they survive equipment changes
        if player.fortifyTurns > 0 { player.def += 4 }
        // Re-apply active curse stat penalties so they survive equipment changes
        for curse in curses {
            switch curse.id {
            case "fragile":
                player.maxHp = max(5, player.maxHp - 6)
                player.hp = min(player.hp, player.maxHp)
            case "weakened":
                player.atk   = max(1, player.atk - 2)
                player.spell = max(0, player.spell - 2)
            default: break
            }
        }
        if flags.seeker {
            for y in 0..<GRID_H { for x in 0..<GRID_W {
                if map.indices.contains(y) && map[y].indices.contains(x) && map[y][x] == .secret {
                    seen[y][x] = true
                }
            }}
        }
    }

    // MARK: — Level up

    func checkLevelUp() {
        while player.xp >= player.xpNext {
            player.xp -= player.xpNext
            player.level += 1
            player.xpNext = 14 + player.level * 8
            player.bonusMaxHp += 4
            switch cls {
            case "warrior": player.bonusDef += 1; player.bonusAtk += 1
            case "mage":    player.bonusSpell += 1; player.bonusAtk += 1
            case "rogue":   player.bonusCrit += 0.03; player.bonusAtk += 1
            default: player.bonusAtk += 1
            }
            levelUpPending = true
            addLog("Level \(player.level)! HP+4", .spell)
            AudioEngine.shared.play(.kill)
        }
        applyEquipment()
        if levelUpPending { showBanner("LEVEL \(player.level)!", color: "#ffcc44"); levelUpPending = false }
    }
}

// MARK: — RoomRect

struct RoomRect: Codable {
    var x: Int; var y: Int; var w: Int; var h: Int
    var cx: Int { x + w / 2 }
    var cy: Int { y + h / 2 }
    var size: Int = 2
}
