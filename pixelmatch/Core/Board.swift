import Foundation

// MARK: - Data Structures

struct TileMatch {
    var positions: [(row: Int, col: Int)]
    var isHorizontal: Bool
    var createsSpecial: TileSpecial
    var specialPosition: (row: Int, col: Int)?
    var gemColor: GemColor
}

struct TileFall {
    var tile: Tile
    var fromRow: Int
    var fromCol: Int
    var toRow: Int
    var toCol: Int
}

struct NewTileInfo {
    var tile: Tile
    var column: Int
    var spawnRowOffset: Int // negative = above board
}

// MARK: - Board

final class Board {
    let rows: Int
    let cols: Int
    var grid: [[Tile?]]
    var availableColors: [GemColor]

    init(rows: Int, cols: Int, availableColors: [GemColor]) {
        self.rows = rows
        self.cols = cols
        self.availableColors = availableColors
        self.grid = Array(repeating: Array(repeating: nil, count: cols), count: rows)
    }

    // MARK: - Setup

    func setup(from level: Level) {
        // Place holes
        for pos in level.holes {
            guard valid(pos) else { continue }
            grid[pos.row][pos.col] = Tile(row: pos.row, col: pos.col, color: .red, isHole: true)
        }

        // Fill remaining cells with random, no-initial-match tiles
        for r in 0..<rows {
            for c in 0..<cols {
                if grid[r][c] == nil {
                    grid[r][c] = makeTile(at: (r, c))
                }
            }
        }

        // Apply obstacles
        for obs in level.obstacles {
            guard valid(obs.position) else { continue }
            grid[obs.position.row][obs.position.col]?.obstacle = obs.type
        }
    }

    private func makeTile(at pos: (row: Int, col: Int), avoid: [GemColor] = []) -> Tile {
        var forbidden = avoid
        if pos.col >= 2,
           let l1 = grid[pos.row][pos.col - 1], !l1.isHole,
           let l2 = grid[pos.row][pos.col - 2], !l2.isHole,
           l1.gemColor == l2.gemColor {
            forbidden.append(l1.gemColor)
        }
        if pos.row >= 2,
           let u1 = grid[pos.row - 1][pos.col], !u1.isHole,
           let u2 = grid[pos.row - 2][pos.col], !u2.isHole,
           u1.gemColor == u2.gemColor {
            forbidden.append(u1.gemColor)
        }
        var pool = availableColors.filter { !forbidden.contains($0) }
        if pool.isEmpty { pool = availableColors }
        return Tile(row: pos.row, col: pos.col, color: pool.randomElement()!)
    }

    // MARK: - Helpers

    func valid(_ pos: (row: Int, col: Int)) -> Bool {
        pos.row >= 0 && pos.row < rows && pos.col >= 0 && pos.col < cols
    }

    func isValidPosition(_ pos: (row: Int, col: Int)) -> Bool { valid(pos) }

    func tile(at pos: (row: Int, col: Int)) -> Tile? {
        guard valid(pos) else { return nil }
        return grid[pos.row][pos.col]
    }

    func isAdjacent(_ a: (row: Int, col: Int), _ b: (row: Int, col: Int)) -> Bool {
        let dr = abs(a.row - b.row), dc = abs(a.col - b.col)
        return (dr == 1 && dc == 0) || (dr == 0 && dc == 1)
    }

    // MARK: - Swap

    func canSwap(_ a: (row: Int, col: Int), _ b: (row: Int, col: Int)) -> Bool {
        guard isAdjacent(a, b) else { return false }
        guard let ta = tile(at: a), let tb = tile(at: b) else { return false }
        guard !ta.isHole && !tb.isHole else { return false }
        guard ta.isMovable && tb.isMovable else { return false }

        if ta.special == .colorBomb || tb.special == .colorBomb { return true }

        doSwap(a, b)
        let hasMatch = !detectMatches().isEmpty
        doSwap(a, b)
        return hasMatch
    }

    func doSwap(_ a: (row: Int, col: Int), _ b: (row: Int, col: Int)) {
        let ta = grid[a.row][a.col]
        let tb = grid[b.row][b.col]
        grid[a.row][a.col] = tb
        grid[b.row][b.col] = ta
        ta?.row = b.row; ta?.col = b.col
        tb?.row = a.row; tb?.col = a.col
    }

    // MARK: - Match Detection

    func detectMatches() -> [TileMatch] {
        var matches: [TileMatch] = []

        // Horizontal
        for r in 0..<rows {
            var c = 0
            while c < cols {
                guard let anchor = grid[r][c], anchor.isMatchable, anchor.special == .none else {
                    c += 1; continue
                }
                var len = 1
                while c + len < cols,
                      let next = grid[r][c + len],
                      next.isMatchable, next.special == .none,
                      next.gemColor == anchor.gemColor { len += 1 }
                if len >= 3 {
                    let positions = (0..<len).map { (row: r, col: c + $0) }
                    let sp = specialKind(len: len, isH: true)
                    let spPos = sp != .none ? positions[len / 2] : nil
                    matches.append(TileMatch(positions: positions, isHorizontal: true,
                                             createsSpecial: sp, specialPosition: spPos,
                                             gemColor: anchor.gemColor))
                    c += len
                } else { c += 1 }
            }
        }

        // Vertical
        for c in 0..<cols {
            var r = 0
            while r < rows {
                guard let anchor = grid[r][c], anchor.isMatchable, anchor.special == .none else {
                    r += 1; continue
                }
                var len = 1
                while r + len < rows,
                      let next = grid[r + len][c],
                      next.isMatchable, next.special == .none,
                      next.gemColor == anchor.gemColor { len += 1 }
                if len >= 3 {
                    let positions = (0..<len).map { (row: r + $0, col: c) }
                    let sp = specialKind(len: len, isH: false)
                    let spPos = sp != .none ? positions[len / 2] : nil
                    matches.append(TileMatch(positions: positions, isHorizontal: false,
                                             createsSpecial: sp, specialPosition: spPos,
                                             gemColor: anchor.gemColor))
                    r += len
                } else { r += 1 }
            }
        }

        return mergeIntoWrapped(matches)
    }

    private func specialKind(len: Int, isH: Bool) -> TileSpecial {
        if len >= 5  { return .colorBomb }
        if len == 4  { return isH ? .stripedH : .stripedV }
        return .none
    }

    private func mergeIntoWrapped(_ matches: [TileMatch]) -> [TileMatch] {
        guard matches.count >= 2 else { return matches }
        var result = matches
        var remove = IndexSet()

        for i in 0..<matches.count {
            guard !remove.contains(i) else { continue }
            for j in (i + 1)..<matches.count {
                guard !remove.contains(j) else { continue }
                guard matches[i].isHorizontal != matches[j].isHorizontal else { continue }

                let setI = Set(matches[i].positions.map { "\($0.row)_\($0.col)" })
                let setJ = Set(matches[j].positions.map { "\($0.row)_\($0.col)" })
                guard let inter = setI.intersection(setJ).first else { continue }

                let parts = inter.split(separator: "_")
                let interPos = (row: Int(parts[0])!, col: Int(parts[1])!)

                let all = Array(setI.union(setJ)).compactMap { s -> (row: Int, col: Int)? in
                    let p = s.split(separator: "_")
                    guard p.count == 2 else { return nil }
                    return (row: Int(p[0])!, col: Int(p[1])!)
                }
                result[i] = TileMatch(positions: all, isHorizontal: matches[i].isHorizontal,
                                      createsSpecial: .wrapped, specialPosition: interPos,
                                      gemColor: matches[i].gemColor)
                remove.insert(j)
            }
        }
        return result.enumerated().filter { !remove.contains($0.offset) }.map { $0.element }
    }

    // MARK: - Remove Tiles

    struct RemoveResult {
        var removedPositions: [(row: Int, col: Int)]
        var jellyReduced: [(row: Int, col: Int)]
        var iceCleared: [(row: Int, col: Int)]
        var score: Int
    }

    func removeTiles(at positions: [(row: Int, col: Int)],
                     specialPos: (row: Int, col: Int)? = nil,
                     newSpecial: TileSpecial = .none,
                     cascadeLevel: Int = 0) -> RemoveResult {
        var removed: [(row: Int, col: Int)] = []
        var jellyReduced: [(row: Int, col: Int)] = []
        var iceCleared: [(row: Int, col: Int)] = []
        var score = 0
        let multiplier = 1 + cascadeLevel

        for pos in positions {
            guard valid(pos), let tile = grid[pos.row][pos.col], !tile.isHole else { continue }

            if let sp = specialPos, sp.row == pos.row && sp.col == pos.col, newSpecial != .none {
                tile.special = newSpecial
                score += GameConstants.scorePerSpecial
                continue
            }

            switch tile.obstacle {
            case .jelly2:
                tile.obstacle = .jelly1
                jellyReduced.append(pos)
                score += GameConstants.scorePerTile * multiplier
            case .jelly1:
                tile.obstacle = .none
                grid[pos.row][pos.col] = nil
                removed.append(pos)
                jellyReduced.append(pos)
                score += GameConstants.scorePerTile * multiplier
            case .ice:
                tile.obstacle = .none
                iceCleared.append(pos)
                score += GameConstants.scorePerTile * multiplier
                // tile stays, just freed
            case .stone:
                continue // immovable
            default:
                grid[pos.row][pos.col] = nil
                removed.append(pos)
                score += GameConstants.scorePerTile * multiplier
            }
        }

        // Damage chocolate adjacent to removed tiles
        var chocolatePositions: [(row: Int, col: Int)] = []
        for pos in removed {
            for (dr, dc) in [(-1,0),(1,0),(0,-1),(0,1)] {
                let nr = pos.row + dr, nc = pos.col + dc
                guard valid((nr, nc)), let t = grid[nr][nc], t.obstacle == .chocolate else { continue }
                t.obstacle = .none
                chocolatePositions.append((nr, nc))
            }
        }

        return RemoveResult(removedPositions: removed + chocolatePositions,
                            jellyReduced: jellyReduced,
                            iceCleared: iceCleared,
                            score: score)
    }

    // MARK: - Special Activation

    func positionsForSpecial(_ special: TileSpecial,
                              at pos: (row: Int, col: Int),
                              targetColor: GemColor? = nil) -> [(row: Int, col: Int)] {
        switch special {
        case .stripedH:
            return (0..<cols).compactMap { c in
                guard let t = grid[pos.row][c], !t.isHole, t.obstacle != .stone else { return nil }
                return (row: pos.row, col: c)
            }
        case .stripedV:
            return (0..<rows).compactMap { r in
                guard let t = grid[r][pos.col], !t.isHole, t.obstacle != .stone else { return nil }
                return (row: r, col: pos.col)
            }
        case .wrapped:
            var result: [(row: Int, col: Int)] = []
            for dr in -2...2 {
                for dc in -2...2 {
                    if abs(dr) == 2 && abs(dc) == 2 { continue }
                    let nr = pos.row + dr, nc = pos.col + dc
                    guard valid((nr, nc)), let t = grid[nr][nc], !t.isHole, t.obstacle != .stone else { continue }
                    result.append((nr, nc))
                }
            }
            return result
        case .colorBomb:
            guard let color = targetColor else { return [] }
            var result: [(row: Int, col: Int)] = []
            for r in 0..<rows {
                for c in 0..<cols {
                    guard let t = grid[r][c], !t.isHole, t.gemColor == color else { continue }
                    result.append((r, c))
                }
            }
            return result
        case .none:
            return []
        }
    }

    // MARK: - Gravity & Refill

    func applyGravity() -> [TileFall] {
        var falls: [TileFall] = []
        for c in 0..<cols {
            var writeRow = rows - 1
            for r in stride(from: rows - 1, through: 0, by: -1) {
                if let t = grid[r][c], !t.isHole {
                    if r != writeRow {
                        falls.append(TileFall(tile: t, fromRow: r, fromCol: c, toRow: writeRow, toCol: c))
                        grid[writeRow][c] = t
                        grid[r][c] = nil
                        t.row = writeRow; t.col = c
                    }
                    writeRow -= 1
                }
            }
        }
        return falls
    }

    func fillFromTop() -> [NewTileInfo] {
        var newTiles: [NewTileInfo] = []
        for c in 0..<cols {
            var spawnOffset = -1
            for r in 0..<rows {
                if grid[r][c] == nil {
                    let t = makeTile(at: (r, c))
                    grid[r][c] = t
                    newTiles.append(NewTileInfo(tile: t, column: c, spawnRowOffset: spawnOffset))
                    spawnOffset -= 1
                }
            }
        }
        return newTiles
    }

    // MARK: - Chocolate Spread

    func spreadChocolate() -> [(row: Int, col: Int)] {
        var chocolatePositions: [(row: Int, col: Int)] = []
        var newChocolate: [(row: Int, col: Int)] = []

        for r in 0..<rows {
            for c in 0..<cols {
                if let t = grid[r][c], t.obstacle == .chocolate {
                    chocolatePositions.append((r, c))
                }
            }
        }

        // Each chocolate has a chance to spread to one random adjacent empty tile
        for pos in chocolatePositions {
            var adjacents: [(row: Int, col: Int)] = []
            for (dr, dc) in [(-1,0),(1,0),(0,-1),(0,1)] {
                let nr = pos.row + dr, nc = pos.col + dc
                guard valid((nr, nc)), let t = grid[nr][nc], !t.isHole,
                      t.obstacle == .none, t.special == .none else { continue }
                adjacents.append((nr, nc))
            }
            if let target = adjacents.randomElement(), Int.random(in: 0..<3) == 0 {
                grid[target.row][target.col]?.obstacle = .chocolate
                newChocolate.append(target)
            }
        }
        return newChocolate
    }

    // MARK: - Deadlock

    func hasPossibleMove() -> Bool {
        for r in 0..<rows {
            for c in 0..<cols {
                if c + 1 < cols && canSwap((r, c), (r, c + 1)) { return true }
                if r + 1 < rows && canSwap((r, c), (r + 1, c)) { return true }
            }
        }
        return false
    }

    func shuffle() {
        var tilesAndPositions: [(Tile, (row: Int, col: Int))] = []
        for r in 0..<rows {
            for c in 0..<cols {
                if let t = grid[r][c], !t.isHole, t.obstacle != .stone {
                    tilesAndPositions.append((t, (r, c)))
                }
            }
        }

        for _ in 0..<20 {
            let shuffledTiles = tilesAndPositions.map { $0.0 }.shuffled()
            for (i, (_, pos)) in tilesAndPositions.enumerated() {
                grid[pos.row][pos.col] = shuffledTiles[i]
                shuffledTiles[i].row = pos.row
                shuffledTiles[i].col = pos.col
            }
            if hasPossibleMove() { return }
        }
    }

    // MARK: - Jelly Count

    var jellyCount: Int {
        var count = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if let t = grid[r][c], t.obstacle == .jelly1 || t.obstacle == .jelly2 {
                    count += 1
                }
            }
        }
        return count
    }

    var iceCount: Int {
        var count = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if let t = grid[r][c], t.obstacle == .ice { count += 1 }
            }
        }
        return count
    }

    func count(of color: GemColor) -> Int {
        var n = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if let t = grid[r][c], !t.isHole, t.gemColor == color { n += 1 }
            }
        }
        return n
    }

    // MARK: - Debug

    func printBoard() {
        for r in 0..<rows {
            print((0..<cols).map { grid[r][$0]?.description ?? "." }.joined(separator: " "))
        }
    }
}
