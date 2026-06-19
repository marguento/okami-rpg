import Foundation

// MARK: — BSP Map Generator

struct BSPRect {
    var x, y, w, h: Int
}

func bspSplit(_ rect: BSPRect, depth: Int, rooms: inout [RoomRect]) {
    if depth == 0 || rect.w < 8 || rect.h < 7 {
        rooms.append(RoomRect(x: rect.x, y: rect.y, w: rect.w, h: rect.h))
        return
    }
    let horizontal = rect.w < rect.h ? true : rect.h < rect.w ? false : Bool.random()
    if horizontal {
        let minS = Int(Double(rect.h) * 0.36)
        let maxS = Int(Double(rect.h) * 0.64)
        guard minS < maxS else { rooms.append(RoomRect(x: rect.x, y: rect.y, w: rect.w, h: rect.h)); return }
        let s = Int.random(in: minS...maxS)
        bspSplit(BSPRect(x: rect.x, y: rect.y,     w: rect.w, h: s),         depth: depth - 1, rooms: &rooms)
        bspSplit(BSPRect(x: rect.x, y: rect.y + s, w: rect.w, h: rect.h - s),depth: depth - 1, rooms: &rooms)
    } else {
        let minS = Int(Double(rect.w) * 0.36)
        let maxS = Int(Double(rect.w) * 0.64)
        guard minS < maxS else { rooms.append(RoomRect(x: rect.x, y: rect.y, w: rect.w, h: rect.h)); return }
        let s = Int.random(in: minS...maxS)
        bspSplit(BSPRect(x: rect.x,     y: rect.y, w: s,         h: rect.h), depth: depth - 1, rooms: &rooms)
        bspSplit(BSPRect(x: rect.x + s, y: rect.y, w: rect.w - s, h: rect.h),depth: depth - 1, rooms: &rooms)
    }
}

func generateFloor(state: GameState) {
    var map = Array(repeating: Array(repeating: Tile.wall, count: GRID_W), count: GRID_H)
    var rooms: [RoomRect] = []
    var leaves: [RoomRect] = []
    bspSplit(BSPRect(x: 0, y: 0, w: GRID_W, h: GRID_H), depth: 3, rooms: &leaves)

    for leaf in leaves {
        let szD = Int.random(in: 1...4)
        let mg = szD == 1 ? 2 : 1
        let extra = szD == 1 ? Int.random(in: 1...2) : szD <= 3 ? Int.random(in: 0...1) : 0
        let rx = leaf.x + mg; let ry = leaf.y + mg
        let rw = max(3, leaf.w - mg * 2 - extra)
        let rh = max(3, leaf.h - mg * 2 - extra)
        guard rx + rw < GRID_W, ry + rh < GRID_H else { continue }
        for yy in ry..<(ry + rh) { for xx in rx..<(rx + rw) { map[yy][xx] = .floor } }
        rooms.append(RoomRect(x: rx, y: ry, w: rw, h: rh, size: szD))
    }
    guard rooms.count >= 3 else { generateFloor(state: state); return }

    // Floor 12: inject a guaranteed large central arena for the boss fight
    if state.floor == MAX_FLOORS {
        let cx = GRID_W / 2 - 4; let cy = GRID_H / 2 - 3
        let bw = 9; let bh = 7
        for yy in cy..<cy+bh { for xx in cx..<cx+bw {
            if yy > 0, xx > 0, yy < GRID_H-1, xx < GRID_W-1 { map[yy][xx] = .floor }
        }}
        let bossRoom = RoomRect(x: cx, y: cy, w: bw, h: bh, size: 4)
        rooms.append(bossRoom)
        // Connect to nearest existing room
        if let near = rooms.dropLast().min(by: { abs($0.cx - bossRoom.cx) + abs($0.cy - bossRoom.cy) < abs($1.cx - bossRoom.cx) + abs($1.cy - bossRoom.cy) }) {
            var x1 = near.cx; let y1 = near.cy
            let x2 = bossRoom.cx; let y2 = bossRoom.cy
            while x1 != x2 { map[y1][x1] = .floor; x1 += x1 < x2 ? 1 : -1 }
            var yy = min(y1, y2); while yy <= max(y1, y2) { map[yy][x2] = .floor; yy += 1 }
        }
    }

    var doors: [Point] = []
    let shuffled = rooms.shuffled()
    for i in 1..<shuffled.count {
        var x1 = shuffled[i-1].cx; var y1 = shuffled[i-1].cy
        let x2 = shuffled[i].cx;   let y2 = shuffled[i].cy
        let dx = x1 < x2 ? 1 : -1
        let dy = y1 < y2 ? 1 : -1
        var doorPlaced = false
        if Bool.random() {
            while x1 != x2 { map[y1][x1] = .floor; x1 += dx }
            while y1 != y2 {
                map[y1][x1] = .floor
                if !doorPlaced && Bool.random() && y1 != shuffled[i].cy {
                    map[y1][x1] = .door; doorPlaced = true; doors.append(Point(x: x1, y: y1))
                }
                y1 += dy
            }
        } else {
            while y1 != y2 { map[y1][x1] = .floor; y1 += dy }
            while x1 != x2 {
                map[y1][x1] = .floor
                if !doorPlaced && Bool.random() {
                    map[y1][x1] = .door; doorPlaced = true; doors.append(Point(x: x1, y: y1))
                }
                x1 += dx
            }
        }
    }

    // Stairs in last room, player in most central non-stairs room
    let sr = rooms.last!
    map[sr.cy][sr.cx] = .stairs
    state.stairsPos = Point(x: sr.cx, y: sr.cy)
    let mapCX = GRID_W / 2; let mapCY = GRID_H / 2
    let startRoom = rooms.dropLast().min(by: {
        abs($0.cx - mapCX) + abs($0.cy - mapCY) < abs($1.cx - mapCX) + abs($1.cy - mapCY)
    }) ?? rooms[0]
    state.player.x = startRoom.cx; state.player.y = startRoom.cy

    // Shop / altar tiles
    let mid = Array(rooms.dropFirst().dropLast())
    if state.hasShop, let r = mid.first { map[r.cy][r.cx] = .shop }
    if state.hasAltar, mid.count >= 2   { map[mid[mid.count / 2].cy][mid[mid.count / 2].cx] = .altar }

    // Secret rooms (1-2)
    for _ in 0..<Int.random(in: 1...2) {
        let base = rooms[Int.random(in: 1..<rooms.count - 1)]
        let dirs = [(1,0),(-1,0),(0,1),(0,-1)]
        let dir = dirs.randomElement()!
        let sx = base.cx + dir.0 * Int.random(in: 2...3)
        let sy = base.cy + dir.1 * Int.random(in: 2...3)
        guard sx > 1, sy > 1, sx < GRID_W - 2, sy < GRID_H - 2, map[sy][sx] == .wall else { continue }
        for dy in -1...1 { for dx in -1...1 {
            let nx = sx + dx; let ny = sy + dy
            if ny > 0 && nx > 0 && ny < GRID_H - 1 && nx < GRID_W - 1 { map[ny][nx] = .secret }
        }}
    }

    // Widen 1-tile corridors → 2 tiles wide for easier navigation.
    // Doors also span both tiles so they can't be walked around.
    let prewiden = map
    var wideDoors: [Point] = []
    for y in 1..<GRID_H - 2 {
        for x in 1..<GRID_W - 2 {
            let t = prewiden[y][x]
            guard t == .floor || t == .door else { continue }
            // Horizontal corridor (wall above AND below) → widen downward
            if prewiden[y-1][x] == .wall && prewiden[y+1][x] == .wall {
                map[y+1][x] = (t == .door) ? .door : .floor
                if t == .door { wideDoors.append(Point(x: x, y: y+1)) }
            }
            // Vertical corridor (wall left AND right) → widen rightward
            if prewiden[y][x-1] == .wall && prewiden[y][x+1] == .wall {
                map[y][x+1] = (t == .door) ? .door : .floor
                if t == .door { wideDoors.append(Point(x: x+1, y: y)) }
            }
        }
    }
    doors.append(contentsOf: wideDoors)

    state.map = map; state.rooms = rooms; state.doors = doors
    state.vis  = Array(repeating: Array(repeating: false, count: GRID_W), count: GRID_H)
    state.seen = Array(repeating: Array(repeating: false, count: GRID_W), count: GRID_H)

    placeTorches(state: state, rooms: rooms, map: map)
    placeTraps(state: state, rooms: rooms, map: map)
    placeEnemies(state: state, rooms: rooms, map: map)
    placeSecretLoot(state: state, map: map)
    buildShopItems(state: state)
    state.altarUsed = false
    state.projectiles = []
    state.sceneNeedsRebuild = true
    AudioEngine.shared.startMusic(floor: state.floor)
    SaveManager.save(state)
}

private func placeTorches(state: GameState, rooms: [RoomRect], map: [[Tile]]) {
    var torches: [TorchData] = []
    for r in rooms {
        var spots = [(r.x, r.y), (r.x + r.w - 1, r.y), (r.x, r.y + r.h - 1), (r.x + r.w - 1, r.y + r.h - 1)]
        if r.w > 3 { spots += [(r.cx, r.y), (r.cx, r.y + r.h - 1)] }
        if r.h > 3 { spots += [(r.x, r.cy), (r.x + r.w - 1, r.cy)] }
        let max = r.size >= 4 ? 4 : r.size >= 2 ? 2 : 1
        var placed = 0
        for sp in spots {
            guard placed < max else { break }
            if sp.0 >= 0, sp.1 >= 0, sp.0 < GRID_W, sp.1 < GRID_H, map[sp.1][sp.0] == .floor {
                torches.append(TorchData(x: sp.0, y: sp.1, flicker: Double.random(in: 0...(.pi * 2)), speed: Double.random(in: 0.018...0.043)))
                placed += 1
            }
        }
    }
    state.torches = torches
}

private func placeTraps(state: GameState, rooms: [RoomRect], map: [[Tile]]) {
    let count = Int.random(in: 1...(1 + max(1, state.floor / 3)))
    let available = availableTraps(floor: state.floor)
    var newTraps: [TrapData] = []
    for _ in 0..<count {
        let r = rooms[Int.random(in: 1..<rooms.count)]
        let tx = Int.random(in: r.x..<(r.x + r.w))
        let ty = Int.random(in: r.y..<(r.y + r.h))
        guard map[ty][tx] == .floor else { continue }
        let type = available.randomElement()!
        newTraps.append(TrapData(uid: UUID(), type: type.rawValue, x: tx, y: ty))
    }
    state.traps = newTraps
}

private func placeEnemies(state: GameState, rooms: [RoomRect], map: [[Tile]]) {
    var enemies: [Enemy] = []
    var items: [GameItem] = []
    let pool = ENEMY_POOLS[min(state.floor, MAX_FLOORS)] ?? ["skeleton"]
    let scale = 1.0 + Double(state.floor - 1) * 0.14

    // Boss on floor 12 — placed in the boss arena (last room, injected by generateFloor)
    if state.floor == MAX_FLOORS {
        let bossRoom = rooms.last ?? rooms[max(0, rooms.count - 1)]
        enemies.append(Enemy(uid: UUID(), templateId: "marguento",
                             x: bossRoom.cx, y: bossRoom.cy,
                             hp: 160, maxHp: 160, atk: 16))
    }

    var placed = 0
    for i in 1..<rooms.count where placed < state.floorEnemyCount {
        let r = rooms[i]
        let t = map[r.cy][r.cx]
        guard t != .stairs && t != .shop && t != .altar && t != .secret else { continue }
        placed += 1
        let cnt = min(3, 1 + max(0, state.floor / 4))
        for _ in 0..<Int.random(in: 1...cnt) {
            guard let tid = pool.randomElement(), let tmpl = ENEMY_TEMPLATES[tid] else { continue }
            var ex = r.x; var ey = r.y
            var tries = 0
            repeat {
                ex = Int.random(in: r.x..<(r.x + r.w))
                ey = Int.random(in: r.y..<(r.y + r.h))
                tries += 1
            } while tries < 15 && (
                Point(x: ex, y: ey).distance(to: state.stairsPos) <= 2 ||
                Point(x: ex, y: ey).distance(to: Point(x: state.player.x, y: state.player.y)) <= 3 ||
                map[ey][ex] != .floor
            )
            guard map[ey][ex] == .floor else { continue }
            var enemy = Enemy(uid: UUID(), templateId: tid, x: ex, y: ey,
                              hp: Int(ceil(Double(tmpl.hp) * scale)),
                              maxHp: Int(ceil(Double(tmpl.hp) * scale)),
                              atk: Int(ceil(Double(tmpl.atk) * scale)))
            if tmpl.invisible { enemy.revealed = false }
            if tmpl.isGargoyle { enemy.shootTimer = Int.random(in: 1...2) }
            enemies.append(enemy)
        }
        // Random item drop chance
        if Double.random(in: 0...1) < 0.3 {
            let types = ["potion", "scroll", "gold"]
            let type = types.randomElement()!
            var gi = GameItem(uid: UUID(), type: type,
                              x: Int.random(in: r.x..<(r.x + r.w)),
                              y: Int.random(in: r.y..<(r.y + r.h)))
            if type == "gold" { gi.goldAmount = Int.random(in: 2...8); gi.identified = true }
            items.append(gi)
        }
    }
    state.enemies = enemies
    state.items = items
}

private func placeSecretLoot(state: GameState, map: [[Tile]]) {
    var secretTiles: [Point] = []
    for y in 0..<GRID_H { for x in 0..<GRID_W {
        if map[y][x] == .secret { secretTiles.append(Point(x: x, y: y)) }
    }}
    guard let pos = secretTiles.randomElement() else { return }
    let eq = ALL_EQUIP.randomElement()!
    state.items.append(GameItem(uid: UUID(), type: "equipment", x: pos.x, y: pos.y,
                                identified: true, equipId: eq.id))
}

func buildShopItems(state: GameState) {
    let floor = state.floor
    let extra = state.hasCurse("cursedgold") ? 4 : 0
    func p(_ base: Double) -> Int { Int(base) + extra }

    var shopItems: [ShopItem] = [
        ShopItem(uid: UUID(), label: "Potion",         desc: "+\(8 + floor * 2)HP",    price: p(2 + Double(floor) * 1.1),  type: "potion"),
        ShopItem(uid: UUID(), label: "Elixir",         desc: "+5 MaxHP",                price: p(2 + Double(floor) * 0.6),  type: "elixir"),
        ShopItem(uid: UUID(), label: "Weapon upgrade", desc: "+3 ATK/SPELL",            price: p(4 + Double(floor) * 1.7),  type: "weapon"),
        ShopItem(uid: UUID(), label: "Armor upgrade",  desc: "+2 DEF",                  price: p(3 + Double(floor) * 1.4),  type: "armor"),
    ]
    let availRelics = ALL_RELICS.filter { !state.hasRelic($0.id) }
    if let rel = availRelics.randomElement() {
        shopItems.append(ShopItem(uid: UUID(), label: rel.name, desc: rel.desc,
                                  price: p(5 + Double(floor) * 2.0), type: "relic", relicId: rel.id))
    }
    let usedEquip = Set(state.equipment.values)
    let availEquip = ALL_EQUIP.filter { !usedEquip.contains($0.id) }
    if let eq = availEquip.randomElement() {
        shopItems.append(ShopItem(uid: UUID(), label: eq.name, desc: eq.desc,
                                  price: p(5 + Double(floor) * 2.2), type: "equip", equipId: eq.id))
    }
    state.shopItems = shopItems
}
