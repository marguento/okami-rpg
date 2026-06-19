import Foundation

func astar(state: GameState, sx: Int, sy: Int, ex: Int, ey: Int) -> [Point] {
    struct Node {
        let x, y, g: Int
        let f: Int
        let parent: Int?   // index into closed list
    }

    let key: (Int, Int) -> Int = { x, y in x + y * GRID_W }
    var open = [Node(x: sx, y: sy, g: 0, f: dist(sx, sy, ex, ey), parent: nil)]
    var closed: [Node] = []
    var gMap: [Int: Int] = [key(sx, sy): 0]
    var iter = 0

    while !open.isEmpty, iter < 200 {
        iter += 1
        open.sort { $0.f < $1.f }
        let cur = open.removeFirst()
        if cur.x == ex && cur.y == ey {
            var path: [Point] = []
            var node = cur
            while let pi = node.parent {
                path.insert(Point(x: node.x, y: node.y), at: 0)
                node = closed[pi]
            }
            return path
        }
        let closedIdx = closed.count
        closed.append(cur)
        for (dx, dy) in [(0,1),(0,-1),(1,0),(-1,0)] {
            let nx = cur.x + dx; let ny = cur.y + dy
            guard nx >= 0, ny >= 0, nx < GRID_W, ny < GRID_H else { continue }
            let t = state.map[ny][nx]
            guard t != .wall && t != .door else { continue }
            let nk = key(nx, ny)
            let ng = cur.g + 1
            if ng >= (gMap[nk] ?? Int.max) { continue }
            if closed.contains(where: { $0.x == nx && $0.y == ny }) { continue }
            gMap[nk] = ng
            open.append(Node(x: nx, y: ny, g: ng, f: ng + dist(nx, ny, ex, ey), parent: closedIdx))
        }
    }
    return []
}

private func dist(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) -> Int { abs(x1 - x0) + abs(y1 - y0) }
