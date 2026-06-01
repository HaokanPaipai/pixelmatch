import SpriteKit

final class BoardNode: SKNode {

    private var board: Board
    var tileNodes: [[TileNode?]] = []
    private var cellBg: SKNode!
    private var isAnimating = false

    var onTileTapped: ((Int, Int) -> Void)?
    var onSwapAttempt: ((Int, Int, Int, Int) -> Void)?

    let rows: Int
    let cols: Int
    let tileStep = GameConstants.tileStep
    let tileSize = GameConstants.tileSize

    init(board: Board) {
        self.board = board
        self.rows = board.rows
        self.cols = board.cols
        super.init()
        setupCellBackgrounds()
        setupTileNodes()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupCellBackgrounds() {
        cellBg = SKNode()
        addChild(cellBg)

        for r in 0..<rows {
            for c in 0..<cols {
                let isHole = board.grid[r][c]?.isHole ?? false
                let tex = PixelArt.shared.cellTexture(size: tileSize, isHole: isHole)
                let cell = SKSpriteNode(texture: tex, size: CGSize(width: tileSize, height: tileSize))
                cell.position = tilePos(row: r, col: c)
                cell.zPosition = 0
                if isHole { cell.alpha = 0 }
                cellBg.addChild(cell)

                if !isHole {
                    addPortalMarkerIfNeeded(row: r, col: c)
                }
            }
        }
    }

    private func addPortalMarkerIfNeeded(row: Int, col: Int) {
        let pos = (row: row, col: col)
        let isEntrance = board.isPortalEntrance(pos)
        let isExit = board.isPortalExit(pos)
        guard isEntrance || isExit else { return }

        let marker = SKShapeNode(circleOfRadius: tileSize * (isEntrance ? 0.39 : 0.31))
        marker.position = tilePos(row: row, col: col)
        marker.fillColor = (isEntrance ? UIColor(hex: "#AF52DE") : UIColor(hex: "#00C7BE")).withAlphaComponent(0.18)
        marker.strokeColor = (isEntrance ? UIColor(hex: "#DDA0FF") : UIColor(hex: "#66FFF0")).withAlphaComponent(0.85)
        marker.lineWidth = 3
        marker.zPosition = 0.4
        cellBg.addChild(marker)

        let inner = SKShapeNode(circleOfRadius: tileSize * 0.16)
        inner.fillColor = (isEntrance ? UIColor(hex: "#DDA0FF") : UIColor(hex: "#66FFF0")).withAlphaComponent(0.45)
        inner.strokeColor = .clear
        inner.zPosition = 0.5
        marker.addChild(inner)
    }

    private func setupTileNodes() {
        tileNodes = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                guard let tile = board.grid[r][c], !tile.isHole else { continue }
                let node = TileNode(tile: tile)
                node.position = tilePos(row: r, col: c)
                node.zPosition = 1
                addChild(node)
                tileNodes[r][c] = node
            }
        }
    }

    // MARK: - Position Helpers

    func tilePos(row: Int, col: Int) -> CGPoint {
        let boardW = CGFloat(cols) * tileStep - GameConstants.tileGap
        let boardH = CGFloat(rows) * tileStep - GameConstants.tileGap
        let x = CGFloat(col) * tileStep - boardW / 2 + tileSize / 2
        let y = -(CGFloat(row) * tileStep - boardH / 2 + tileSize / 2)
        return CGPoint(x: x, y: y)
    }

    func spawnPos(column: Int, rowOffset: Int) -> CGPoint {
        let base = tilePos(row: 0, col: column)
        let extraY = CGFloat(-rowOffset) * tileStep
        return CGPoint(x: base.x, y: base.y + extraY)
    }

    func rowCol(at point: CGPoint) -> (row: Int, col: Int)? {
        let boardW = CGFloat(cols) * tileStep - GameConstants.tileGap
        let boardH = CGFloat(rows) * tileStep - GameConstants.tileGap
        let localX = point.x + boardW / 2 - tileSize / 2
        // tilePos 的 y 带外层负号：y = -(row*tileStep - boardH/2 + tileSize/2)，
        // 反算时 tileSize/2 必须随之变号，否则整盘行命中会下移约一行
        // （按住某格却命中下一行），即“拖到的不是手指按住的那个”。
        let localY = -(point.y - boardH / 2 + tileSize / 2)

        // localX/localY 此时分别等于 col*tileStep / row*tileStep；
        // 命中检测取“离触点最近的中心”，即四舍五入（Int() 向下取整会把
        // 左半/上半判到相邻格）。
        let col = Int((localX / tileStep).rounded())
        let row = Int((localY / tileStep).rounded())

        guard row >= 0 && row < rows && col >= 0 && col < cols else { return nil }
        guard let t = board.grid[row][col], !t.isHole else { return nil }
        return (row, col)
    }

    // MARK: - Swap Animation

    func animateSwap(from a: (row: Int, col: Int), to b: (row: Int, col: Int),
                     completion: @escaping () -> Void) {
        let nodeA = tileNodes[a.row][a.col]
        let nodeB = tileNodes[b.row][b.col]
        let posA = tilePos(row: a.row, col: a.col)
        let posB = tilePos(row: b.row, col: b.col)

        let dur = 0.18
        nodeA?.run(.move(to: posB, duration: dur))
        nodeB?.run(.move(to: posA, duration: dur)) {
            // Update grid references
            let tmp = self.tileNodes[a.row][a.col]
            self.tileNodes[a.row][a.col] = self.tileNodes[b.row][b.col]
            self.tileNodes[b.row][b.col] = tmp
            completion()
        }

        AudioManager.shared.play(.swap)
    }

    func animateInvalidSwap(from a: (row: Int, col: Int), to b: (row: Int, col: Int),
                             completion: @escaping () -> Void) {
        let nodeA = tileNodes[a.row][a.col]
        let nodeB = tileNodes[b.row][b.col]
        let posA = tilePos(row: a.row, col: a.col)
        let posB = tilePos(row: b.row, col: b.col)
        let dur = 0.12

        nodeA?.run(.sequence([
            .move(to: CGPoint(x: (posA.x + posB.x)/2, y: (posA.y + posB.y)/2), duration: dur),
            .move(to: posA, duration: dur)
        ]))
        nodeB?.run(.sequence([
            .move(to: CGPoint(x: (posA.x + posB.x)/2, y: (posA.y + posB.y)/2), duration: dur),
            .move(to: posB, duration: dur)
        ])) { completion() }

        AudioManager.shared.play(.invalidSwap)
    }

    // MARK: - Remove Animation

    func animateRemovals(_ positions: [(row: Int, col: Int)],
                         specialPos: (row: Int, col: Int)? = nil,
                         newSpecial: TileSpecial = .none,
                         completion: @escaping () -> Void) {
        var maxDelay = 0.0
        var particleScene: SKScene? { scene }

        for pos in positions {
            guard let node = tileNodes[pos.row][pos.col] else { continue }

            if let sp = specialPos, sp.row == pos.row && sp.col == pos.col, newSpecial != .none {
                // Transform into special tile
                node.tile.special = newSpecial
                node.refresh()
                node.pulse(scale: 1.4)
                AudioManager.shared.play(.specialCreated)
                continue
            }

            // Burst particles
            if let s = scene {
                node.burstParticles(in: s, count: 6)
            }

            node.animateMatch { }
            maxDelay = max(maxDelay, 0.2)
        }

        AudioManager.shared.play(.match)

        run(.wait(forDuration: maxDelay + 0.05)) { completion() }
    }

    func animateSpecialActivation(at pos: (row: Int, col: Int),
                                   affectedPositions: [(row: Int, col: Int)],
                                   special: TileSpecial,
                                   completion: @escaping () -> Void) {
        let node = tileNodes[pos.row][pos.col]
        node?.animateSpecialActivate()

        // Flash beam/sweep
        switch special {
        case .stripedH: flashRow(pos.row)
        case .stripedV: flashCol(pos.col)
        case .wrapped:  flashExplosion(at: pos)
        case .colorBomb: flashColorBomb(at: pos)
        default: break
        }

        AudioManager.shared.play(special == .colorBomb ? .colorBomb : .specialCreated)

        // Remove affected
        let delay = special == .colorBomb ? 0.15 : 0.1
        run(.wait(forDuration: delay)) { [weak self] in
            guard let self = self else { return }
            for p in affectedPositions {
                self.tileNodes[p.row][p.col]?.animateMatch { }
            }
            self.run(.wait(forDuration: 0.2)) { completion() }
        }
    }

    private func flashRow(_ row: Int) {
        let boardW = CGFloat(cols) * tileStep
        let beam = SKSpriteNode(color: UIColor.white.withAlphaComponent(0.7),
                                size: CGSize(width: boardW, height: tileSize * 0.6))
        beam.position = tilePos(row: row, col: cols / 2)
        beam.zPosition = 10
        addChild(beam)
        beam.run(.sequence([
            .scaleX(to: 1.1, y: 1, duration: 0.05),
            .fadeOut(withDuration: 0.25),
            .removeFromParent()
        ]))
    }

    private func flashCol(_ col: Int) {
        let boardH = CGFloat(rows) * tileStep
        let beam = SKSpriteNode(color: UIColor.white.withAlphaComponent(0.7),
                                size: CGSize(width: tileSize * 0.6, height: boardH))
        beam.position = tilePos(row: rows / 2, col: col)
        beam.zPosition = 10
        addChild(beam)
        beam.run(.sequence([
            .scaleX(to: 1, y: 1.1, duration: 0.05),
            .fadeOut(withDuration: 0.25),
            .removeFromParent()
        ]))
    }

    private func flashExplosion(at pos: (row: Int, col: Int)) {
        let ring = SKShapeNode(circleOfRadius: tileSize * 1.5)
        ring.strokeColor = UIColor.white.withAlphaComponent(0.8)
        ring.lineWidth = 4
        ring.fillColor = UIColor.white.withAlphaComponent(0.1)
        ring.position = tilePos(row: pos.row, col: pos.col)
        ring.zPosition = 10
        ring.setScale(0.1)
        addChild(ring)
        ring.run(.sequence([
            .scale(to: 2.5, duration: 0.3),
            .fadeOut(withDuration: 0.1),
            .removeFromParent()
        ]))
    }

    private func flashColorBomb(at pos: (row: Int, col: Int)) {
        for i in 0..<6 {
            let ring = SKShapeNode(circleOfRadius: tileSize * CGFloat(i + 1))
            ring.strokeColor = GemColor(rawValue: i)!.primary.withAlphaComponent(0.6)
            ring.lineWidth = 3
            ring.fillColor = .clear
            ring.position = tilePos(row: pos.row, col: pos.col)
            ring.zPosition = 10
            ring.setScale(0.1)
            addChild(ring)
            ring.run(.sequence([
                .wait(forDuration: Double(i) * 0.04),
                .scale(to: 3, duration: 0.4),
                .fadeOut(withDuration: 0.15),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Fall Animation

    func animateFalls(_ falls: [TileFall], completion: @escaping () -> Void) {
        guard !falls.isEmpty else { completion(); return }

        var completedCount = 0
        let moves = falls.compactMap { fall -> (fall: TileFall, node: TileNode)? in
            guard let node = tileNodes[fall.fromRow][fall.fromCol] else { return nil }
            return (fall, node)
        }
        let total = moves.count
        guard total > 0 else { completion(); return }

        for move in moves {
            tileNodes[move.fall.fromRow][move.fall.fromCol] = nil
        }

        for move in moves {
            let fall = move.fall
            let node = move.node
            let fromPos = tilePos(row: fall.fromRow, col: fall.fromCol)
            let toPos = tilePos(row: fall.toRow, col: fall.toCol)

            // 先用快照取节点，再统一更新目标格，避免同一列连续下落时来源格被覆盖。
            node.tile = fall.tile
            tileNodes[fall.toRow][fall.toCol] = node

            if fall.fromCol == fall.toCol {
                node.animateFall(fromY: fromPos.y, toY: toPos.y, delay: 0) {
                    completedCount += 1
                    if completedCount == total { completion() }
                }
            } else {
                node.position = fromPos
                let distance = hypot(fromPos.x - toPos.x, fromPos.y - toPos.y)
                let duration = min(0.42, max(0.16, distance / 560))
                node.run(.sequence([
                    .scale(to: 0.72, duration: 0.06),
                    .group([
                        .move(to: toPos, duration: duration),
                        .rotate(byAngle: CGFloat.pi * 2, duration: duration)
                    ]),
                    .scale(to: 1.0, duration: 0.08)
                ])) {
                    completedCount += 1
                    if completedCount == total { completion() }
                }
            }
        }
    }

    func animateNewTiles(_ newTiles: [NewTileInfo], completion: @escaping () -> Void) {
        guard !newTiles.isEmpty else { completion(); return }

        var maxDelay = 0.0

        for info in newTiles {
            let tile = info.tile
            let destPos = tilePos(row: tile.row, col: tile.col)
            let startPos = spawnPos(column: info.column, rowOffset: info.spawnRowOffset)

            // 理论上补充位置应为空；这里兜底移除旧节点，避免残影叠到新棋子上。
            tileNodes[tile.row][tile.col]?.removeFromParent()
            let node = TileNode(tile: tile)
            node.position = startPos
            node.zPosition = 1
            addChild(node)
            tileNodes[tile.row][tile.col] = node

            let delay = Double(-info.spawnRowOffset - 1) * 0.04
            maxDelay = max(maxDelay, delay + 0.35)

            node.run(.wait(forDuration: delay)) {
                node.position = startPos
                let fallDist = abs(startPos.y - destPos.y)
                let fallDur = min(0.35, max(0.12, fallDist / 500))
                node.run(.sequence([
                    .moveTo(y: destPos.y - 4, duration: fallDur * 0.85),
                    .moveTo(y: destPos.y + 2, duration: 0.05),
                    .moveTo(y: destPos.y, duration: 0.04)
                ]))
            }
        }

        AudioManager.shared.play(.cascade)
        run(.wait(forDuration: maxDelay)) { completion() }
    }

    // MARK: - Shuffle Animation

    func animateShuffle(completion: @escaping () -> Void) {
        let dur = 0.4
        for r in 0..<rows {
            for c in 0..<cols {
                guard let node = tileNodes[r][c] else { continue }
                let randomOffset = CGPoint(x: CGFloat.random(in: -20...20),
                                          y: CGFloat.random(in: -20...20))
                let target = tilePos(row: r, col: c)
                node.run(.sequence([
                    .moveBy(x: randomOffset.x, y: randomOffset.y, duration: dur * 0.4),
                    .move(to: target, duration: dur * 0.6)
                ]))
            }
        }
        AudioManager.shared.play(.shuffle)
        run(.wait(forDuration: dur)) { completion() }
    }

    func rebuildAfterShuffle() {
        // Remove all tile nodes
        for r in 0..<rows {
            for c in 0..<cols {
                tileNodes[r][c]?.removeFromParent()
                tileNodes[r][c] = nil
            }
        }
        // Re-create from updated board
        for r in 0..<rows {
            for c in 0..<cols {
                guard let tile = board.grid[r][c], !tile.isHole else { continue }
                let node = TileNode(tile: tile)
                node.position = tilePos(row: r, col: c)
                node.zPosition = 1
                addChild(node)
                tileNodes[r][c] = node
            }
        }
    }

    func syncWithBoard() {
        // 棋盘数据在消除后才知道哪些格子真的为空，哪些只是障碍层变化。
        // 这里以 Board 为准修正视觉节点，避免旧节点或障碍贴图残留在底行。
        for r in 0..<rows {
            for c in 0..<cols {
                guard let tile = board.grid[r][c], !tile.isHole else {
                    tileNodes[r][c]?.removeFromParent()
                    tileNodes[r][c] = nil
                    continue
                }

                if let node = tileNodes[r][c] {
                    node.tile = tile
                    node.position = tilePos(row: r, col: c)
                    node.zPosition = 1
                    node.refresh()
                } else {
                    let node = TileNode(tile: tile)
                    node.position = tilePos(row: r, col: c)
                    node.zPosition = 1
                    addChild(node)
                    tileNodes[r][c] = node
                }
            }
        }
    }

    // MARK: - Selection Highlight

    func selectTile(at pos: (row: Int, col: Int)) {
        tileNodes[pos.row][pos.col]?.setSelected(true)
    }

    func deselectAll() {
        for row in tileNodes { row.forEach { $0?.setSelected(false) } }
    }

    // MARK: - Hint

    func showHint(a: (row: Int, col: Int), b: (row: Int, col: Int)) {
        tileNodes[a.row][a.col]?.animateHint()
        tileNodes[b.row][b.col]?.animateHint()

        // Glow ring around hint tiles
        let ringA = makeHintRing()
        ringA.position = tilePos(row: a.row, col: a.col)
        ringA.name = "hintRing"
        addChild(ringA)

        let ringB = makeHintRing()
        ringB.position = tilePos(row: b.row, col: b.col)
        ringB.name = "hintRing"
        addChild(ringB)
    }

    private func makeHintRing() -> SKShapeNode {
        let ring = SKShapeNode(rectOf: CGSize(width: tileSize + 6, height: tileSize + 6), cornerRadius: 10)
        ring.strokeColor = UIColor(hex: "#FFCC00").withAlphaComponent(0.8)
        ring.fillColor = .clear
        ring.lineWidth = 2
        ring.zPosition = 8
        ring.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.3, duration: 0.4),
            .fadeAlpha(to: 0.9, duration: 0.4)
        ])))
        return ring
    }

    func hideHints() {
        for row in tileNodes { row.forEach { $0?.stopHint() } }
        enumerateChildNodes(withName: "hintRing") { node, _ in node.removeFromParent() }
    }

    // MARK: - Jelly Overlay Refresh

    func refreshObstacles() {
        for r in 0..<rows {
            for c in 0..<cols {
                tileNodes[r][c]?.refresh()
            }
        }
    }

    // MARK: - Board Size Helper

    var boardSize: CGSize {
        CGSize(width: CGFloat(cols) * tileStep - GameConstants.tileGap,
               height: CGFloat(rows) * tileStep - GameConstants.tileGap)
    }
}
