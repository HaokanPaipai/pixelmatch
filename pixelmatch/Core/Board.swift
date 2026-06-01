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

struct SpecialComboEffect {
    var origin: (row: Int, col: Int)
    var consumedPositions: [(row: Int, col: Int)]
    var positions: [(row: Int, col: Int)]
    var visualSpecial: TileSpecial
    var scoreMultiplier: Int
}

// MARK: - Board

final class Board {
    let rows: Int
    let cols: Int
    var grid: [[Tile?]]
    var availableColors: [GemColor]
    var portalLinks: [PortalLink] = []

    init(rows: Int, cols: Int, availableColors: [GemColor]) {
        self.rows = rows
        self.cols = cols
        self.availableColors = availableColors
        self.grid = Array(repeating: Array(repeating: nil, count: cols), count: rows)
    }

    // MARK: - Setup

    func setup(from level: Level) {
        portalLinks = level.portalLinks

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
        if ta.special != .none && tb.special != .none { return true }

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
                // 条纹和包裹棋子仍保留颜色，可以参与后续三消并触发效果；
                // 彩虹炸弹没有普通颜色消除语义，只通过交换触发。
                guard let anchor = grid[r][c], anchor.isMatchable, anchor.special != .colorBomb else {
                    c += 1; continue
                }
                var len = 1
                while c + len < cols,
                      let next = grid[r][c + len],
                      next.isMatchable, next.special != .colorBomb,
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
                // 竖向检测与横向保持一致：普通特殊棋子可被匹配触发，
                // 彩虹炸弹仍由交换逻辑单独处理。
                guard let anchor = grid[r][c], anchor.isMatchable, anchor.special != .colorBomb else {
                    r += 1; continue
                }
                var len = 1
                while r + len < rows,
                      let next = grid[r + len][c],
                      next.isMatchable, next.special != .colorBomb,
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
        var cageCleared: [(row: Int, col: Int)]
        var chocolateCleared: [(row: Int, col: Int)]
        var chestDamaged: [(row: Int, col: Int)]
        var chestOpened: [(row: Int, col: Int)]
        var keysCollected: [(row: Int, col: Int)]
        var locksOpened: [(row: Int, col: Int)]
        var score: Int
    }

    func removeTiles(at positions: [(row: Int, col: Int)],
                     specialPos: (row: Int, col: Int)? = nil,
                     newSpecial: TileSpecial = .none,
                     cascadeLevel: Int = 0) -> RemoveResult {
        var removed: [(row: Int, col: Int)] = []
        var jellyReduced: [(row: Int, col: Int)] = []
        var iceCleared: [(row: Int, col: Int)] = []
        var cageCleared: [(row: Int, col: Int)] = []
        var chocolateCleared: [(row: Int, col: Int)] = []
        var chestDamaged: [(row: Int, col: Int)] = []
        var chestOpened: [(row: Int, col: Int)] = []
        var keysCollected: [(row: Int, col: Int)] = []
        var locksOpened: [(row: Int, col: Int)] = []
        var score = 0
        let multiplier = 1 + cascadeLevel

        for pos in uniquePositions(positions) {
            guard valid(pos), let tile = grid[pos.row][pos.col], !tile.isHole else { continue }

            if let sp = specialPos,
               sp.row == pos.row && sp.col == pos.col,
               newSpecial != .none,
               tile.obstacle != .cage,
               tile.obstacle != .chest1,
               tile.obstacle != .chest2,
               tile.obstacle != .key,
               tile.obstacle != .lock {
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
            case .cage:
                tile.obstacle = .none
                cageCleared.append(pos)
                score += GameConstants.scorePerTile * multiplier
                // The cage absorbs this hit; the freed tile remains on the board.
            case .chest2:
                tile.obstacle = .chest1
                chestDamaged.append(pos)
                score += GameConstants.scorePerTile * multiplier
            case .chest1:
                tile.obstacle = .none
                chestDamaged.append(pos)
                chestOpened.append(pos)
                score += GameConstants.scorePerTile * 3 * multiplier
            case .key:
                tile.obstacle = .none
                keysCollected.append(pos)
                grid[pos.row][pos.col] = nil
                removed.append(pos)
                score += GameConstants.scorePerTile * 2 * multiplier
            case .lock:
                continue
            case .stone:
                continue // immovable
            default:
                if tile.obstacle == .chocolate {
                    chocolateCleared.append(pos)
                }
                grid[pos.row][pos.col] = nil
                removed.append(pos)
                score += GameConstants.scorePerTile * multiplier
            }
        }

        // Damage blockers adjacent to removed tiles. A blocker can only take one adjacent hit per cascade step.
        var adjacentChests: [(row: Int, col: Int)] = []
        for pos in removed {
            for (dr, dc) in [(-1,0),(1,0),(0,-1),(0,1)] {
                let nr = pos.row + dr, nc = pos.col + dc
                guard valid((nr, nc)), let t = grid[nr][nc] else { continue }
                if t.obstacle == .chocolate {
                    t.obstacle = .none
                    chocolateCleared.append((nr, nc))
                } else if t.obstacle == .chest1 || t.obstacle == .chest2 {
                    adjacentChests.append((nr, nc))
                }
            }
        }
        for pos in uniquePositions(adjacentChests) {
            guard let tile = grid[pos.row][pos.col] else { continue }
            if tile.obstacle == .chest2 {
                tile.obstacle = .chest1
                chestDamaged.append(pos)
                score += GameConstants.scorePerTile * multiplier
            } else if tile.obstacle == .chest1 {
                tile.obstacle = .none
                chestDamaged.append(pos)
                chestOpened.append(pos)
                score += GameConstants.scorePerTile * 3 * multiplier
            }
        }
        if !keysCollected.isEmpty {
            locksOpened.append(contentsOf: unlockNearestLocks(for: keysCollected))
            score += locksOpened.count * GameConstants.scorePerSpecial
        }

        let uniqueChocolate = uniquePositions(chocolateCleared)
        return RemoveResult(removedPositions: uniquePositions(removed + uniqueChocolate),
                            jellyReduced: uniquePositions(jellyReduced),
                            iceCleared: uniquePositions(iceCleared),
                            cageCleared: uniquePositions(cageCleared),
                            chocolateCleared: uniqueChocolate,
                            chestDamaged: uniquePositions(chestDamaged),
                            chestOpened: uniquePositions(chestOpened),
                            keysCollected: uniquePositions(keysCollected),
                            locksOpened: uniquePositions(locksOpened),
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

    func specialComboEffect(first: TileSpecial,
                            firstColor: GemColor,
                            at firstPos: (row: Int, col: Int),
                            second: TileSpecial,
                            secondColor: GemColor,
                            at secondPos: (row: Int, col: Int)) -> SpecialComboEffect? {
        guard first != .none, second != .none else { return nil }

        let origin = second == .colorBomb ? firstPos : secondPos
        var positions: [(row: Int, col: Int)] = []
        var visualSpecial: TileSpecial = .wrapped
        var scoreMultiplier = 3

        switch (first, second) {
        case (.colorBomb, .colorBomb):
            positions = allClearablePositions()
            visualSpecial = .colorBomb
            scoreMultiplier = 5

        case (.colorBomb, .stripedH), (.colorBomb, .stripedV):
            positions = colorBombLineComboPositions(targetColor: secondColor)
            visualSpecial = second
            scoreMultiplier = 4

        case (.stripedH, .colorBomb), (.stripedV, .colorBomb):
            positions = colorBombLineComboPositions(targetColor: firstColor)
            visualSpecial = first
            scoreMultiplier = 4

        case (.colorBomb, .wrapped):
            positions = colorBombWrappedComboPositions(targetColor: secondColor)
            visualSpecial = .colorBomb
            scoreMultiplier = 4

        case (.wrapped, .colorBomb):
            positions = colorBombWrappedComboPositions(targetColor: firstColor)
            visualSpecial = .colorBomb
            scoreMultiplier = 4

        case (.stripedH, .stripedH), (.stripedH, .stripedV), (.stripedV, .stripedH), (.stripedV, .stripedV):
            positions.append(contentsOf: rowPositions(firstPos.row))
            positions.append(contentsOf: colPositions(secondPos.col))
            visualSpecial = .stripedH
            scoreMultiplier = 3

        case (.stripedH, .wrapped), (.stripedV, .wrapped):
            positions = wideCrossPositions(center: secondPos)
            visualSpecial = first
            scoreMultiplier = 4

        case (.wrapped, .stripedH), (.wrapped, .stripedV):
            positions = wideCrossPositions(center: firstPos)
            visualSpecial = second
            scoreMultiplier = 4

        case (.wrapped, .wrapped):
            positions = areaPositions(center: firstPos, radius: 3, skipCorners: false)
            visualSpecial = .wrapped
            scoreMultiplier = 4

        default:
            return nil
        }

        positions.append(firstPos)
        positions.append(secondPos)
        return SpecialComboEffect(origin: origin,
                                  consumedPositions: [firstPos, secondPos],
                                  positions: uniquePositions(positions),
                                  visualSpecial: visualSpecial,
                                  scoreMultiplier: scoreMultiplier)
    }

    private func colorBombLineComboPositions(targetColor: GemColor) -> [(row: Int, col: Int)] {
        var result: [(row: Int, col: Int)] = []
        for pos in positions(of: targetColor) {
            let special: TileSpecial = (pos.row + pos.col).isMultiple(of: 2) ? .stripedH : .stripedV
            result.append(contentsOf: positionsForSpecial(special, at: pos))
        }
        return uniquePositions(result)
    }

    private func colorBombWrappedComboPositions(targetColor: GemColor) -> [(row: Int, col: Int)] {
        var result: [(row: Int, col: Int)] = []
        for pos in positions(of: targetColor) {
            result.append(contentsOf: positionsForSpecial(.wrapped, at: pos))
        }
        return uniquePositions(result)
    }

    private func wideCrossPositions(center: (row: Int, col: Int)) -> [(row: Int, col: Int)] {
        var result: [(row: Int, col: Int)] = []
        for dr in -1...1 {
            let row = center.row + dr
            if row >= 0 && row < rows {
                result.append(contentsOf: rowPositions(row))
            }
        }
        for dc in -1...1 {
            let col = center.col + dc
            if col >= 0 && col < cols {
                result.append(contentsOf: colPositions(col))
            }
        }
        return uniquePositions(result)
    }

    private func areaPositions(center: (row: Int, col: Int),
                               radius: Int,
                               skipCorners: Bool) -> [(row: Int, col: Int)] {
        var result: [(row: Int, col: Int)] = []
        for dr in -radius...radius {
            for dc in -radius...radius {
                if skipCorners && abs(dr) == radius && abs(dc) == radius { continue }
                let pos = (row: center.row + dr, col: center.col + dc)
                guard isClearable(pos) else { continue }
                result.append(pos)
            }
        }
        return result
    }

    private func rowPositions(_ row: Int) -> [(row: Int, col: Int)] {
        (0..<cols).compactMap { col in
            let pos = (row: row, col: col)
            return isClearable(pos) ? pos : nil
        }
    }

    private func colPositions(_ col: Int) -> [(row: Int, col: Int)] {
        (0..<rows).compactMap { row in
            let pos = (row: row, col: col)
            return isClearable(pos) ? pos : nil
        }
    }

    private func positions(of color: GemColor) -> [(row: Int, col: Int)] {
        var result: [(row: Int, col: Int)] = []
        for r in 0..<rows {
            for c in 0..<cols {
                guard let tile = grid[r][c], !tile.isHole, tile.obstacle != .stone, tile.obstacle != .lock,
                      tile.gemColor == color else { continue }
                result.append((r, c))
            }
        }
        return result
    }

    private func allClearablePositions() -> [(row: Int, col: Int)] {
        var result: [(row: Int, col: Int)] = []
        for r in 0..<rows {
            for c in 0..<cols where isClearable((r, c)) {
                result.append((r, c))
            }
        }
        return result
    }

    private func isClearable(_ pos: (row: Int, col: Int)) -> Bool {
        guard valid(pos), let tile = grid[pos.row][pos.col] else { return false }
        return !tile.isHole && tile.obstacle != .stone && tile.obstacle != .lock
    }

    private func unlockNearestLocks(for keyPositions: [(row: Int, col: Int)]) -> [(row: Int, col: Int)] {
        var locks = lockPositions()
        var opened: [(row: Int, col: Int)] = []

        for key in keyPositions where !locks.isEmpty {
            let targetIndex = locks.indices.min { lhs, rhs in
                distance(key, locks[lhs]) < distance(key, locks[rhs])
            }
            guard let index = targetIndex else { continue }
            let lock = locks.remove(at: index)
            grid[lock.row][lock.col]?.obstacle = .none
            opened.append(lock)
        }

        return opened
    }

    private func lockPositions() -> [(row: Int, col: Int)] {
        var positions: [(row: Int, col: Int)] = []
        for r in 0..<rows {
            for c in 0..<cols {
                guard let tile = grid[r][c], tile.obstacle == .lock else { continue }
                positions.append((r, c))
            }
        }
        return positions
    }

    private func distance(_ a: (row: Int, col: Int), _ b: (row: Int, col: Int)) -> Int {
        abs(a.row - b.row) + abs(a.col - b.col)
    }

    private func uniquePositions(_ positions: [(row: Int, col: Int)]) -> [(row: Int, col: Int)] {
        var seen = Set<String>()
        var result: [(row: Int, col: Int)] = []
        for pos in positions {
            let key = "\(pos.row)_\(pos.col)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(pos)
        }
        return result
    }

    // MARK: - Gravity & Refill

    func applyGravity() -> [TileFall] {
        var origins: [ObjectIdentifier: (tile: Tile, row: Int, col: Int)] = [:]

        func recordMove(_ tile: Tile, from: (row: Int, col: Int), to: (row: Int, col: Int)) {
            let key = ObjectIdentifier(tile)
            if origins[key] == nil {
                origins[key] = (tile, from.row, from.col)
            }
            tile.row = to.row
            tile.col = to.col
        }

        var changed = false
        var safety = 0
        repeat {
            changed = false
            if transferPortalTiles(recordMove: recordMove) { changed = true }
            if applyVerticalGravity(recordMove: recordMove) { changed = true }
            if transferPortalTiles(recordMove: recordMove) { changed = true }
            safety += 1
        } while changed && safety < 12

        return origins.values.compactMap { origin in
            guard origin.row != origin.tile.row || origin.col != origin.tile.col else { return nil }
            return TileFall(tile: origin.tile,
                            fromRow: origin.row,
                            fromCol: origin.col,
                            toRow: origin.tile.row,
                            toCol: origin.tile.col)
        }
    }

    private func applyVerticalGravity(recordMove: (Tile, (row: Int, col: Int), (row: Int, col: Int)) -> Void) -> Bool {
        var changed = false
        for c in 0..<cols {
            var writeRow = rows - 1
            for r in stride(from: rows - 1, through: 0, by: -1) {
                let current = (row: r, col: c)
                if isPortalEntrance(current) {
                    if let tile = grid[r][c], !tile.isHole {
                        writeRow = r - 1
                    } else {
                        writeRow = r
                    }
                    continue
                }

                // hole 和固定障碍是重力屏障，不能被上方棋子覆盖。
                if let blocker = grid[r][c], blocker.isGravityBlocker {
                    writeRow = r - 1
                    continue
                }

                if let t = grid[r][c] {
                    if r != writeRow {
                        grid[writeRow][c] = t
                        grid[r][c] = nil
                        recordMove(t, current, (row: writeRow, col: c))
                        changed = true
                    }
                    writeRow -= 1
                }
            }
        }
        return changed
    }

    private func transferPortalTiles(recordMove: (Tile, (row: Int, col: Int), (row: Int, col: Int)) -> Void) -> Bool {
        var changed = false
        for link in portalLinks {
            guard valid(link.entrance), valid(link.exit),
                  let tile = grid[link.entrance.row][link.entrance.col],
                  !tile.isHole,
                  !tile.isGravityBlocker,
                  grid[link.exit.row][link.exit.col] == nil else { continue }
            grid[link.exit.row][link.exit.col] = tile
            grid[link.entrance.row][link.entrance.col] = nil
            recordMove(tile, link.entrance, link.exit)
            changed = true
        }
        return changed
    }

    func isPortalEntrance(_ pos: (row: Int, col: Int)) -> Bool {
        portalLinks.contains { $0.entrance.row == pos.row && $0.entrance.col == pos.col }
    }

    func isPortalExit(_ pos: (row: Int, col: Int)) -> Bool {
        portalLinks.contains { $0.exit.row == pos.row && $0.exit.col == pos.col }
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

    func spreadChocolate(force: Bool = false) -> [(row: Int, col: Int)] {
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
            if let target = adjacents.randomElement(), (force || Int.random(in: 0..<3) == 0) {
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
                if let t = grid[r][c], !t.isHole, !t.isGravityBlocker {
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

    var chocolateCount: Int {
        var count = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if let t = grid[r][c], t.obstacle == .chocolate { count += 1 }
            }
        }
        return count
    }

    var cageCount: Int {
        var count = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if let t = grid[r][c], t.obstacle == .cage { count += 1 }
            }
        }
        return count
    }

    var chestCount: Int {
        var count = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if let t = grid[r][c], t.obstacle == .chest1 || t.obstacle == .chest2 { count += 1 }
            }
        }
        return count
    }

    var keyCount: Int {
        var count = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if let t = grid[r][c], t.obstacle == .key { count += 1 }
            }
        }
        return count
    }

    var lockCount: Int {
        var count = 0
        for r in 0..<rows {
            for c in 0..<cols {
                if let t = grid[r][c], t.obstacle == .lock { count += 1 }
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
