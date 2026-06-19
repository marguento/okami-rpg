import Foundation

func computeVision(state: GameState) {
    let W = GRID_W; let H = GRID_H
    var vis = Array(repeating: Array(repeating: false, count: W), count: H)

    let p = state.player
    let r = state.sightRadius
    for dy in -r...r { for dx in -r...r {
        guard dx*dx + dy*dy <= r*r else { continue }
        let tx = p.x + dx; let ty = p.y + dy
        guard tx >= 0, ty >= 0, tx < W, ty < H else { continue }
        if hasLOS(state: state, x0: p.x, y0: p.y, x1: tx, y1: ty) {
            vis[ty][tx] = true
            state.seen[ty][tx] = true
        }
    }}

    // Torch illumination
    let torchR = 3
    for torch in state.torches {
        guard state.seen.indices.contains(torch.y), state.seen[torch.y].indices.contains(torch.x),
              state.seen[torch.y][torch.x] else { continue }
        for dy in -torchR...torchR { for dx in -torchR...torchR {
            guard dx*dx + dy*dy <= torchR*torchR else { continue }
            let tx = torch.x + dx; let ty = torch.y + dy
            guard tx >= 0, ty >= 0, tx < W, ty < H else { continue }
            if hasLOS(state: state, x0: torch.x, y0: torch.y, x1: tx, y1: ty) {
                vis[ty][tx] = true
                state.seen[ty][tx] = true
            }
        }}
    }

    // Doors: always visible at distance 1
    for door in state.doors {
        if abs(door.x - p.x) <= 1 && abs(door.y - p.y) <= 1 {
            vis[door.y][door.x] = true
            state.seen[door.y][door.x] = true
        }
    }

    // Secret rooms
    for y in 0..<H { for x in 0..<W {
        guard state.map[y][x] == .secret else { continue }
        if state.cls == "rogue" && Point(x: x, y: y).distance(to: state.playerPos) <= 3 {
            state.seen[y][x] = true
        }
        if Point(x: x, y: y) == state.playerPos {
            vis[y][x] = true; state.seen[y][x] = true
        }
    }}

    // Seeker relic reveals all secrets on minimap
    if state.flags.seeker {
        for y in 0..<H { for x in 0..<W {
            if state.map[y][x] == .secret { state.seen[y][x] = true }
        }}
    }

    state.vis = vis

    // Trap detection
    let trapRadius = state.cls == "rogue" ? 5 : 2
    for i in state.traps.indices {
        if !state.traps[i].triggered && state.traps[i].pos.distance(to: state.playerPos) <= trapRadius {
            state.traps[i].revealed = true
        }
    }

    autoAim(state: state)
}

func hasLOS(state: GameState, x0: Int, y0: Int, x1: Int, y1: Int) -> Bool {
    var cx = x0; var cy = y0
    let dx = abs(x1 - x0); let dy = abs(y1 - y0)
    let sx = x0 < x1 ? 1 : -1; let sy = y0 < y1 ? 1 : -1
    var err = dx - dy
    while cx != x1 || cy != y1 {
        let t = (cx >= 0 && cy >= 0 && cx < GRID_W && cy < GRID_H) ? state.map[cy][cx] : .wall
        if (t == .wall || t == .door) && !(cx == x0 && cy == y0) { return false }
        let e2 = 2 * err
        if e2 > -dy { err -= dy; cx += sx }
        if e2 <  dx { err += dx; cy += sy }
    }
    return true
}

func autoAim(state: GameState) {
    let dirs = [(1,0),(-1,0),(0,-1),(0,1)]
    var best = 999; var bestDir = (1,0)
    for d in dirs {
        for s in 1...10 {
            let tx = state.player.x + d.0 * s
            let ty = state.player.y + d.1 * s
            guard tx >= 0, ty >= 0, tx < GRID_W, ty < GRID_H else { break }
            let t = state.map[ty][tx]
            if t == .wall || t == .door { break }
            if state.enemy(at: Point(x: tx, y: ty)) != nil {
                if s < best { best = s; bestDir = d }
                break
            }
        }
    }
    state.aimDx = bestDir.0; state.aimDy = bestDir.1
}
