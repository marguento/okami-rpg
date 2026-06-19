import Foundation

// MARK: — Player movement

func movePlayer(state: GameState, dx: Int, dy: Int) {
    guard !state.isDead, !state.isVictory, !state.stairsPending else { return }
    guard state.player.stunned <= 0 else {
        state.player.stunned -= 1
        state.addLog("Stunned — cannot move", .combat)
        endPlayerTurn(state: state); return
    }

    let nx = state.player.x + dx
    let ny = state.player.y + dy
    let target = Point(x: nx, y: ny)

    guard nx >= 0, ny >= 0, nx < GRID_W, ny < GRID_H else { return }

    // Attack if enemy at target
    if let idx = state.enemies.firstIndex(where: { $0.x == nx && $0.y == ny && $0.hp > 0 }) {
        playerAttack(state: state, enemyIdx: idx)
        endPlayerTurn(state: state)
        return
    }

    let tile = state.map[ny][nx]
    guard tile != .wall else {
        // Visible flash at wall tile + bump animation on player sprite
        state.pendingFlashes.append((x: nx, y: ny, color: "#5588dd"))
        state.pendingPlayerLunge = Point(x: dx, y: dy)
        return
    }

    // Open door
    if tile == .door {
        state.map[ny][nx] = .doorOpen
        state.doors.removeAll { $0 == target }
        AudioEngine.shared.play(.door)
        state.addLog("Door opened.", .normal)
        state.pendingFlashes.append((x: nx, y: ny, color: "#aa8833"))
        state.pendingTileRebuild.append(Point(x: nx, y: ny))
        endPlayerTurn(state: state)
        return
    }

    // Move
    state.player.x = nx; state.player.y = ny
    state.steps += 1; state.runSteps += 1
    AudioEngine.shared.play(.step)
    HapticEngine.light()

    // Hungry curse
    if state.hasCurse("hungry") && state.steps % 5 == 0 {
        state.player.hp = max(1, state.player.hp - 1)
        state.addLog("Dark Hunger: -1HP", .curse)
    }
    // Quick feet relic
    if state.flags.quickfeet && state.steps % 10 == 0 {
        state.player.hp = min(state.player.maxHp, state.player.hp + 1)
        state.addLog("Quick Feet: +1HP", .spell)
    }

    // Check tile
    switch tile {
    case .stairs:
        if state.floor >= MAX_FLOORS {
            triggerVictory(state: state)
        } else {
            state.stairsPending = true
        }
        return
    case .shop:
        AudioEngine.shared.play(.door); HapticEngine.light()
        state.addLog("The merchant awaits...", .narr)
        state.screen = .shop
        return
    case .altar:
        AudioEngine.shared.play(.door); HapticEngine.light()
        state.addLog("The Dark Altar pulses with dark energy...", .narr)
        state.screen = .altar
        return
    case .secret:
        let isNew = !state.isSeen(Point(x: nx, y: ny))
        if isNew { AudioEngine.shared.play(.secret); state.addLog("Secret room discovered!", .narr) }
    default: break
    }

    // Pick up items
    if let gi = state.item(at: target) {
        pickItem(state: state, item: gi)
    }

    // Check trap (ghoststep relic: skip when shadow is active)
    let shadowSkipsTrap = state.flags.ghoststep && state.flags.shadowActive
    if let trap = state.trap(at: target), !state.flags.trapmaster, !shadowSkipsTrap {
        triggerTrap(state: state, trap: trap)
    }

    endPlayerTurn(state: state)
}

func endPlayerTurn(state: GameState) {
    computeVision(state: state)
    enemyTurns(state: state)
    computeVision(state: state)  // re-compute after enemies move so vis reflects final positions
    tickCooldowns(state: state)
    updateProjectiles(state: state)
    state.enemyTurnFlash = true
}

// MARK: — Player attack

func playerAttack(state: GameState, enemyIdx: Int) {
    guard enemyIdx < state.enemies.count else { return }
    let tmpl = state.enemies[enemyIdx].template

    // Miss check (clumsy curse)
    if state.hasCurse("clumsy") && Double.random(in: 0...1) < 0.25 {
        state.addLog("Missed! (Clumsy)", .combat); AudioEngine.shared.play(.miss); return
    }

    var dmg = max(1, state.player.atk - 0) // no enemy DEF in base formula
    let isCrit = Double.random(in: 0...1) < state.player.crit
    if isCrit { dmg *= 2; AudioEngine.shared.play(.swordCrit); HapticEngine.medium() }
    else { AudioEngine.shared.play(.sword); HapticEngine.light() }

    // BrutalStrike
    if state.player.brutalkStrike { dmg *= 3; state.player.brutalkStrike = false }
    // Ambush
    if state.player.ambushReady { dmg = Int(Double(dmg) * 3); state.player.ambushReady = false }

    // Lunge animation: player springs toward enemy
    state.pendingPlayerLunge = Point(
        x: state.enemies[enemyIdx].x - state.player.x,
        y: state.enemies[enemyIdx].y - state.player.y
    )
    state.enemies[enemyIdx].hp -= dmg
    state.pendingDamageFloats.append((x: state.enemies[enemyIdx].x, y: state.enemies[enemyIdx].y,
                                       text: "-\(dmg)\(isCrit ? "!" : "")", color: isCrit ? "#ffcc00" : "#ff4444"))
    state.pendingFlashes.append((x: state.enemies[enemyIdx].x, y: state.enemies[enemyIdx].y, color: "#ff3333"))
    // Entity hit flash
    state.pendingEntityFlashUIDs.append(state.enemies[enemyIdx].uid)
    state.pendingEntityFlashColors.append(isCrit ? "#ffee44" : "#ffffff")

    let name = tmpl.name
    state.addLog(isCrit ? "CRIT! -\(dmg) to \(name)" : "Hit \(name) for \(dmg)", .combat)

    if state.enemies[enemyIdx].hp <= 0 {
        killEnemy(state: state, idx: enemyIdx)
    } else if tmpl.isBoss {
        checkBossPhase(state: state, idx: enemyIdx)
    }
}

// MARK: — Kill

func killEnemy(state: GameState, idx: Int) {
    guard idx < state.enemies.count else { return }
    let enemy = state.enemies[idx]
    let tmpl = enemy.template
    AudioEngine.shared.play(.kill); HapticEngine.heavy()
    state.addLog("\(tmpl.name.capitalized) defeated!", .combat)

    let xpGain = state.flags.xpboost ? Int(Double(tmpl.xp) * 1.5) : tmpl.xp
    state.player.xp += xpGain
    state.kills += 1

    if state.flags.vampirism { state.player.hp = min(state.player.maxHp, state.player.hp + 1) }
    if state.flags.berserker { state.player.bonusAtk += 1; state.applyEquipment() }

    let goldAmt = Int.random(in: tmpl.goldMin...tmpl.goldMax)
    let finalGold = state.flags.goldlust ? goldAmt * 2 : goldAmt
    state.gold += finalGold; state.runGold += finalGold

    if finalGold > 0 {
        state.items.append(GameItem(uid: UUID(), type: "gold", x: enemy.x, y: enemy.y,
                                    identified: true, goldAmount: finalGold))
    }

    if let drop = tmpl.drop {
        state.items.append(GameItem(uid: UUID(), type: drop, x: enemy.x, y: enemy.y))
    }

    state.enemies.remove(at: idx)
    state.checkLevelUp()
}

// MARK: — Boss phases

func checkBossPhase(state: GameState, idx: Int) {
    guard idx < state.enemies.count else { return }
    let boss = state.enemies[idx]
    let pct = Double(boss.hp) / Double(boss.maxHp)
    let oldPhase = boss.phase

    var newPhase = 1
    if pct <= 0.25 { newPhase = 4 }
    else if pct <= 0.50 { newPhase = 3 }
    else if pct <= 0.75 { newPhase = 2 }

    guard newPhase > oldPhase else { return }
    state.enemies[idx].phase = newPhase
    AudioEngine.shared.play(.bossPhase); HapticEngine.heavy()

    switch newPhase {
    case 2:
        let line = BOSS_PHASE2_LINES.randomElement()!
        state.showBanner(line, color: "#cc0000")
        // Spawn 2 death knights in walkable room centers
        for r in state.rooms.prefix(3) {
            guard r.cy < state.map.count, r.cx < (state.map.first?.count ?? 0) else { continue }
            guard state.map[r.cy][r.cx] == .floor else { continue }
            if state.enemies.count < 20 {
                state.enemies.append(Enemy(uid: UUID(), templateId: "death_knight",
                                           x: r.cx, y: r.cy, hp: 34, maxHp: 34, atk: 11))
            }
        }
    case 3:
        let line = BOSS_PHASE3_LINES.randomElement()!
        state.showBanner(line, color: "#ff3300")
        // Death nova
        let bossPos = boss.pos
        var novaKill: [Int] = []
        for i in state.enemies.indices where state.enemies[i].pos.distance(to: bossPos) <= 3 && i != idx {
            state.enemies[i].hp = max(0, state.enemies[i].hp - 20)
            if state.enemies[i].hp <= 0 { novaKill.append(i) }
        }
        for i in novaKill.reversed() { killEnemy(state: state, idx: i) }
        let dmg = max(1, 8 - state.player.def)
        if bossPos.distance(to: state.playerPos) <= 3 {
            state.player.hp -= dmg
            state.addLog("Death Nova: -\(dmg)HP!", .combat)
            checkPlayerDeath(state: state, cause: "Margüento's Death Nova claimed \(HERO_NAME) on floor \(state.floor).")
        }
    case 4:
        let line = BOSS_PHASE4_LINES.randomElement()!
        state.showBanner(line, color: "#ff0000")
    default: break
    }
}

// MARK: — Enemy turns

func enemyTurns(state: GameState) {
    var toKill: [Int] = []

    for i in state.enemies.indices {
        guard state.enemies[i].hp > 0 else { continue }
        var e = state.enemies[i]

        // Thaw/un-stun
        if e.frozenTurns > 0 { state.enemies[i].frozenTurns -= 1; continue }
        if e.stunTurns > 0   { state.enemies[i].stunTurns -= 1; continue }

        // Poison tick
        if e.poisonedTurns > 0 {
            state.enemies[i].hp -= 2; state.enemies[i].poisonedTurns -= 1
            if state.enemies[i].hp <= 0 { toKill.append(i); continue }
        }

        // Warcry debuff
        if e.warcryDebuffTurns > 0 { state.enemies[i].warcryDebuffTurns -= 1 }

        let tmpl = e.template

        // Slow enemies skip every other turn
        if tmpl.slow {
            state.enemies[i].moveCounter += 1
            if state.enemies[i].moveCounter % 2 != 0 { continue }
        }

        let ePos = Point(x: e.x, y: e.y)
        let pPos = state.playerPos
        guard state.isVisible(ePos) else { continue }

        // Gargoyle: shoots on interval
        if tmpl.isGargoyle {
            state.enemies[i].shootTimer -= 1
            if state.enemies[i].shootTimer <= 0 {
                state.enemies[i].shootTimer = 2
                if hasLOS(state: state, x0: e.x, y0: e.y, x1: pPos.x, y1: pPos.y) {
                    let ddx = pPos.x - e.x; let ddy = pPos.y - e.y
                    spawnProjectile(state: state, fx: e.x, fy: e.y, dx: ddx, dy: ddy,
                                    color: tmpl.projColor, dmg: tmpl.projDmg, isPlayer: false,
                                    speed: tmpl.projSpeed, paralyzes: false)
                }
            }
            continue
        }

        // Ranged: shoot if LOS; keepDistance enemies retreat when player is too close
        if tmpl.ranged && hasLOS(state: state, x0: e.x, y0: e.y, x1: pPos.x, y1: pPos.y) {
            if tmpl.keepDistance && ePos.distance(to: pPos) <= 2 {
                let awayDx = e.x > pPos.x ? 1 : e.x < pPos.x ? -1 : 0
                let awayDy = e.y > pPos.y ? 1 : e.y < pPos.y ? -1 : 0
                let retreatCandidates = [
                    Point(x: e.x + awayDx, y: e.y + awayDy),
                    Point(x: e.x + awayDx, y: e.y),
                    Point(x: e.x, y: e.y + awayDy)
                ]
                for pt in retreatCandidates {
                    guard pt.x >= 0, pt.y >= 0, pt.x < GRID_W, pt.y < GRID_H else { continue }
                    let t = state.map[pt.y][pt.x]
                    guard t == .floor || t == .doorOpen else { continue }
                    guard state.enemyReal(at: pt) == nil else { continue }
                    state.enemies[i].x = pt.x; state.enemies[i].y = pt.y
                    break
                }
                continue  // skip shooting this turn while retreating
            }
            let ddx = pPos.x - e.x; let ddy = pPos.y - e.y
            spawnProjectile(state: state, fx: e.x, fy: e.y, dx: ddx, dy: ddy,
                            color: tmpl.projColor, dmg: tmpl.projDmg, isPlayer: false,
                            speed: tmpl.projSpeed, paralyzes: tmpl.paralyzesOnHit)
            continue
        }

        // Melee: move toward player via A*
        let path = astar(state: state, sx: e.x, sy: e.y, ex: pPos.x, ey: pPos.y)
        e = state.enemies[i]  // refresh after astar

        if let next = path.first {
            if next == pPos {
                enemyAttack(state: state, enemy: e)
            } else if state.enemyReal(at: next) == nil {
                state.enemies[i].x = next.x; state.enemies[i].y = next.y
            }
        } else if ePos.distance(to: pPos) == 1 {
            enemyAttack(state: state, enemy: e)
        }
    }

    // Kill deferred enemies in reverse order to preserve valid indices
    for i in toKill.reversed() { killEnemy(state: state, idx: i) }
}

func enemyAttack(state: GameState, enemy: Enemy) {
    let tmpl = enemy.template
    let effectiveAtk = enemy.warcryDebuffTurns > 0 ? max(1, enemy.atk - 2) : enemy.atk
    let dmg = max(1, effectiveAtk - state.player.def)

    // Shadow dodge
    if state.player.dodgeNext {
        state.player.dodgeNext = false; state.flags.shadowActive = false
        state.addLog("Dodged \(tmpl.name)'s attack!", .spell); return
    }

    // Deflect relic
    if state.flags.deflect && Double.random(in: 0...1) < 0.3 {
        state.addLog("Deflected!", .spell); return
    }

    // Vampire: drain hp
    if tmpl.drainHP {
        if let idx = state.enemies.firstIndex(where: { $0.uid == enemy.uid }) {
            state.enemies[idx].hp = min(state.enemies[idx].maxHp, state.enemies[idx].hp + 2)
        }
    }

    // Enemy lunge toward player
    let eLungeDx = state.player.x > enemy.x ? 1 : state.player.x < enemy.x ? -1 : 0
    let eLungeDy = state.player.y > enemy.y ? 1 : state.player.y < enemy.y ? -1 : 0
    state.pendingEnemyLunges.append((uid: enemy.uid, dx: eLungeDx, dy: eLungeDy))
    state.player.hp -= dmg
    state.pendingFlashes.append((x: state.player.x, y: state.player.y, color: "#cc0000"))
    // Player hit flash on sprite
    state.pendingEntityFlashUIDs.append(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    state.pendingEntityFlashColors.append("#ff3333")
    state.pendingPlayerHit = true
    AudioEngine.shared.play(.playerHit); HapticEngine.medium()
    state.addLog("\(tmpl.name.capitalized) hits you: -\(dmg)HP", .combat)
    checkPlayerDeath(state: state, cause: "\(tmpl.name.capitalized) ended \(HERO_NAME) on floor \(state.floor).")
}

func checkPlayerDeath(state: GameState, cause: String) {
    guard state.player.hp <= 0 else { return }
    // Phoenix relic: revive once
    if state.flags.phoenix && !state.flags.phoenixUsed {
        state.flags.phoenixUsed = true
        state.player.hp = 8
        state.addLog("Phoenix: Revived at 8HP!", .spell)
        AudioEngine.shared.play(.relic)
        return
    }
    state.player.hp = 0
    state.isDead = true
    state.deathCause = cause
    AudioEngine.shared.stopMusic()
    AudioEngine.shared.play(.death); HapticEngine.heavy()
    state.screen = .death
}

// MARK: — Skills

func useSkill(state: GameState, index: Int) {
    guard index < state.skills.count else { return }
    guard state.skills[index].cur <= 0 else {
        state.addLog("Skill on cooldown!", .info); return
    }
    let skill = state.skills[index]
    switch skill.id {
    case "brutalStrike": skillBrutalStrike(state: state)
    case "fortify":      skillFortify(state: state)
    case "warcry":       skillWarcry(state: state)
    case "fireball":     skillFireball(state: state)
    case "freeze":       skillFreeze(state: state)
    case "lightning":    skillLightning(state: state)
    case "poison":       skillPoison(state: state)
    case "shadow":       skillShadow(state: state)
    case "ambush":       skillAmbush(state: state)
    default: break
    }
    state.skills[index].cur = state.skills[index].cd
    endPlayerTurn(state: state)
}

private func nearbyEnemies(state: GameState, radius: Int) -> [Int] {
    state.enemies.indices.filter {
        state.enemies[$0].hp > 0 &&
        Point(x: state.enemies[$0].x, y: state.enemies[$0].y).distance(to: state.playerPos) <= radius
    }
}

private func firstAimedEnemy(state: GameState) -> Int? {
    for s in 1...10 {
        let tx = state.player.x + state.aimDx * s
        let ty = state.player.y + state.aimDy * s
        guard tx >= 0, ty >= 0, tx < GRID_W, ty < GRID_H else { break }
        let t = state.map[ty][tx]; if t == .wall || t == .door { break }
        if let idx = state.enemies.firstIndex(where: { $0.x == tx && $0.y == ty && $0.hp > 0 }) { return idx }
    }
    return nil
}

private func skillBrutalStrike(state: GameState) {
    state.player.brutalkStrike = true
    state.addLog("Strike ready — next hit deals 3x damage!", .spell)
    AudioEngine.shared.play(.skillStrike)
}
private func skillFortify(state: GameState) {
    state.player.fortifyTurns = 3
    state.player.def += 4
    state.addLog("Fortify: DEF+4 for 3 turns", .spell)
    AudioEngine.shared.play(.skillFortify)
}
private func skillWarcry(state: GameState) {
    let nearby = nearbyEnemies(state: state, radius: 3)
    for i in nearby {
        state.enemies[i].warcryDebuffTurns = 2
    }
    state.addLog("Warcry: \(nearby.count) enemies weakened!", .spell)
    AudioEngine.shared.play(.skillWarcry)
    HapticEngine.heavy()
}
private func skillFireball(state: GameState) {
    let dmg = max(1, state.player.spell * 3)
    if let idx = firstAimedEnemy(state: state) {
        let ex = state.enemies[idx].x; let ey = state.enemies[idx].y
        state.enemies[idx].hp -= dmg
        state.enemies[idx].poisonedTurns = 2
        state.addLog("Fireball: -\(dmg) + burn!", .spell)
        state.pendingDamageFloats.append((x: ex, y: ey, text: "🔥\(dmg)", color: "#ff6600"))
        state.pendingFlashes.append((x: ex, y: ey, color: "#ff5500"))
        state.pendingEntityFlashUIDs.append(state.enemies[idx].uid)
        state.pendingEntityFlashColors.append("#ff6600")
        // Flash player tile too (cast animation)
        state.pendingFlashes.append((x: state.player.x, y: state.player.y, color: "#ff3300"))
        if state.enemies[idx].hp <= 0 { killEnemy(state: state, idx: idx) }
    }
    AudioEngine.shared.play(.spellFire); HapticEngine.medium()
}
private func skillFreeze(state: GameState) {
    let nearby = nearbyEnemies(state: state, radius: 2)
    for i in nearby {
        state.enemies[i].frozenTurns = 2
        state.pendingFlashes.append((x: state.enemies[i].x, y: state.enemies[i].y, color: "#44aaff"))
        state.pendingEntityFlashUIDs.append(state.enemies[i].uid)
        state.pendingEntityFlashColors.append("#88ddff")
    }
    state.pendingFlashes.append((x: state.player.x, y: state.player.y, color: "#2266ff"))
    state.addLog("Freeze: \(nearby.count) enemies frozen!", .spell)
    AudioEngine.shared.play(.spellIce); HapticEngine.medium()
}
private func skillLightning(state: GameState) {
    let dmg = max(1, state.player.spell * 2)
    let targets = state.enemies.indices
        .filter { state.enemies[$0].hp > 0 }
        .sorted { state.enemies[$0].pos.distance(to: state.playerPos) < state.enemies[$1].pos.distance(to: state.playerPos) }
        .prefix(3)
    var hit = 0
    var toKill: [Int] = []
    for i in targets {
        state.enemies[i].hp -= dmg
        state.pendingDamageFloats.append((x: state.enemies[i].x, y: state.enemies[i].y,
                                          text: "⚡\(dmg)", color: "#ddddff"))
        state.pendingFlashes.append((x: state.enemies[i].x, y: state.enemies[i].y, color: "#aaaaff"))
        state.pendingEntityFlashUIDs.append(state.enemies[i].uid)
        state.pendingEntityFlashColors.append("#ffffff")
        if state.enemies[i].hp <= 0 { toKill.append(i) }
        hit += 1
    }
    state.pendingFlashes.append((x: state.player.x, y: state.player.y, color: "#8888ff"))
    state.addLog("Lightning chains \(hit) enemies!", .spell)
    for i in toKill.reversed() { killEnemy(state: state, idx: i) }
    AudioEngine.shared.play(.spellLightning); HapticEngine.heavy()
}
private func skillPoison(state: GameState) {
    if let idx = firstAimedEnemy(state: state) {
        state.enemies[idx].poisonedTurns = 4
        state.addLog("Poison: \(state.enemies[idx].template.name) poisoned 4 turns", .spell)
    }
    AudioEngine.shared.play(.spellPoison)
}
private func skillShadow(state: GameState) {
    state.player.dodgeNext = true; state.flags.shadowActive = true
    state.addLog("Shadow: next attack dodged", .spell)
    AudioEngine.shared.play(.spellShadow)
}
private func skillAmbush(state: GameState) {
    state.player.ambushReady = true
    state.addLog("Ambush: next hit 3x damage!", .spell)
    AudioEngine.shared.play(.spellAmbush)
}

// MARK: — Skill cooldown tick

func tickCooldowns(state: GameState) {
    for i in state.skills.indices {
        if state.skills[i].cur > 0 { state.skills[i].cur -= 1 }
    }
    if state.player.fortifyTurns > 0 {
        state.player.fortifyTurns -= 1
        if state.player.fortifyTurns == 0 { state.player.def -= 4 }
    }
}

// MARK: — Projectiles

func spawnProjectile(state: GameState, fx: Int, fy: Int, dx: Int, dy: Int,
                     color: String, dmg: Int, isPlayer: Bool, speed: CGFloat, paralyzes: Bool) {
    var ndx = dx; var ndy = dy
    if ndx != 0 && ndy != 0 { if abs(ndx) > abs(ndy) { ndy = 0 } else { ndx = 0 } }
    guard ndx != 0 || ndy != 0 else { return }
    let vx = CGFloat(ndx > 0 ? 1 : (ndx < 0 ? -1 : 0)) * speed * CGFloat(TILE_SIZE) / 60
    let vy = CGFloat(ndy > 0 ? 1 : (ndy < 0 ? -1 : 0)) * speed * CGFloat(TILE_SIZE) / 60
    let proj = Projectile(uid: UUID(),
                          px: CGFloat(fx) * TILE_SIZE + TILE_SIZE / 2,
                          py: CGFloat(fy) * TILE_SIZE + TILE_SIZE / 2,
                          vx: vx, vy: vy, color: color, dmg: dmg,
                          isPlayer: isPlayer, paralyzes: paralyzes)
    state.projectiles.append(proj)
    if isPlayer { AudioEngine.shared.play(.projLaunch) }
}

func shootProjectile(state: GameState) {
    spawnProjectile(state: state, fx: state.player.x, fy: state.player.y,
                    dx: state.aimDx, dy: state.aimDy,
                    color: "#c0a060", dmg: max(1, state.player.atk / 2),
                    isPlayer: true, speed: 2.0, paralyzes: false)
    endPlayerTurn(state: state)
}

func updateProjectiles(state: GameState) {
    var toRemove: Set<UUID> = []
    for i in state.projectiles.indices {
        var p = state.projectiles[i]
        p.px += p.vx; p.py += p.vy
        p.traveled += sqrt(p.vx * p.vx + p.vy * p.vy)
        state.projectiles[i] = p

        guard p.traveled <= p.maxRange else { toRemove.insert(p.uid); continue }
        let cx = Int(p.px / TILE_SIZE); let cy = Int(p.py / TILE_SIZE)
        guard cx >= 0, cy >= 0, cx < GRID_W, cy < GRID_H else { toRemove.insert(p.uid); continue }
        let t = state.map[cy][cx]
        if t == .wall || t == .door { toRemove.insert(p.uid); continue }

        if p.isPlayer {
            if let idx = state.enemies.firstIndex(where: { $0.x == cx && $0.y == cy && $0.hp > 0 }) {
                state.enemies[idx].hp -= p.dmg
                state.pendingDamageFloats.append((x: cx, y: cy, text: "-\(p.dmg)", color: "#ffaa44"))
                state.pendingFlashes.append((x: cx, y: cy, color: "#ff5500"))
                AudioEngine.shared.play(.projHit)
                if state.enemies[idx].hp <= 0 { killEnemy(state: state, idx: idx) }
                toRemove.insert(p.uid)
            }
        } else {
            if cx == state.player.x && cy == state.player.y {
                if state.flags.deflect && Double.random(in: 0...1) < 0.3 {
                    state.addLog("Deflected!", .spell); toRemove.insert(p.uid); continue
                }
                if state.player.dodgeNext {
                    state.player.dodgeNext = false; state.flags.shadowActive = false
                    state.addLog("Dodged!", .spell); toRemove.insert(p.uid); continue
                }
                let dmg = max(1, p.dmg - state.player.def)
                state.player.hp -= dmg
                state.pendingFlashes.append((x: cx, y: cy, color: "#cc0000"))
                AudioEngine.shared.play(.playerHit); HapticEngine.medium()
                if p.paralyzes { state.player.stunned = 2; state.addLog("Stunned by Banshee!", .combat) }
                state.addLog("Hit by projectile: -\(dmg)HP", .combat)
                checkPlayerDeath(state: state, cause: "A projectile struck down \(HERO_NAME) on floor \(state.floor).")
                toRemove.insert(p.uid)
            }
        }
    }
    state.projectiles.removeAll { toRemove.contains($0.uid) }
}

// MARK: — Traps

func triggerTrap(state: GameState, trap: TrapData) {
    guard !state.flags.trapmaster else { return }
    guard let idx = state.traps.firstIndex(where: { $0.uid == trap.uid }) else { return }
    state.traps[idx].triggered = true
    // Visual "click" cue before damage resolves
    state.pendingDamageFloats.append((x: trap.x, y: trap.y, text: "*CLICK*", color: "#ff8800"))
    state.pendingFlashes.append((x: trap.x, y: trap.y, color: "#ff6600"))
    AudioEngine.shared.play(.trap); HapticEngine.heavy()

    switch trap.type {
    case "spike":
        let dmg = max(1, 5 - state.player.def)
        state.player.hp -= dmg
        state.addLog("Spike trap: -\(dmg)HP!", .trap)
        checkPlayerDeath(state: state, cause: "A spike trap ended \(HERO_NAME) on floor \(state.floor).")
    case "proximity_spike":
        let dmg = max(1, 8 - state.player.def)
        state.player.hp -= dmg
        state.addLog("Proximity spike: -\(dmg)HP!", .trap)
        // AoE: also damages nearby enemies
        let trapPos = state.traps[idx].pos
        var proxKill: [Int] = []
        for j in state.enemies.indices where state.enemies[j].hp > 0 && state.enemies[j].pos.distance(to: trapPos) <= 2 {
            state.enemies[j].hp -= 6
            state.pendingDamageFloats.append((x: state.enemies[j].x, y: state.enemies[j].y, text: "-6", color: "#ff8800"))
            if state.enemies[j].hp <= 0 { proxKill.append(j) }
        }
        for j in proxKill.reversed() { killEnemy(state: state, idx: j) }
        checkPlayerDeath(state: state, cause: "A proximity spike ended \(HERO_NAME) on floor \(state.floor).")
    case "gas":
        let dmg = max(1, 3 - state.player.def)
        state.player.hp -= dmg
        state.addLog("Gas trap: -\(dmg)HP + weakened!", .trap)
        if !state.hasCurse("weakened"), let curse = curseById("weakened") {
            state.curses.append(curse)
            state.applyCurseEffect(curse)
        }
        checkPlayerDeath(state: state, cause: "A gas trap ended \(HERO_NAME) on floor \(state.floor).")
    case "arrow":
        let dmg = max(1, 4 - state.player.def)
        state.player.hp -= dmg
        state.addLog("Arrow trap: -\(dmg)HP!", .trap)
        checkPlayerDeath(state: state, cause: "An arrow trap ended \(HERO_NAME) on floor \(state.floor).")
    case "teleport":
        let floors = state.rooms.compactMap { r -> Point? in
            let p = Point(x: r.cx, y: r.cy)
            return state.map[r.cy][r.cx] == .floor ? p : nil
        }
        if let dest = floors.randomElement() {
            state.player.x = dest.x; state.player.y = dest.y
            state.addLog("Teleport trap!", .trap)
        }
    case "chain":
        let dmg = max(1, 5 - state.player.def)
        state.player.hp -= dmg; state.player.stunned = 1
        state.addLog("Chain trap: -\(dmg)HP + stunned!", .trap)
        checkPlayerDeath(state: state, cause: "A chain trap ended \(HERO_NAME) on floor \(state.floor).")
    default: break
    }
}

// MARK: — Item pickup

func pickItem(state: GameState, item: GameItem) {
    guard let idx = state.items.firstIndex(where: { $0.uid == item.uid }) else { return }
    state.items.remove(at: idx)
    switch item.type {
    case "potion":
        let heal = 8 + state.floor * 2
        state.player.hp = min(state.player.maxHp, state.player.hp + heal)
        state.addLog("Potion: +\(heal)HP", .normal)
        AudioEngine.shared.play(.pickup)
    case "scroll":
        let dmgBoost = 3
        state.player.bonusAtk += dmgBoost
        state.applyEquipment()
        state.addLog("Scroll: ATK+\(dmgBoost)", .spell)
        AudioEngine.shared.play(.pickup)
    case "gold":
        state.gold += item.goldAmount; state.runGold += item.goldAmount
        state.addLog("+\(item.goldAmount) gold", .normal)
        AudioEngine.shared.play(.goldDrop)
    case "equipment":
        if let eid = item.equipId, let eq = equipById(eid) {
            equipItem(state: state, eq: eq)
        }
    case "relic":
        if let rid = item.relicId { state.applyRelic(rid) }
        else if let rel = ALL_RELICS.filter({ !state.hasRelic($0.id) }).randomElement() {
            state.applyRelic(rel.id)
        }
    default: break
    }
}

func equipItem(state: GameState, eq: EquipItem) {
    state.equipment[eq.slot] = eq.id
    state.applyEquipment()
    state.addLog("\(eq.icon) Equipped: \(eq.name)", .normal)
    AudioEngine.shared.play(.equip)
    HapticEngine.medium()
}

// MARK: — Altar

func openAltarOption(state: GameState, option: Int) {
    guard !state.altarUsed else { return }
    state.altarUsed = true
    switch option {
    case 0: // Blood Pact: -8HP → random relic
        state.player.hp = max(1, state.player.hp - 8)
        let avail = ALL_RELICS.filter { !state.hasRelic($0.id) }
        if let rel = avail.randomElement() { state.applyRelic(rel.id) }
        state.addLog("Blood Pact: -8HP, gained relic!", .spell)
    case 1: // Steal Power: -6HP → ATK+3
        state.player.hp = max(1, state.player.hp - 6)
        state.player.bonusAtk += 3
        state.applyEquipment()
        state.addLog("Steal Power: -6HP, ATK+3!", .spell)
    case 2: // Curse bargain: relic + pending curse
        let avail = ALL_RELICS.filter { !state.hasRelic($0.id) }
        if let rel = avail.randomElement() { state.applyRelic(rel.id) }
        let availCurses = ALL_CURSES.filter { !state.hasCurse($0.id) }
        state.pendingCurse = availCurses.randomElement()
        state.addLog("Bargain: relic gained, curse pending next floor!", .curse)
    default: break
    }
    AudioEngine.shared.play(.altar)
    checkPlayerDeath(state: state, cause: "A blood pact drained \(HERO_NAME) on floor \(state.floor).")
}

// MARK: — Floor transition

func enterFloor(state: GameState) {
    state.curses = []
    state.enemies = []; state.items = []; state.traps = []; state.projectiles = []
    state.map = []   // blocks SaveManager from persisting stale map during rest screen
    state.player.fortifyTurns = 0; state.player.stunned = 0
    state.altarUsed = false
    state.hasShop  = state.floor % 3 == 0 || state.floor == 2
    state.hasAltar = (state.floor % 4 == 0 || state.floor == MAX_FLOORS - 1) && state.floor < MAX_FLOORS
    state.floorEnemyCount = min(8, 3 + state.floor / 2)
    state.applyEquipment()
    state.screen = .rest
}

func triggerVictory(state: GameState) {
    state.isVictory = true
    state.addLog("You have defeated Marguento!", .narr)
    AudioEngine.shared.stopMusic()
    AudioEngine.shared.play(.victory); HapticEngine.heavy()
    state.screen = .victory
}

// MARK: — Wait turn

func waitTurn(state: GameState) {
    AudioEngine.shared.play(.step)
    endPlayerTurn(state: state)
}

