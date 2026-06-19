import SpriteKit
import SwiftUI

// MARK: — GameScene

final class GameScene: SKScene {
    weak var state: GameState?

    private let tileLayer   = SKNode()
    private let itemLayer   = SKNode()
    private let entityLayer = SKNode()
    private let fxLayer     = SKNode()
    private let projLayer   = SKNode()
    private var cameraNode  = SKCameraNode()

    private var tileNodes:   [[SKNode?]]    = []
    private var entityNodes: [UUID: SKNode] = [:]
    private var projNodes:   [UUID: SKNode] = [:]
    private var itemNodes:   [UUID: SKNode] = [:]

    private let TS = CGFloat(TILE_SIZE)

    // Camera + sprite tracking — avoid restarting actions every frame
    private var lastCameraTarget: CGPoint = CGPoint(x: CGFloat.infinity, y: 0)
    private var lastSpriteTarget: CGPoint = CGPoint(x: CGFloat.infinity, y: 0)

    // Direction tracking
    private var lastPlayerPos: (x: Int, y: Int) = (0, 0)
    private var playerFacing: String = "south"
    private var lastEnemyPos:    [UUID: (x: Int, y: Int)] = [:]
    private var enemyFacing:     [UUID: String] = [:]
    private var lastEnemyTarget: [UUID: CGPoint] = [:]
    private var lastProjPos:   [UUID: CGPoint] = [:]

    // Texture cache — nearest-neighbor filtering for crisp pixel art
    private var textureCache: [String: SKTexture] = [:]

    private lazy var floorTex: SKTexture = {
        let atlas = loadTexture("dungeon_tileset")
        // Wang tile index 0 (all-floor corners) = top-left cell of the 4×4 sheet
        // SpriteKit UV: y flipped from image coords → row 0 of image = y 0.75..1.0
        let t = SKTexture(rect: CGRect(x: 0, y: 0.75, width: 0.25, height: 0.25), in: atlas)
        t.filteringMode = .nearest
        return t
    }()

    private lazy var wallTex: SKTexture = {
        let atlas = loadTexture("dungeon_tileset")
        // Wang tile index 15 (all-wall corners) = bottom-right cell of the 4×4 sheet
        let t = SKTexture(rect: CGRect(x: 0.75, y: 0, width: 0.25, height: 0.25), in: atlas)
        t.filteringMode = .nearest
        return t
    }()

    override func didMove(to view: SKView) {
        backgroundColor = .black
        tileLayer.zPosition   = 0
        itemLayer.zPosition   = 10
        entityLayer.zPosition = 20
        fxLayer.zPosition     = 30
        projLayer.zPosition   = 40
        addChild(tileLayer)
        addChild(itemLayer)
        addChild(entityLayer)
        addChild(fxLayer)
        addChild(projLayer)
        addChild(cameraNode)
        camera = cameraNode
    }

    // MARK: — Full rebuild (new floor)

    func rebuild() {
        guard let state, state.map.count == GRID_H, !state.map[0].isEmpty else { return }
        tileLayer.removeAllChildren()
        itemLayer.removeAllChildren()
        entityLayer.removeAllChildren()
        fxLayer.removeAllChildren()
        projLayer.removeAllChildren()
        entityNodes = [:]
        projNodes   = [:]
        itemNodes   = [:]
        tileNodes   = Array(repeating: Array(repeating: nil, count: GRID_W), count: GRID_H)

        lastPlayerPos    = (state.player.x, state.player.y)
        playerFacing     = "south"
        lastEnemyPos     = [:]
        enemyFacing      = [:]
        lastEnemyTarget  = [:]
        lastCameraTarget = CGPoint(x: CGFloat.infinity, y: 0) // force instant snap on new floor
        lastSpriteTarget = CGPoint(x: CGFloat.infinity, y: 0)

        for y in 0..<GRID_H {
            for x in 0..<GRID_W {
                let tile = state.map[y][x]
                let n = makeTileNode(tile, x: x, y: y)
                n.position = worldPos(x, y)
                n.zPosition = 0
                n.alpha = 0
                tileNodes[y][x] = n
                tileLayer.addChild(n)
            }
        }

        // Torches — container controls visibility; children animate independently
        for t in state.torches {
            let container = SKNode()
            container.position = worldPos(t.x, t.y)
            container.name = "torch"
            container.alpha = 0
            tileLayer.addChild(container)

            let glow = SKSpriteNode(color: UIColor(hex: "#ffaa33").withAlphaComponent(0.22),
                                    size: CGSize(width: TS * 3.5, height: TS * 3.5))
            glow.zPosition = 0.3; glow.blendMode = .add
            container.addChild(glow)
            glow.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.group([SKAction.fadeAlpha(to: 0.34, duration: 0.45),
                                SKAction.scale(to: 1.15, duration: 0.45)]),
                SKAction.group([SKAction.fadeAlpha(to: 0.13, duration: 0.35),
                                SKAction.scale(to: 0.87, duration: 0.35)]),
                SKAction.group([SKAction.fadeAlpha(to: 0.22, duration: 0.28),
                                SKAction.scale(to: 1.0,  duration: 0.28)])
            ])))

            let dot = SKShapeNode(circleOfRadius: 4)
            dot.fillColor   = UIColor(hex: "#ffcc55")
            dot.strokeColor = UIColor(hex: "#ff8800")
            dot.lineWidth   = 1.5; dot.glowWidth = 3; dot.zPosition = 0.4
            container.addChild(dot)
            dot.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.35, duration: 0.3),
                SKAction.scale(to: 0.75, duration: 0.42),
                SKAction.scale(to: 1.0,  duration: 0.18)
            ])))
        }

        rebuildEntities()
        rebuildItems()
        updateCamera()
    }

    // MARK: — Per-frame update

    override func update(_ currentTime: TimeInterval) {
        guard let state else { return }
        if state.sceneNeedsRebuild { state.sceneNeedsRebuild = false; rebuild(); return }
        // Map cleared by enterFloor — skip until rebuild on new floor
        guard state.map.count == GRID_H else { return }
        updateVisibility(state: state)
        syncEntities(state: state)
        syncItems(state: state)
        syncProjectiles(state: state)
        drainFlashes(state: state)
        drainDamageFloats(state: state)
        drainEntityFlashes(state: state)
        drainPlayerLunge(state: state)
        drainEnemyLunges(state: state)
        updateCamera()
    }

    // MARK: — Visibility

    private func updateVisibility(state: GameState) {
        for y in 0..<GRID_H {
            for x in 0..<GRID_W {
                guard let n = tileNodes[y][x] else { continue }
                let vis  = state.vis[y][x]
                let seen = state.seen[y][x]
                let tile = state.map[y][x]
                if vis        { n.alpha = 1.0 }
                else if seen  { n.alpha = tile == .wall ? 0.55 : 0.28 }
                else          { n.alpha = 0 }
            }
        }
        for node in tileLayer.children {
            guard node.name == "torch" else { continue }
            let tx = Int((node.position.x + CGFloat(GRID_W) * TS / 2 - TS / 2) / TS)
            let ty = Int((-node.position.y + CGFloat(GRID_H) * TS / 2 - TS / 2) / TS)
            if tx >= 0, ty >= 0, tx < GRID_W, ty < GRID_H {
                node.alpha = state.vis[ty][tx] ? 1.0 : 0.0
            }
        }
    }

    // MARK: — Entity sync

    private func rebuildEntities() {
        guard let state else { return }
        let pKey = playerKey
        let player = makeEntityNode(color: playerColor(state.cls), isPlayer: true, templateId: nil, cls: state.cls)
        player.position = worldPos(state.player.x, state.player.y)
        entityLayer.addChild(player)
        entityNodes[pKey] = player

        for e in state.enemies {
            let n = makeEntityNode(color: e.template.color, isPlayer: false, templateId: e.templateId, cls: "")
            n.position = worldPos(e.x, e.y)
            entityLayer.addChild(n)
            entityNodes[e.uid] = n
            lastEnemyPos[e.uid] = (e.x, e.y)
        }
    }

    private func syncEntities(state: GameState) {
        let pKey = playerKey
        if let pNode = entityNodes[pKey] {
            // Re-add if somehow detached from scene
            if pNode.parent == nil {
                entityLayer.addChild(pNode)
                lastSpriteTarget = CGPoint(x: CGFloat.infinity, y: 0)
            }

            let nx = state.player.x, ny = state.player.y
            let dx = nx - lastPlayerPos.x
            let dy = ny - lastPlayerPos.y
            if abs(dx) >= abs(dy) && dx != 0 {
                playerFacing = dx > 0 ? "east" : "west"
            } else if dy != 0 {
                playerFacing = dy > 0 ? "south" : "north"
            }
            lastPlayerPos = (nx, ny)

            if let sprite = pNode.childNode(withName: "sprite") as? SKSpriteNode {
                sprite.texture = loadTexture("\(playerSpriteName(state.cls))_\(playerFacing)")
            }
            let spriteTarget = worldPos(nx, ny)
            if spriteTarget != lastSpriteTarget {
                let wasInfinite = lastSpriteTarget.x.isInfinite
                lastSpriteTarget = spriteTarget
                if wasInfinite {
                    pNode.removeAction(forKey: "move")
                    pNode.position = spriteTarget
                } else {
                    pNode.run(SKAction.move(to: spriteTarget, duration: 0.12), withKey: "move")
                    // Walk bob: sprite child bounces up-down with each step
                    if let sprite = pNode.childNode(withName: "sprite") as? SKSpriteNode {
                        sprite.run(SKAction.sequence([
                            SKAction.moveBy(x: 0, y: 5, duration: 0.06),
                            SKAction.moveBy(x: 0, y: -5, duration: 0.06)
                        ]), withKey: "bob")
                    }
                }
            }
        }

        let liveIDs = Set(state.enemies.map { $0.uid })
        // Collect dead IDs first — mutating entityNodes while iterating its keys crashes
        let deadIDs = entityNodes.keys.filter { $0 != pKey && !liveIDs.contains($0) }
        for id in deadIDs {
            if let deadNode = entityNodes[id] {
                spawnKillBurst(at: deadNode.position)
                deadNode.run(SKAction.sequence([
                    SKAction.fadeOut(withDuration: 0.18),
                    SKAction.removeFromParent()
                ]), withKey: "death")
            }
            entityNodes.removeValue(forKey: id)
            lastEnemyPos.removeValue(forKey: id)
            enemyFacing.removeValue(forKey: id)
            lastEnemyTarget.removeValue(forKey: id)
        }
        for e in state.enemies {
            if let n = entityNodes[e.uid] {
                if let lastPos = lastEnemyPos[e.uid] {
                    let dx = e.x - lastPos.x, dy = e.y - lastPos.y
                    if abs(dx) >= abs(dy) && dx != 0 {
                        enemyFacing[e.uid] = dx > 0 ? "east" : "west"
                    } else if dy != 0 {
                        enemyFacing[e.uid] = dy > 0 ? "south" : "north"
                    }
                }
                lastEnemyPos[e.uid] = (e.x, e.y)

                let dir = enemyFacing[e.uid] ?? "south"
                if let sprite = n.childNode(withName: "sprite") as? SKSpriteNode {
                    sprite.texture = loadTexture("\(enemySpriteName(e.templateId ?? ""))_\(dir)")
                    sprite.alpha = (e.template.invisible && !e.revealed) ? 0.25 : 1.0
                    // Status effect tint — resets every frame so hit flash overlay still works
                    if e.frozenTurns > 0 {
                        sprite.color = UIColor(hex: "#aaddff"); sprite.colorBlendFactor = 0.65
                    } else if e.poisonedTurns > 0 {
                        sprite.color = UIColor(hex: "#44ee44"); sprite.colorBlendFactor = 0.55
                    } else if e.stunTurns > 0 {
                        sprite.color = UIColor(hex: "#ffee44"); sprite.colorBlendFactor = 0.55
                    } else {
                        sprite.color = UIColor(hex: e.template.color); sprite.colorBlendFactor = 0.45
                    }
                }

                let enemyTarget = worldPos(e.x, e.y)
                if enemyTarget != lastEnemyTarget[e.uid] {
                    let isFirst = lastEnemyTarget[e.uid] == nil
                    lastEnemyTarget[e.uid] = enemyTarget
                    if isFirst {
                        n.removeAction(forKey: "move")
                        n.position = enemyTarget
                    } else {
                        n.run(SKAction.move(to: enemyTarget, duration: 0.12), withKey: "move")
                    }
                }
                let vis = state.isVisible(e.pos)
                n.isHidden = !vis || (!e.revealed && e.template.invisible)
                if let bar = n.childNode(withName: "hpbar") as? SKSpriteNode {
                    let pct = CGFloat(e.hp) / CGFloat(e.maxHp)
                    bar.xScale = max(0, pct)
                    bar.color  = pct > 0.5 ? UIColor(hex: "#22cc44") : pct > 0.25 ? UIColor(hex: "#ddaa00") : UIColor(hex: "#cc2222")
                }
            } else {
                let n = makeEntityNode(color: e.template.color, isPlayer: false, templateId: e.templateId, cls: "")
                let eTarget = worldPos(e.x, e.y)
                n.position = eTarget
                entityLayer.addChild(n)
                entityNodes[e.uid] = n
                lastEnemyPos[e.uid]    = (e.x, e.y)
                lastEnemyTarget[e.uid] = eTarget
            }
        }
    }

    // MARK: — Item sync

    private func rebuildItems() {
        guard let state else { return }
        for item in state.items { addItemNode(item) }
    }

    private func syncItems(state: GameState) {
        let liveIDs = Set(state.items.map { $0.uid })
        for id in itemNodes.keys where !liveIDs.contains(id) {
            if let node = itemNodes[id] {
                spawnPickupBurst(at: node.position)
                node.removeFromParent()
            }
            itemNodes.removeValue(forKey: id)
        }
        for item in state.items {
            if itemNodes[item.uid] == nil { addItemNode(item) }
            let inBounds = item.y >= 0 && item.x >= 0 && item.y < state.vis.count && item.x < (state.vis.first?.count ?? 0)
            itemNodes[item.uid]?.isHidden = inBounds ? !state.vis[item.y][item.x] : true
        }
    }

    private func addItemNode(_ item: GameItem) {
        let pos = worldPos(item.x, item.y)
        let itemSize = CGSize(width: TS * 0.72, height: TS * 0.72)

        switch item.type {
        case "potion":
            let n = SKSpriteNode(texture: loadTexture("potion"), size: itemSize)
            n.position = pos; n.zPosition = 1
            itemLayer.addChild(n); itemNodes[item.uid] = n

        case "scroll":
            let n = SKSpriteNode(texture: loadTexture("scroll"), size: itemSize)
            n.position = pos; n.zPosition = 1
            itemLayer.addChild(n); itemNodes[item.uid] = n

        case "gold":
            let n = SKSpriteNode(texture: loadTexture("gold"), size: itemSize)
            n.position = pos; n.zPosition = 1
            itemLayer.addChild(n); itemNodes[item.uid] = n

        default:
            let (char, color): (String, String)
            switch item.type {
            case "equipment": (char, color) = ("E", "#aaccee")
            case "relic":     (char, color) = ("*", "#ffaa33")
            default:          (char, color) = ("?", "#888888")
            }
            let n = SKLabelNode(text: char)
            n.fontSize    = 20
            n.fontName    = "Courier-Bold"
            n.fontColor   = UIColor(hex: color)
            n.verticalAlignmentMode   = .center
            n.horizontalAlignmentMode = .center
            n.position  = pos
            n.zPosition = 1
            itemLayer.addChild(n); itemNodes[item.uid] = n
        }
    }

    // MARK: — Projectile sync

    private func syncProjectiles(state: GameState) {
        let liveIDs = Set(state.projectiles.map { $0.uid })
        for id in projNodes.keys where !liveIDs.contains(id) {
            projNodes[id]?.removeFromParent()
            projNodes.removeValue(forKey: id)
            lastProjPos.removeValue(forKey: id)
        }
        for proj in state.projectiles {
            let wx = proj.px - CGFloat(GRID_W) * TS / 2
            let wy = CGFloat(GRID_H) * TS / 2 - proj.py
            let wpos = CGPoint(x: wx, y: wy)
            if let n = projNodes[proj.uid] {
                let prev = lastProjPos[proj.uid]
                if prev == nil || prev! != wpos {
                    if let p = prev { spawnProjTrail(at: p, color: proj.color) }
                    n.run(SKAction.move(to: wpos, duration: 0.09), withKey: "projMove")
                    lastProjPos[proj.uid] = wpos
                }
            } else {
                let container = SKNode()
                container.position = wpos
                container.zPosition = 5

                let glow = SKShapeNode(circleOfRadius: 9)
                glow.fillColor   = UIColor(hex: proj.color).withAlphaComponent(0.35)
                glow.strokeColor = .clear
                glow.blendMode   = .add
                container.addChild(glow)

                let core = SKShapeNode(circleOfRadius: 4)
                core.fillColor   = UIColor(hex: proj.color)
                core.strokeColor = UIColor.white.withAlphaComponent(0.6)
                core.lineWidth   = 1
                core.blendMode   = .add
                container.addChild(core)

                projLayer.addChild(container)
                projNodes[proj.uid] = container
            }
        }
    }

    // MARK: — Flash effects

    private func drainFlashes(state: GameState) {
        for f in state.pendingFlashes {
            let flash = SKSpriteNode(color: UIColor(hex: f.color),
                                     size: CGSize(width: TS, height: TS))
            flash.position = worldPos(f.x, f.y)
            flash.alpha    = 0.72
            flash.zPosition = 8
            fxLayer.addChild(flash)
            flash.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.28),
                SKAction.removeFromParent()
            ]))
        }
        state.pendingFlashes.removeAll()
    }

    // MARK: — Damage floats

    private func drainDamageFloats(state: GameState) {
        for df in state.pendingDamageFloats {
            let isCrit = df.text.hasSuffix("!")
            let label = SKLabelNode(text: df.text)
            label.fontSize  = isCrit ? 28 : 19
            label.fontName  = "Courier-Bold"
            label.fontColor = UIColor(hex: df.color)
            label.position  = worldPos(df.x, df.y) + CGPoint(x: 0, y: TS * 0.6)
            label.zPosition = 12
            label.setScale(isCrit ? 1.5 : 0.7)
            fxLayer.addChild(label)
            label.run(SKAction.sequence([
                // Pop-in
                SKAction.scale(to: isCrit ? 1.1 : 1.0, duration: 0.08),
                // Float up then fade
                SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in: -6...6), y: TS * (isCrit ? 1.5 : 1.0), duration: isCrit ? 0.75 : 0.58),
                    SKAction.sequence([
                        SKAction.wait(forDuration: isCrit ? 0.45 : 0.3),
                        SKAction.fadeOut(withDuration: isCrit ? 0.3 : 0.28)
                    ])
                ]),
                SKAction.removeFromParent()
            ]))
        }
        state.pendingDamageFloats.removeAll()
    }

    // MARK: — Entity hit flash + bounce

    private func drainEntityFlashes(state: GameState) {
        for (uid, colorHex) in zip(state.pendingEntityFlashUIDs, state.pendingEntityFlashColors) {
            guard let node = entityNodes[uid] else { continue }
            let isBoss = state.enemies.first { $0.uid == uid }?.template.isBoss ?? false
            // Scale bounce — bigger for boss
            let bounceScale: CGFloat = isBoss ? 1.40 : 1.25
            node.run(SKAction.sequence([
                SKAction.scale(to: bounceScale, duration: 0.05),
                SKAction.scale(to: 1.0, duration: isBoss ? 0.18 : 0.12)
            ]), withKey: "hitBounce")
            // Additive color overlay
            let overlayW: CGFloat = isBoss ? TS * 2.2 : TS * 1.5
            let overlay = SKSpriteNode(color: UIColor(hex: colorHex),
                                       size: CGSize(width: overlayW, height: overlayW * 1.2))
            overlay.alpha = isBoss ? 1.0 : 0.80; overlay.zPosition = 3; overlay.blendMode = .add
            node.addChild(overlay)
            overlay.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: isBoss ? 0.28 : 0.16),
                SKAction.removeFromParent()
            ]))
            // Boss: extra ring burst + camera shake
            if isBoss {
                spawnBossHitBurst(at: node.position, color: colorHex)
                shakeCameraNode(intensity: 5, duration: 0.22)
            }
        }
        state.pendingEntityFlashUIDs.removeAll()
        state.pendingEntityFlashColors.removeAll()
    }

    private func spawnBossHitBurst(at pos: CGPoint, color: String) {
        let ring = SKShapeNode(circleOfRadius: TS * 0.5)
        ring.fillColor   = .clear
        ring.strokeColor = UIColor(hex: color)
        ring.lineWidth   = 3; ring.blendMode = .add
        ring.position    = pos; ring.zPosition = 14
        fxLayer.addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 3.0, duration: 0.35),
                SKAction.fadeOut(withDuration: 0.35)
            ]),
            SKAction.removeFromParent()
        ]))
        for _ in 0..<16 {
            let r = CGFloat.random(in: 2.5...6)
            let p = SKShapeNode(circleOfRadius: r)
            p.fillColor   = UIColor(hex: color); p.strokeColor = .clear
            p.blendMode   = .add; p.position = pos; p.zPosition = 14
            fxLayer.addChild(p)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist  = CGFloat.random(in: TS * 0.4...TS * 1.4)
            p.run(SKAction.sequence([
                SKAction.group([
                    SKAction.move(by: CGVector(dx: cos(angle)*dist, dy: sin(angle)*dist), duration: 0.42),
                    SKAction.fadeOut(withDuration: 0.42),
                    SKAction.scale(to: 0.1, duration: 0.42)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func shakeCameraNode(intensity: CGFloat, duration: Double) {
        let steps = Int(duration / 0.04)
        var actions: [SKAction] = []
        for _ in 0..<steps {
            let dx = CGFloat.random(in: -intensity...intensity)
            let dy = CGFloat.random(in: -intensity...intensity)
            actions.append(SKAction.moveBy(x: dx, y: dy, duration: 0.04))
        }
        actions.append(contentsOf: [
            SKAction.move(to: cameraNode.position, duration: 0.04),
        ])
        cameraNode.run(SKAction.sequence(actions), withKey: "shake")
    }

    // MARK: — Player lunge (attack) and wall bump

    private func drainPlayerLunge(state: GameState) {
        guard let dir = state.pendingPlayerLunge else { return }
        state.pendingPlayerLunge = nil
        guard let pNode = entityNodes[playerKey] else { return }

        let dest = Point(x: state.player.x + dir.x, y: state.player.y + dir.y)
        let isWallBump = !state.enemies.contains { $0.x == dest.x && $0.y == dest.y }
        let mag: CGFloat = isWallBump ? 0.22 : 0.38

        pNode.removeAction(forKey: "move")
        if !lastSpriteTarget.x.isInfinite { pNode.position = lastSpriteTarget }
        let lx = CGFloat(dir.x) * TS * mag
        let ly = -CGFloat(dir.y) * TS * mag
        pNode.run(SKAction.sequence([
            SKAction.moveBy(x: lx, y: ly, duration: isWallBump ? 0.05 : 0.07),
            SKAction.moveBy(x: -lx, y: -ly, duration: isWallBump ? 0.09 : 0.11)
        ]), withKey: "lunge")
    }

    // MARK: — Item pickup burst

    private func spawnPickupBurst(at pos: CGPoint) {
        let colors: [UIColor] = [UIColor(hex: "#ffee88"), UIColor(hex: "#ffffff"),
                                  UIColor(hex: "#88ddff"), UIColor(hex: "#ffaa44")]
        for i in 0..<6 {
            let r = CGFloat.random(in: 1.5...3.5)
            let p = SKShapeNode(circleOfRadius: r)
            p.fillColor   = colors[i % colors.count]
            p.strokeColor = .clear; p.blendMode = .add
            p.position    = pos; p.zPosition = 12
            fxLayer.addChild(p)
            let angle = CGFloat(i) / 6 * 2 * .pi + CGFloat.random(in: -0.4...0.4)
            let dist  = CGFloat.random(in: TS * 0.25...TS * 0.65)
            p.run(SKAction.sequence([
                SKAction.group([
                    SKAction.move(by: CGVector(dx: cos(angle)*dist, dy: sin(angle)*dist), duration: 0.32),
                    SKAction.fadeOut(withDuration: 0.32)
                ]),
                SKAction.removeFromParent()
            ]))
        }
        // Rising sparkle label
        let star = SKLabelNode(text: "✦")
        star.fontSize  = 14; star.fontColor = UIColor(hex: "#ffee88")
        star.position  = pos + CGPoint(x: 0, y: TS * 0.3)
        star.zPosition = 13; star.blendMode = .add
        fxLayer.addChild(star)
        star.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: TS * 0.7, duration: 0.45),
                SKAction.sequence([
                    SKAction.wait(forDuration: 0.2),
                    SKAction.fadeOut(withDuration: 0.25)
                ])
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: — Projectile trail

    private func spawnProjTrail(at pos: CGPoint, color: String) {
        let trail = SKShapeNode(circleOfRadius: 3.5)
        trail.fillColor   = UIColor(hex: color).withAlphaComponent(0.55)
        trail.strokeColor = .clear
        trail.blendMode   = .add
        trail.position    = pos
        trail.zPosition   = 3
        projLayer.addChild(trail)
        trail.run(SKAction.sequence([
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.22),
                SKAction.scale(to: 0.3, duration: 0.22)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: — Enemy attack lunge

    private func drainEnemyLunges(state: GameState) {
        for lunge in state.pendingEnemyLunges {
            guard let node = entityNodes[lunge.uid] else { continue }
            let lx = CGFloat(lunge.dx) * TS * 0.30
            let ly = -CGFloat(lunge.dy) * TS * 0.30
            node.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.10),
                SKAction.moveBy(x: lx, y: ly, duration: 0.07),
                SKAction.moveBy(x: -lx, y: -ly, duration: 0.11)
            ]), withKey: "enemyLunge")
        }
        state.pendingEnemyLunges.removeAll()
    }

    // MARK: — Kill burst particles

    private func spawnKillBurst(at pos: CGPoint) {
        let colors: [UIColor] = [
            UIColor(hex: "#ff4444"), UIColor(hex: "#ff8844"),
            UIColor(hex: "#ffcc44"), UIColor(hex: "#ffffff")
        ]
        for _ in 0..<10 {
            let r = CGFloat.random(in: 2...5)
            let p = SKShapeNode(circleOfRadius: r)
            p.fillColor   = colors.randomElement()!
            p.strokeColor = .clear
            p.position    = pos
            p.zPosition   = 11
            p.blendMode   = .add
            fxLayer.addChild(p)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist  = CGFloat.random(in: TS * 0.3...TS * 1.1)
            p.run(SKAction.sequence([
                SKAction.group([
                    SKAction.move(by: CGVector(dx: cos(angle) * dist, dy: sin(angle) * dist), duration: 0.38),
                    SKAction.fadeOut(withDuration: 0.38),
                    SKAction.scale(to: 0.05, duration: 0.38)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: — Camera

    private func updateCamera() {
        guard let state else { return }
        var target = worldPos(state.player.x, state.player.y)

        let halfW = size.width / 2
        let halfH = size.height / 2
        let mapW  = CGFloat(GRID_W) * TS
        let mapH  = CGFloat(GRID_H) * TS

        // Horizontal clamp
        let minX = -mapW / 2 + halfW
        let maxX =  mapW / 2 - halfW
        if minX < maxX { target.x = max(minX, min(maxX, target.x)) }

        // Vertical clamp — HUD ~85pt top, controls ~200pt bottom
        let hudH:  CGFloat = 85
        let ctrlH: CGFloat = 200
        let minCamY = -mapH / 2 + halfH - ctrlH
        let maxCamY =  mapH / 2 - halfH + hudH
        if minCamY < maxCamY {
            target.y = max(minCamY, min(maxCamY, target.y))
        } else {
            target.y = (minCamY + maxCamY) / 2
        }

        guard target != lastCameraTarget else { return }
        let isInstant = lastCameraTarget.x.isInfinite // floor transition: snap instantly
        lastCameraTarget = target
        if isInstant {
            cameraNode.removeAllActions()
            cameraNode.position = target
        } else {
            // Camera lag (0.28s) — character visibly moves across screen before map catches up
            cameraNode.run(SKAction.move(to: target, duration: 0.28), withKey: "camera")
        }
    }

    // MARK: — Tile node factory

    private func makeSpecialGlow(color: String, radius: CGFloat, period: Double) -> SKShapeNode {
        let glow = SKShapeNode(circleOfRadius: radius)
        glow.fillColor   = UIColor(hex: color).withAlphaComponent(0.22)
        glow.strokeColor = UIColor(hex: color).withAlphaComponent(0.85)
        glow.lineWidth   = 1.5
        glow.glowWidth   = 10
        glow.zPosition   = 0.6
        glow.blendMode   = .add
        glow.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.9, duration: period),
            SKAction.fadeAlpha(to: 0.15, duration: period)
        ])))
        return glow
    }

    private func makeTileNode(_ tile: Tile, x: Int, y: Int) -> SKNode {
        let container = SKNode()
        let size = CGSize(width: TS, height: TS)

        switch tile {
        case .floor, .doorOpen:
            let base = SKSpriteNode(texture: floorTex, size: size)
            base.zPosition = 0
            container.addChild(base)

        case .wall:
            let base = SKSpriteNode(texture: wallTex, size: size)
            base.zPosition = 0
            base.color = UIColor(hex: "#334466"); base.colorBlendFactor = 0.25
            container.addChild(base)
            // Thin bright edge line on top — creates depth separation from floor
            let edge = SKSpriteNode(color: UIColor(hex: "#6688aa").withAlphaComponent(0.55),
                                    size: CGSize(width: TS, height: 1.5))
            edge.position  = CGPoint(x: 0, y: TS * 0.48)
            edge.zPosition = 0.2
            container.addChild(edge)

        case .secret:
            let base = SKSpriteNode(texture: floorTex, size: size)
            base.zPosition = 0; base.alpha = 0.65; container.addChild(base)
            // Faint blue shimmer — subtle hint if looking carefully
            let shimmer = SKShapeNode(rect: CGRect(x: -TS*0.42, y: -TS*0.42, width: TS*0.84, height: TS*0.84))
            shimmer.fillColor   = UIColor(hex: "#1133cc").withAlphaComponent(0.12)
            shimmer.strokeColor = UIColor(hex: "#4466ee").withAlphaComponent(0.40)
            shimmer.lineWidth   = 0.8; shimmer.zPosition = 0.5; shimmer.blendMode = .add
            container.addChild(shimmer)
            shimmer.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.7, duration: 2.0),
                SKAction.fadeAlpha(to: 0.05, duration: 2.0)
            ])))

        case .door:
            let base = SKSpriteNode(texture: floorTex, size: size)
            base.zPosition = 0; container.addChild(base)
            let obj = SKSpriteNode(texture: loadTexture("door"), size: size)
            obj.zPosition = 0.5; container.addChild(obj)
            // Amber border frame — makes doors clearly distinguishable
            let frame = SKShapeNode(rect: CGRect(x: -TS*0.46, y: -TS*0.46, width: TS*0.92, height: TS*0.92), cornerRadius: 2)
            frame.fillColor   = UIColor(hex: "#aa7722").withAlphaComponent(0.10)
            frame.strokeColor = UIColor(hex: "#cc9933").withAlphaComponent(0.72)
            frame.lineWidth   = 1.5; frame.zPosition = 0.7
            container.addChild(frame)

        case .stairs:
            let base = SKSpriteNode(texture: floorTex, size: size)
            base.zPosition = 0; container.addChild(base)
            let obj = SKSpriteNode(texture: loadTexture("stairs"), size: size)
            obj.zPosition = 0.5; container.addChild(obj)
            container.addChild(makeSpecialGlow(color: "#44ff88", radius: TS * 0.38, period: 1.0))

        case .shop:
            let base = SKSpriteNode(texture: floorTex, size: size)
            base.zPosition = 0; container.addChild(base)
            let obj = SKSpriteNode(texture: loadTexture("shop"), size: size)
            obj.zPosition = 0.5; container.addChild(obj)
            container.addChild(makeSpecialGlow(color: "#ffcc33", radius: TS * 0.32, period: 1.2))

        case .altar:
            let base = SKSpriteNode(texture: floorTex, size: size)
            base.zPosition = 0; container.addChild(base)
            let obj = SKSpriteNode(texture: loadTexture("altar"), size: size)
            obj.zPosition = 0.5; container.addChild(obj)
            container.addChild(makeSpecialGlow(color: "#cc44ff", radius: TS * 0.32, period: 1.4))
        }

        return container
    }

    // MARK: — Entity node factory

    private func makeEntityNode(color: String, isPlayer: Bool, templateId: String?, cls: String) -> SKNode {
        let container = SKNode()
        container.zPosition = isPlayer ? 5 : 0

        let uiColor = UIColor(hex: color)

        // Glow ring for player and boss
        if isPlayer || templateId == "marguento" {
            let r: CGFloat = isPlayer ? TS * 0.46 : TS * 0.55
            let glow = SKShapeNode(circleOfRadius: r)
            glow.fillColor   = uiColor.withAlphaComponent(isPlayer ? 0.15 : 0.25)
            glow.strokeColor = uiColor.withAlphaComponent(0.65)
            glow.lineWidth   = 2
            glow.glowWidth   = isPlayer ? 10 : 14
            glow.zPosition   = 1
            container.addChild(glow)
            if isPlayer {
                let pulse = SKAction.repeatForever(SKAction.sequence([
                    SKAction.group([
                        SKAction.fadeAlpha(to: 0.9, duration: 0.7),
                        SKAction.scale(to: 1.15, duration: 0.7)
                    ]),
                    SKAction.group([
                        SKAction.fadeAlpha(to: 0.2, duration: 0.7),
                        SKAction.scale(to: 0.85, duration: 0.7)
                    ])
                ]))
                glow.run(pulse, withKey: "pulse")
            }
        }

        // Character sprite — canvas is ~40% larger than character body.
        // Sprites are generated as near-black on transparent; blend toward entity color to make visible.
        let isBoss = templateId == "marguento"
        let spriteScale: CGFloat = isBoss ? 2.2 : 1.8
        let spriteSize = CGSize(width: TS * spriteScale, height: TS * spriteScale)
        let texName: String
        if isPlayer {
            texName = "\(playerSpriteName(cls))_south"
        } else {
            texName = "\(enemySpriteName(templateId ?? ""))_south"
        }
        let sprite = SKSpriteNode(texture: loadTexture(texName), size: spriteSize)
        sprite.color = uiColor
        sprite.colorBlendFactor = isPlayer ? 0.55 : 0.45
        sprite.zPosition = 2
        sprite.name = "sprite"
        container.addChild(sprite)

        // HP bar (enemies only)
        if !isPlayer {
            let barBg = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.7),
                                      size: CGSize(width: TS * 0.72, height: 3.5))
            barBg.position  = CGPoint(x: 0, y: -(TS * 0.5 + 5))
            barBg.zPosition = 3.9
            container.addChild(barBg)

            let bar = SKSpriteNode(color: UIColor(hex: "#22cc44"),
                                   size: CGSize(width: TS * 0.68, height: 2.5))
            bar.name        = "hpbar"
            bar.zPosition   = 4
            bar.anchorPoint = CGPoint(x: 0, y: 0.5)
            bar.position    = CGPoint(x: -(TS * 0.34), y: -(TS * 0.5 + 5))
            container.addChild(bar)
        }

        return container
    }

    // MARK: — Texture helpers

    private func loadTexture(_ name: String) -> SKTexture {
        if let cached = textureCache[name] { return cached }
        let t = SKTexture(imageNamed: name)
        t.filteringMode = .nearest
        textureCache[name] = t
        return t
    }

    private func playerSpriteName(_ cls: String) -> String {
        switch cls {
        case "warrior": return "warrior"
        case "mage":    return "mage"
        case "rogue":   return "rogue"
        default:        return "warrior"
        }
    }

    private func enemySpriteName(_ templateId: String) -> String {
        switch templateId {
        case "skeleton":          return "skeleton"
        case "skeleton_archer":   return "skeleton_archer"
        case "zombie":            return "zombie"
        case "ghost":             return "ghost"
        case "lich":              return "lich"
        case "wraith":            return "wraith"
        case "bone_giant",
             "bone_golem":        return "bone_golem"
        case "death_knight":      return "death_knight"
        case "gargoyle":          return "gargoyle"
        case "banshee":           return "banshee"
        case "vampire":           return "vampire"
        case "shadow":            return "shadow_demon"
        case "bone_mage":         return "bone_mage"
        case "marguento":         return "marguento"
        default:                  return "skeleton"
        }
    }

    private func playerColor(_ cls: String) -> String {
        switch cls {
        case "warrior": return "#e8c870"
        case "mage":    return "#8899ff"
        case "rogue":   return "#55ee88"
        default:        return "#e8e8ff"
        }
    }

    // MARK: — Helpers

    private var playerKey: UUID {
        UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    }

    private func worldPos(_ x: Int, _ y: Int) -> CGPoint {
        let ox = -CGFloat(GRID_W) * TS / 2 + TS / 2
        let oy =  CGFloat(GRID_H) * TS / 2 - TS / 2
        return CGPoint(x: ox + CGFloat(x) * TS, y: oy - CGFloat(y) * TS)
    }
}

// MARK: — CGPoint helper

private func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}
