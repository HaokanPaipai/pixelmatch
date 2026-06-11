import SpriteKit

final class BoardNode: SKNode {

    static let visualPadding: CGFloat = 8

    private var board: Board
    var tileNodes: [[TileNode?]] = []
    private var cellBg: SKNode!
    private var tileLayer: SKCropNode!
    private var isAnimating = false
    private let world: World?

    var onTileTapped: ((Int, Int) -> Void)?
    var onSwapAttempt: ((Int, Int, Int, Int) -> Void)?

    let rows: Int
    let cols: Int
    let tileStep = GameConstants.tileStep
    let tileSize = GameConstants.tileSize

    init(board: Board, world: World? = nil) {
        self.board = board
        self.world = world
        self.rows = board.rows
        self.cols = board.cols
        super.init()
        setupCellBackgrounds()
        setupTileLayer()
        setupTileNodes()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupCellBackgrounds() {
        cellBg = SKNode()
        addChild(cellBg)
        addBoardBackplate()

        for r in 0..<rows {
            for c in 0..<cols {
                let isHole = board.grid[r][c]?.isHole ?? false
                let tex = PixelArt.shared.cellTexture(size: tileSize,
                                                      isHole: isHole,
                                                      world: world,
                                                      variant: (r + c) % 2)
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

    private func addBoardBackplate() {
        let size = CGSize(width: boardSize.width + 10, height: boardSize.height + 10)
        let plate = SKShapeNode(rectOf: size, cornerRadius: 12)
        let base = world?.bgColor ?? UIColor(hex: "#0A1628")
        let theme = world?.themeColor ?? UIColor(hex: "#2255AA")
        plate.fillColor = base.darker(by: 0.12).withAlphaComponent(0.32)
        plate.strokeColor = theme.withAlphaComponent(0.22)
        plate.lineWidth = 1.5
        plate.zPosition = -0.3
        cellBg.addChild(plate)
    }

    private func setupTileLayer() {
        tileLayer = SKCropNode()
        tileLayer.zPosition = 1

        let mask = SKSpriteNode(color: .white, size: layoutSize)
        mask.position = .zero
        tileLayer.maskNode = mask

        addChild(tileLayer)
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
                tileLayer.addChild(node)
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

    /// matchIntensity：0=普通 3 消，1=4 消/生成特效，2=5 消/彩虹弹（粒子与音高随强度递进）
    /// cascadeLevel：连锁层级，驱动音高阶梯（连锁越深音调越高）
    func animateRemovals(_ positions: [(row: Int, col: Int)],
                         specialPos: (row: Int, col: Int)? = nil,
                         newSpecial: TileSpecial = .none,
                         specialCreations: [(pos: (row: Int, col: Int), special: TileSpecial)] = [],
                         matchIntensity: Int = 0,
                         cascadeLevel: Int = 0,
                         completion: @escaping () -> Void) {
        var maxDelay = 0.0
        var particleScene: SKScene? { scene }
        var creations = specialCreations.filter { $0.special != .none }
        if let specialPos = specialPos, newSpecial != .none {
            creations.insert((specialPos, newSpecial), at: 0)
        }

        let particleCount: Int
        switch matchIntensity {
        case 2: particleCount = 16
        case 1: particleCount = 10
        default: particleCount = 6
        }

        for pos in positions {
            guard let node = tileNodes[pos.row][pos.col] else { continue }

            if let creation = creations.first(where: { $0.pos.row == pos.row && $0.pos.col == pos.col }) {
                // Transform into special tile
                node.tile.special = creation.special
                node.refresh()
                node.pulse(scale: 1.4)
                AudioManager.shared.play(.specialCreated)
                continue
            }

            // Burst particles
            if let s = scene {
                node.burstParticles(in: s, count: particleCount, intensity: matchIntensity)
            }

            node.animateMatch { }
            maxDelay = max(maxDelay, 0.2)
        }

        // 音高随连锁与强度递进
        AudioManager.shared.play(.match, pitchStep: cascadeLevel + matchIntensity)

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
        let reducedMotion = VisualComfort.isReducedMotionEnabled
        let boardW = boardSize.width
        let beam = SKShapeNode(rectOf: CGSize(width: boardW, height: tileSize * 0.34), cornerRadius: tileSize * 0.17)
        beam.fillColor = UIColor.white.withAlphaComponent(VisualComfort.flashAlpha)
        beam.strokeColor = UIColor(hex: "#BEEBFF").withAlphaComponent(reducedMotion ? 0.26 : 0.42)
        beam.lineWidth = 1.5
        beam.position = tilePos(row: row, col: cols / 2)
        beam.zPosition = 10
        tileLayer.addChild(beam)
        beam.run(.sequence([
            .scaleX(to: reducedMotion ? 1.0 : 1.02, y: reducedMotion ? 0.96 : 0.82, duration: reducedMotion ? 0.04 : 0.06),
            .fadeOut(withDuration: reducedMotion ? 0.14 : 0.22),
            .removeFromParent()
        ]))
    }

    private func flashCol(_ col: Int) {
        let reducedMotion = VisualComfort.isReducedMotionEnabled
        let boardH = boardSize.height
        let beam = SKShapeNode(rectOf: CGSize(width: tileSize * 0.34, height: boardH), cornerRadius: tileSize * 0.17)
        beam.fillColor = UIColor.white.withAlphaComponent(VisualComfort.flashAlpha)
        beam.strokeColor = UIColor(hex: "#BEEBFF").withAlphaComponent(reducedMotion ? 0.26 : 0.42)
        beam.lineWidth = 1.5
        beam.position = tilePos(row: rows / 2, col: col)
        beam.zPosition = 10
        tileLayer.addChild(beam)
        beam.run(.sequence([
            .scaleX(to: reducedMotion ? 0.96 : 0.82, y: reducedMotion ? 1.0 : 1.02, duration: reducedMotion ? 0.04 : 0.06),
            .fadeOut(withDuration: reducedMotion ? 0.14 : 0.22),
            .removeFromParent()
        ]))
    }

    private func flashExplosion(at pos: (row: Int, col: Int)) {
        let reducedMotion = VisualComfort.isReducedMotionEnabled
        let ring = SKShapeNode(circleOfRadius: tileSize * (reducedMotion ? 1.05 : 1.35))
        ring.strokeColor = UIColor.white.withAlphaComponent(reducedMotion ? 0.30 : 0.54)
        ring.lineWidth = reducedMotion ? 2 : 3
        ring.fillColor = UIColor(hex: "#BEEBFF").withAlphaComponent(reducedMotion ? 0.04 : 0.08)
        ring.position = tilePos(row: pos.row, col: pos.col)
        ring.zPosition = 10
        ring.setScale(reducedMotion ? 0.74 : 0.1)
        tileLayer.addChild(ring)
        ring.run(.sequence([
            .scale(to: reducedMotion ? 1.18 : 2.15, duration: reducedMotion ? 0.14 : 0.28),
            .fadeOut(withDuration: reducedMotion ? 0.10 : 0.12),
            .removeFromParent()
        ]))
    }

    private func flashColorBomb(at pos: (row: Int, col: Int)) {
        let reducedMotion = VisualComfort.isReducedMotionEnabled
        let ringCount = reducedMotion ? 3 : 6
        for i in 0..<ringCount {
            let colorIndex = reducedMotion ? i * 2 : i
            let ring = SKShapeNode(circleOfRadius: tileSize * CGFloat(i + 1) * (reducedMotion ? 0.64 : 0.78))
            ring.strokeColor = GemColor(rawValue: colorIndex)!.primary.withAlphaComponent(reducedMotion ? 0.30 : 0.42)
            ring.lineWidth = reducedMotion ? 1.5 : 2
            ring.fillColor = .clear
            ring.position = tilePos(row: pos.row, col: pos.col)
            ring.zPosition = 10
            ring.setScale(reducedMotion ? 0.55 : 0.1)
            tileLayer.addChild(ring)
            ring.run(.sequence([
                .wait(forDuration: Double(i) * (reducedMotion ? 0.025 : 0.04)),
                .scale(to: reducedMotion ? 1.55 : 2.45, duration: reducedMotion ? 0.20 : 0.36),
                .fadeOut(withDuration: reducedMotion ? 0.12 : 0.16),
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
                let action: SKAction = VisualComfort.isReducedMotionEnabled
                    ? .move(to: toPos, duration: duration * 0.72)
                    : .sequence([
                        .scale(to: 0.72, duration: 0.06),
                        .group([
                            .move(to: toPos, duration: duration),
                            .rotate(byAngle: CGFloat.pi * 2, duration: duration)
                        ]),
                        .scale(to: 1.0, duration: 0.08)
                    ])
                node.run(action) {
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
            tileLayer.addChild(node)
            tileNodes[tile.row][tile.col] = node

            let reducedMotion = VisualComfort.isReducedMotionEnabled
            let delay = Double(-info.spawnRowOffset - 1) * (reducedMotion ? 0.02 : 0.04)
            maxDelay = max(maxDelay, delay + (reducedMotion ? 0.22 : 0.35))

            node.run(.wait(forDuration: delay)) {
                node.position = startPos
                let fallDist = abs(startPos.y - destPos.y)
                let fallDur = min(0.35, max(0.12, fallDist / 500))
                node.run(reducedMotion
                    ? .moveTo(y: destPos.y, duration: fallDur * 0.72)
                    : .sequence([
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
                tileLayer.addChild(node)
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
                    tileLayer.addChild(node)
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
        let reducedMotion = VisualComfort.isReducedMotionEnabled
        ring.strokeColor = UIColor(hex: "#FFCC00").withAlphaComponent(reducedMotion ? 0.45 : 0.8)
        ring.fillColor = .clear
        ring.lineWidth = reducedMotion ? 1.5 : 2
        ring.zPosition = 8
        if reducedMotion {
            ring.alpha = 0.62
        } else {
            ring.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.3, duration: 0.4),
                .fadeAlpha(to: 0.9, duration: 0.4)
            ])))
        }
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

    var layoutSize: CGSize {
        CGSize(width: boardSize.width + Self.visualPadding * 2,
               height: boardSize.height + Self.visualPadding * 2)
    }
}
