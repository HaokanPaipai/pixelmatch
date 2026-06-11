import SpriteKit
import GameplayKit
import HKAdKit

// MARK: - Game State

// 描述场景的整体交互状态，避免输入、动画、弹窗和结算流程互相打架。
enum GameState {
    case idle, selecting, animating, paused, won, failed
}

struct BoardLayoutMetrics {
    let scale: CGFloat
    let centerY: CGFloat
    let playableTop: CGFloat
    let playableBottom: CGFloat
}

enum BoardLayoutCalculator {
    static func metrics(sceneSize: CGSize,
                        safeAreaInsets: UIEdgeInsets,
                        boardSize: CGSize,
                        sidePadding: CGFloat = 14,
                        verticalPadding: CGFloat = 8) -> BoardLayoutMetrics {
        let topReservedHeight = safeAreaInsets.top + GameHUD.contentHeight + 15
        let bottomReservedHeight = safeAreaInsets.bottom + GameHUD.boosterReservedHeight
        let playableTop = sceneSize.height / 2 - topReservedHeight
        let playableBottom = -sceneSize.height / 2 + bottomReservedHeight
        let availableWidth = max(1, sceneSize.width - safeAreaInsets.left - safeAreaInsets.right - sidePadding * 2)
        let availableHeight = max(1, playableTop - playableBottom - verticalPadding * 2)
        let scale = min(1, availableWidth / boardSize.width, availableHeight / boardSize.height)

        return BoardLayoutMetrics(scale: scale,
                                  centerY: (playableTop + playableBottom) / 2,
                                  playableTop: playableTop,
                                  playableBottom: playableBottom)
    }
}

// MARK: - GameScene

// 负责一个可游玩的关卡：场景布局、棋盘交互、消除流程、HUD 回调、
// 道具、计分、胜负跳转以及轻量级反馈效果。
final class GameScene: SKScene {

    // Level
    var level: Level!
    var preGameBoosters: [BoosterType] = []
    /// 失败页"continueLevel"激励视频奖励：开局额外步数。不走 booster 库存，避免污染 booster 使用埋点。
    var bonusMovesFromAd: Int = 0

    // Core
    private var board: Board!
    private var boardNode: BoardNode!
    private var hud: GameHUD!
    private var safeAreaInsets: UIEdgeInsets = .zero

    // State
    private var state: GameState = .idle
    private var selectedPos: (row: Int, col: Int)?
    private var currentScore: Int = 0
    private var remainingMoves: Int = 0
    private var objectives: [LevelObjective] = []
    private var cascadeCount: Int = 0
    private var isHammerMode = false
    private var hintTimer: Timer?
    private var hintShown = false

    // Touch
    private var touchStartPos: CGPoint?
    private var touchStartBoardPos: (row: Int, col: Int)?

    // 震屏归位锚点（setupBoard 后固定）
    private var boardNodeHomePosition: CGPoint?

    // Collected counts (for collect objectives)
    private var collectedCounts: [GemColor: Int] = [:]
    private var collectedKeys: Int = 0
    private var initialIceCount: Int = 0
    private var initialJellyCount: Int = 0
    private var initialChocolateCount: Int = 0
    private var initialChestCount: Int = 0
    private var shouldResolveChocolateAfterCascade = false
    private var clearedChocolateThisMove = false
    private var usedBoosterThisLevel = false

    private struct HintCandidate {
        let a: (row: Int, col: Int)
        let b: (row: Int, col: Int)
        let score: Int
    }

    // Score multiplier event
    private var scoreMultiplier: Int = 1
    private var multiplierTimer: Timer?
    private var movesUntilNextEvent: Int = 10

    // MARK: - Lifecycle

    // SpriteKit 将场景挂到 view 后的入口。这里记录安全区，创建棋盘和 HUD，
    // 然后启动入场动画与提示计时器。
    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        size = view.bounds.size
        safeAreaInsets = view.safeAreaInsets
        guard level != nil else { return }

        HapticsManager.shared.prepare()
        AudioManager.shared.stopMusic()
        setupBackground()
        setupBoard()
        setupHUD()
        animateIntro()
        startHintTimer()
        AnalyticsManager.shared.track(.levelStart,
                                      properties: ["level": "\(level.id)",
                                                   "moves": "\(level.moves)",
                                                   "colors": "\(level.availableColors.count)"])
    }

    // MARK: - Setup

    // 构建静态视觉层和初始 UI：世界背景、装饰网格、居中的棋盘、
    // 适配安全区的 HUD，以及关卡入场动画。
    private func setupBackground() {
        backgroundColor = UIColor(hex: "#0A1628")

        let world = level.world ?? GameWorlds[0]
        let bgTex = PixelArt.shared.worldBgTexture(world: world, size: size)
        let bg = SKSpriteNode(texture: bgTex, size: size)
        bg.position = CGPoint(x: 0, y: 0)
        bg.zPosition = -10
        addChild(bg)

        // Pixel grid overlay
        addPixelGridDecoration()

        // World name
        let worldLbl = SKLabelNode(fontNamed: "Courier-Bold")
        worldLbl.text = L10n.upper(world.localizedName)
        worldLbl.fontSize = 12
        worldLbl.fontColor = UIColor(hex: world.themeColorHex).withAlphaComponent(0.5)
        worldLbl.verticalAlignmentMode = .center
        worldLbl.position = CGPoint(x: 0, y: size.height/2 - safeAreaInsets.top - 20)
        worldLbl.zPosition = 5
        addChild(worldLbl)
    }

    private func addPixelGridDecoration() {
        let gridSize: CGFloat = 40
        let cols = Int(size.width / gridSize) + 1
        let rows = Int(size.height / gridSize) + 1
        let gridNode = SKNode()
        gridNode.zPosition = -9

        for r in 0..<rows {
            let line = SKShapeNode(rectOf: CGSize(width: size.width, height: 1))
            line.fillColor = UIColor.white.withAlphaComponent(0.025)
            line.strokeColor = .clear
            line.position = CGPoint(x: 0, y: -size.height/2 + CGFloat(r) * gridSize)
            gridNode.addChild(line)
        }
        for c in 0..<cols {
            let line = SKShapeNode(rectOf: CGSize(width: 1, height: size.height))
            line.fillColor = UIColor.white.withAlphaComponent(0.025)
            line.strokeColor = .clear
            line.position = CGPoint(x: -size.width/2 + CGFloat(c) * gridSize, y: 0)
            gridNode.addChild(line)
        }
        addChild(gridNode)
    }

    private func setupBoard() {
        board = Board(rows: level.rows, cols: level.cols, availableColors: level.availableColors)
        board.setup(from: level)

        boardNode = BoardNode(board: board, world: level.world)

        // 9x9 starts at level 13. Small devices cannot fit the raw 430pt board,
        // so scale to the space between HUD and boosters while preserving touch math.
        let layout = BoardLayoutCalculator.metrics(sceneSize: size,
                                                   safeAreaInsets: safeAreaInsets,
                                                   boardSize: boardNode.layoutSize)
        boardNode.setScale(layout.scale)

        boardNode.position = CGPoint(x: 0, y: layout.centerY)
        boardNode.zPosition = 1
        boardNodeHomePosition = boardNode.position
        addChild(boardNode)
    }

    /// 棋盘震屏：不引入 SKCameraNode（会牵动全部绝对定位），只抖棋盘本体。
    /// 固定 action key + 每次先归位，避免连续触发时位移叠加漂移。
    private func shakeBoard(intensity: CGFloat, duration: TimeInterval) {
        guard !VisualComfort.isReducedMotionEnabled, let home = boardNodeHomePosition else { return }
        boardNode.removeAction(forKey: "shake")
        boardNode.position = home
        let steps = 5
        var actions: [SKAction] = []
        for i in 0..<steps {
            let decay = intensity * CGFloat(steps - i) / CGFloat(steps)
            let dx = CGFloat.random(in: -decay...decay)
            let dy = CGFloat.random(in: -decay...decay)
            let stepDur = duration / Double(steps + 1)
            actions.append(.move(to: CGPoint(x: home.x + dx, y: home.y + dy), duration: stepDur))
        }
        actions.append(.move(to: home, duration: duration / Double(steps + 1)))
        boardNode.run(.sequence(actions), withKey: "shake")
    }

    private func setupHUD() {
        objectives = level.objectives
        remainingMoves = level.moves
        collectedCounts = [:]
        initialIceCount = board.iceCount
        // 记录"剩余型"目标的初始量，供失败时计算完成度（近胜判定）
        initialJellyCount = board.jellyCount
        initialChocolateCount = board.chocolateCount
        initialChestCount = board.chestCount

        // Initialize "remaining" objectives with board state
        for i in 0..<objectives.count {
            switch objectives[i].kind {
            case .clearAllJelly: objectives[i].progress = board.jellyCount
            case .breakIce:     objectives[i].progress = board.iceCount
            case .eliminateChocolate: objectives[i].progress = board.chocolateCount
            case .openChests: objectives[i].progress = board.chestCount
            case .collectKeys: objectives[i].progress = collectedKeys
            default: break
            }
        }

        let hudY = size.height / 2 - safeAreaInsets.top - GameHUD.contentHeight / 2
        hud = GameHUD(level: level, sceneSize: size, safeAreaInsets: safeAreaInsets, hudWorldY: hudY)
        hud.position = CGPoint(x: 0, y: hudY)
        hud.zPosition = 10
        addChild(hud)

        hud.onPause = { [weak self] in self?.showPause() }
        hud.onBoosterTap = { [weak self] type in self?.activateBooster(type) }

        hud.updateMoves(remainingMoves)
        hud.updateScore(0)
        for index in objectives.indices {
            hud.updateObjective(index, progress: objectives[index].progress)
        }

        // Apply pre-game boosters
        for booster in preGameBoosters {
            guard PlayerData.shared.useBooster(booster) else { continue }
            usedBoosterThisLevel = true
            LiveOpsManager.shared.recordBoosterUsed()
            switch booster {
            case .extraMoves:
                remainingMoves += 5
                hud.updateMoves(remainingMoves)
            case .colorBomb:
                placeColorBombBooster()
            case .hammer:
                isHammerMode = true
            case .shuffle:
                board.shuffle()
                boardNode.rebuildAfterShuffle()
            }
        }
        if !preGameBoosters.isEmpty { hud.updateBoosterCounts() }

        // 失败页激励视频"continueLevel"奖励：开局额外步数（独立于 booster 计数）。
        if bonusMovesFromAd > 0 {
            remainingMoves += bonusMovesFromAd
            hud.updateMoves(remainingMoves)
        }
    }

    private func animateIntro() {
        // Level number banner
        let intro = SKNode()
        intro.zPosition = 100

        let bannerBg = SKShapeNode(rectOf: CGSize(width: size.width, height: 100))
        bannerBg.fillColor = UIColor(hex: "#0A1628").withAlphaComponent(0.92)
        bannerBg.strokeColor = UIColor(hex: level.world?.themeColorHex ?? "#FFCC00").withAlphaComponent(0.6)
        bannerBg.lineWidth = 2
        intro.addChild(bannerBg)

        let worldName = level.world?.localizedName ?? L10n.tr("level.fallback", fallback: "Level")
        let lbl1 = SKLabelNode(fontNamed: "Courier-Bold")
        lbl1.text = level.lesson?.title ?? L10n.upper(worldName)
        lbl1.fontSize = 14
        lbl1.fontColor = UIColor(hex: level.world?.themeColorHex ?? "#FFCC00")
        lbl1.verticalAlignmentMode = .center
        lbl1.position = CGPoint(x: 0, y: 22)
        intro.addChild(lbl1)

        let lbl2 = SKLabelNode(fontNamed: "Courier-Bold")
        lbl2.text = L10n.upper(level.displayName)
        lbl2.fontSize = 38
        lbl2.fontColor = .white
        lbl2.verticalAlignmentMode = .center
        lbl2.position = CGPoint(x: 0, y: -8)
        intro.addChild(lbl2)

        let lbl3 = SKLabelNode(fontNamed: "Courier")
        lbl3.text = level.lesson?.message ?? objectiveSummary()
        lbl3.fontSize = 13
        lbl3.fontColor = UIColor(hex: "#99BBCC")
        lbl3.verticalAlignmentMode = .center
        lbl3.numberOfLines = 2
        lbl3.preferredMaxLayoutWidth = min(size.width - 48, 360)
        lbl3.position = CGPoint(x: 0, y: -34)
        intro.addChild(lbl3)

        addChild(intro)

        intro.position = CGPoint(x: 0, y: size.height)
        intro.run(.sequence([
            .moveTo(y: 0, duration: 0.35),
            .wait(forDuration: 1.2),
            .moveTo(y: size.height, duration: 0.25),
            .removeFromParent()
        ]))

        // Cascade board tiles in column by column
        boardNode.alpha = 0
        for col in 0..<level.cols {
            let delay = 0.4 + Double(col) * 0.04
            for row in 0..<level.rows {
                if let node = boardNode.tileNodes[row][col] {
                    let targetPos = node.position
                    node.position = CGPoint(x: targetPos.x, y: targetPos.y + 200)
                    node.alpha = 0
                    let colDelay = delay + Double(row) * 0.02
                    node.run(.sequence([
                        .wait(forDuration: colDelay),
                        .group([
                            .fadeIn(withDuration: 0.15),
                            .move(to: targetPos, duration: 0.25)
                        ])
                    ]))
                }
            }
        }
        boardNode.run(.sequence([
            .wait(forDuration: 0.3),
            .run { [weak self] in self?.boardNode.alpha = 1 }
        ]))
    }

    private func objectiveSummary() -> String {
        guard let obj = level.objectives.first else { return "" }
        switch obj.kind {
        case .score(let t): return L10n.fmt("objective.score", t.scoreFormatted, fallback: "Score %@ pts")
        case .collect(let c, let n): return L10n.fmt("objective.collect", n, c.name, fallback: "Collect %d %@")
        case .clearAllJelly: return L10n.tr("objective.clear_jelly", fallback: "Clear all jelly")
        case .breakIce(let n): return L10n.fmt("objective.break_ice", n, fallback: "Break %d ice blocks")
        case .eliminateChocolate: return L10n.tr("objective.eliminate_chocolate", fallback: "Eliminate chocolate")
        case .openChests(let n): return L10n.fmt("objective.open_chests", n, fallback: "Open %d chests")
        case .collectKeys(let n): return L10n.fmt("objective.collect_keys", n, fallback: "Collect %d keys")
        }
    }

    // MARK: - Touch Handling

    // 将点击和滑动转换成棋子选择、交换或当前道具操作。
    // 所有输入都受场景状态控制，避免动画过程中修改棋盘。
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard state == .idle, let touch = touches.first else { return }
        let loc = touch.location(in: boardNode)

        if let pos = boardNode.rowCol(at: loc) {
            touchStartPos = touch.location(in: self)
            touchStartBoardPos = pos

            if isHammerMode {
                // Hammer booster: tap to remove tile
                handleHammerTap(at: pos)
                return
            }

            if let sel = selectedPos {
                // Second tap
                if sel.row == pos.row && sel.col == pos.col {
                    // Deselect
                    boardNode.deselectAll()
                    selectedPos = nil
                    AudioManager.shared.play(.tileSelect)
                    HapticsManager.shared.tap()
                } else if board.isAdjacent(sel, pos) {
                    // Try swap
                    boardNode.deselectAll()
                    selectedPos = nil
                    attemptSwap(from: sel, to: pos)
                } else {
                    // Select new tile
                    boardNode.deselectAll()
                    selectedPos = pos
                    boardNode.selectTile(at: pos)
                    AudioManager.shared.play(.tileSelect)
                    HapticsManager.shared.select()
                }
            } else {
                selectedPos = pos
                boardNode.selectTile(at: pos)
                AudioManager.shared.play(.tileSelect)
                HapticsManager.shared.select()
            }

            hideHints()
            resetHintTimer()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard state == .idle, let touch = touches.first,
              let startPos = touchStartPos, let startBoardPos = touchStartBoardPos else { return }

        let loc = touch.location(in: self)
        let dx = loc.x - startPos.x
        let dy = loc.y - startPos.y
        let dist = sqrt(dx*dx + dy*dy)

        guard dist > 15 else { return }

        // Determine swipe direction
        let swipeDest: (row: Int, col: Int)
        if abs(dx) > abs(dy) {
            swipeDest = (row: startBoardPos.row, col: startBoardPos.col + (dx > 0 ? 1 : -1))
        } else {
            swipeDest = (row: startBoardPos.row + (dy < 0 ? 1 : -1), col: startBoardPos.col)
        }

        guard board.isValidPosition(swipeDest) else { return }
        guard !(swipeDest.row == startBoardPos.row && swipeDest.col == startBoardPos.col) else { return }

        touchStartPos = nil
        touchStartBoardPos = nil
        boardNode.deselectAll()
        selectedPos = nil

        attemptSwap(from: startBoardPos, to: swipeDest)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStartPos = nil
        touchStartBoardPos = nil
    }

    // MARK: - Swap Logic

    // 校验并执行玩家交换。这里处理无效交换反馈，也会在普通消除流程前
    // 先处理彩虹炸弹相关组合。
    private func attemptSwap(from a: (row: Int, col: Int), to b: (row: Int, col: Int)) {
        guard state == .idle else { return }
        guard board.isAdjacent(a, b) else { return }
        guard let ta = board.tile(at: a), let tb = board.tile(at: b) else { return }
        guard !ta.isHole && !tb.isHole else { return }
        guard ta.isMovable && tb.isMovable else {
            HapticsManager.shared.invalidSwap()
            boardNode.animateInvalidSwap(from: a, to: b) { }
            return
        }

        if let combo = board.specialComboEffect(first: ta.special,
                                                firstColor: ta.gemColor,
                                                at: a,
                                                second: tb.special,
                                                secondColor: tb.gemColor,
                                                at: b) {
            state = .animating
            board.doSwap(a, b)
            boardNode.animateSwap(from: a, to: b) { [weak self] in
                self?.handleSpecialComboActivation(combo)
            }
            spendMove()
            return
        }

        // 彩虹炸弹需要在交换前记录目标颜色，再同步交换数据和节点。
        // 双彩虹炸弹没有目标颜色，直接清全盘。
        if ta.special == .colorBomb || tb.special == .colorBomb {
            state = .animating
            let isDoubleBomb = ta.special == .colorBomb && tb.special == .colorBomb
            let bombPosAfterSwap = ta.special == .colorBomb ? b : a
            let targetPos = ta.special == .colorBomb ? b : a
            let targetColor = isDoubleBomb ? nil : board.tile(at: targetPos)?.gemColor
            board.doSwap(a, b)
            boardNode.animateSwap(from: a, to: b) { [weak self] in
                guard let self = self else { return }
                if isDoubleBomb {
                    self.handleDoubleBomb()
                } else {
                    self.handleColorBombActivation(bombPos: bombPosAfterSwap, targetColor: targetColor)
                }
            }
            spendMove()
            return
        }

        if board.canSwap(a, b) {
            state = .animating
            board.doSwap(a, b)
            HapticsManager.shared.swap()
            boardNode.animateSwap(from: a, to: b) { [weak self] in
                guard let self = self else { return }
                self.cascadeCount = 0
                self.processMatches(preferredSpecialPositions: [b, a])
            }
            spendMove()
        } else {
            HapticsManager.shared.invalidSwap()
            boardNode.animateInvalidSwap(from: a, to: b) { }
        }
    }

    // MARK: - Match Processing Pipeline

    // 核心三消流水线：检测匹配、计分、移除棋子、应用重力、顶部补充，
    // 并持续处理连锁直到棋盘稳定。
    private func processMatches(preferredSpecialPositions: [(row: Int, col: Int)] = []) {
        let matches = board.detectMatches(preferredSpecialPositions: preferredSpecialPositions)
        guard !matches.isEmpty else {
            // No matches - check for deadlock
            state = .idle
            checkDeadlock()
            return
        }

        var allPositions: [(row: Int, col: Int)] = []
        var specialCreations: [(pos: (row: Int, col: Int), special: TileSpecial)] = []

        for match in matches {
            allPositions.append(contentsOf: match.positions)
            if match.createsSpecial != .none, let sp = match.specialPosition {
                specialCreations.append((sp, match.createsSpecial))
            }
            // Track collected colors
            if !match.positions.isEmpty {
                let color = match.gemColor
                collectedCounts[color, default: 0] += match.positions.count
            }
        }
        LiveOpsManager.shared.recordSpecialsCreated(specialCreations.count)
        let colorBombCreations = specialCreations.filter { $0.special == .colorBomb }.count
        LiveOpsManager.shared.recordColorBombsCreated(colorBombCreations)
        if !specialCreations.isEmpty {
            AnalyticsManager.shared.track(.specialCreated,
                                          properties: ["level": "\(level.id)",
                                                       "count": "\(specialCreations.count)"])
        }

        // 已存在的条纹/包裹棋子如果被本轮匹配命中，就在同一轮触发它的范围消除。
        // 新生成的特殊棋子只保留下来，不会刚生成就立刻自爆。
        let expanded = expandedPositionsByActivatingExistingSpecials(from: allPositions,
                                                                     preserving: specialCreations.map { $0.pos })
        allPositions = expanded.positions

        // Score calculation with combo multiplier + event multiplier
        let comboMult = cascadeCount > 0 ? min(cascadeCount + 1, 5) : 1
        let matchScore = (allPositions.count * GameConstants.scorePerTile * comboMult
            + specialCreations.count * GameConstants.scorePerSpecial
            + expanded.activationBonus) * scoreMultiplier
        addScore(matchScore)

        // Haptic + combo text feedback
        if cascadeCount > 0 {
            HapticsManager.shared.cascade()
            showComboText(cascadeCount + 1)
        } else {
            HapticsManager.shared.match()
        }

        // 震屏分级：5 消/彩虹弹 > 4 消/特效生成 > 大连锁；3 消不抖避免疲劳
        let maxMatchSize = matches.map { $0.positions.count }.max() ?? 0
        let madeColorBomb = specialCreations.contains { $0.special == .colorBomb }
        if madeColorBomb || maxMatchSize >= 5 {
            shakeBoard(intensity: 4, duration: 0.20)
        } else if !specialCreations.isEmpty || maxMatchSize >= 4 {
            shakeBoard(intensity: 2, duration: 0.12)
        }
        if cascadeCount >= 3 {
            shakeBoard(intensity: 6, duration: 0.28)
        }

        // 粒子/音效强度：0=3消 1=4消或出特效 2=5消/彩虹弹
        let matchIntensity = (madeColorBomb || maxMatchSize >= 5) ? 2
            : ((!specialCreations.isEmpty || maxMatchSize >= 4) ? 1 : 0)

        // Remove tiles (creating specials where needed)
        boardNode.animateRemovals(allPositions,
                                   specialCreations: specialCreations,
                                   matchIntensity: matchIntensity,
                                   cascadeLevel: cascadeCount) { [weak self] in
            guard let self = self else { return }
            let result = self.board.removeTiles(at: allPositions,
                                                specialCreations: specialCreations)
            self.recordRemoveResult(result)

            self.updateObjectiveProgress(positions: allPositions)
            self.boardNode.syncWithBoard()
            self.applyGravityAndRefill()
        }
    }

    private func applyGravityAndRefill() {
        let falls = board.applyGravity()
        boardNode.animateFalls(falls) { [weak self] in
            guard let self = self else { return }
            let newTiles = self.board.fillFromTop()
            self.boardNode.animateNewTiles(newTiles) { [weak self] in
                guard let self = self else { return }
                self.cascadeCount += 1

                // Check for new matches (cascade)
                let more = self.board.detectMatches()
                if !more.isEmpty {
                    self.processMatches()
                } else {
                    self.cascadeCount = 0
                    self.finishStableBoard()
                }
            }
        }
    }

    private func finishStableBoard() {
        state = .idle

        if checkWin() { return }
        resolveChocolateAfterStableBoardIfNeeded()
        if checkWin() { return }
        if checkLoss() { return }
        checkDeadlock()
    }

    // MARK: - Special Activation

    private func containsPosition(_ positions: [(row: Int, col: Int)], _ pos: (row: Int, col: Int)) -> Bool {
        positions.contains { $0.row == pos.row && $0.col == pos.col }
    }

    private func appendUniquePosition(_ pos: (row: Int, col: Int),
                                      to positions: inout [(row: Int, col: Int)]) {
        if !containsPosition(positions, pos) {
            positions.append(pos)
        }
    }

    // 范围消除如果命中已有条纹/包裹棋子，会继续把它的清除范围并入本轮。
    // 彩虹炸弹需要目标颜色，因此仍只通过交换触发，不在这里自动展开。
    private func expandedPositionsByActivatingExistingSpecials(
        from initialPositions: [(row: Int, col: Int)],
        preserving preservedPositions: [(row: Int, col: Int)] = []
    ) -> (positions: [(row: Int, col: Int)], activationBonus: Int) {
        var positions: [(row: Int, col: Int)] = []
        var activatedKeys = Set<String>()
        var activationBonus = 0

        for pos in initialPositions {
            appendUniquePosition(pos, to: &positions)
        }

        var index = 0
        while index < positions.count {
            let pos = positions[index]
            index += 1

            guard !containsPosition(preservedPositions, pos),
                  let tile = board.tile(at: pos),
                  tile.special != .none,
                  tile.special != .colorBomb else { continue }

            let key = "\(pos.row)_\(pos.col)"
            guard !activatedKeys.contains(key) else { continue }
            activatedKeys.insert(key)

            let affected = board.positionsForSpecial(tile.special, at: pos)
            activationBonus += affected.count * GameConstants.scorePerTile
            for affectedPos in affected {
                appendUniquePosition(affectedPos, to: &positions)
            }
        }

        return (positions, activationBonus)
    }

    // 两个特殊棋子互换时触发组合技，例如双条纹十字消除、
    // 条纹加包裹的大范围横竖清除，以及彩虹炸弹组合。
    private func handleSpecialComboActivation(_ effect: SpecialComboEffect) {
        let expanded = expandedPositionsByActivatingExistingSpecials(from: effect.positions,
                                                                     preserving: effect.consumedPositions)
        let positions = expanded.positions

        LiveOpsManager.shared.recordSpecialComboActivated()
        HapticsManager.shared.special()
        shakeBoard(intensity: 6, duration: 0.30)
        boardNode.animateSpecialActivation(at: effect.origin,
                                           affectedPositions: positions,
                                           special: effect.visualSpecial) { [weak self] in
            guard let self = self else { return }
            let result = self.board.removeTiles(at: positions)
            self.recordRemoveResult(result)
            self.updateObjectiveProgress(positions: positions)
            self.addScore(positions.count * GameConstants.scorePerTile * effect.scoreMultiplier
                + expanded.activationBonus)
            self.boardNode.syncWithBoard()
            self.applyGravityAndRefill()
        }
    }

    // 处理非交换触发的特殊棋子效果，例如横竖条纹、爆炸或按颜色清除，
    // 之后回到重力与补充流程。
    private func activateSpecialTile(at pos: (row: Int, col: Int), targetColor: GemColor? = nil) {
        guard let tile = board.tile(at: pos), tile.special != .none else { return }
        let special = tile.special

        let affected = board.positionsForSpecial(special, at: pos, targetColor: targetColor)
        tile.special = .none  // consume
        let expanded = expandedPositionsByActivatingExistingSpecials(from: affected)

        state = .animating
        HapticsManager.shared.special()
        boardNode.animateSpecialActivation(at: pos, affectedPositions: expanded.positions, special: special) { [weak self] in
            guard let self = self else { return }
            let result = self.board.removeTiles(at: expanded.positions)
            self.recordRemoveResult(result)
            self.updateObjectiveProgress(positions: expanded.positions)
            let score = expanded.positions.count * GameConstants.scorePerTile * 2
                + expanded.activationBonus
            self.addScore(score)
            self.boardNode.syncWithBoard()
            self.applyGravityAndRefill()
        }
    }

    // MARK: - Color Bomb Activation

    // 单独处理彩虹炸弹交换，因为目标颜色必须在棋盘数据变化前记录下来。
    private func handleColorBombActivation(bombPos: (row: Int, col: Int), targetColor: GemColor?) {
        guard let bombTile = board.tile(at: bombPos), bombTile.special == .colorBomb else {
            // Both might be color bombs (double bomb)
            handleDoubleBomb()
            return
        }

        var affected = board.positionsForSpecial(.colorBomb, at: bombPos, targetColor: targetColor)
        appendUniquePosition(bombPos, to: &affected)
        board.grid[bombPos.row][bombPos.col]?.special = .none
        let expanded = expandedPositionsByActivatingExistingSpecials(from: affected)

        HapticsManager.shared.colorBomb()
        boardNode.animateSpecialActivation(at: bombPos, affectedPositions: expanded.positions, special: .colorBomb) { [weak self] in
            guard let self = self else { return }
            let result = self.board.removeTiles(at: expanded.positions)
            self.recordRemoveResult(result)
            self.updateObjectiveProgress(positions: expanded.positions)
            self.addScore(expanded.positions.count * GameConstants.scorePerTile * 3
                + expanded.activationBonus)
            self.boardNode.syncWithBoard()
            self.applyGravityAndRefill()
        }
    }

    private func handleDoubleBomb() {
        var all: [(row: Int, col: Int)] = []
        for r in 0..<board.rows {
            for c in 0..<board.cols {
                if let t = board.grid[r][c], !t.isHole { all.append((r, c)) }
            }
        }
        clearAllTiles(all)
    }

    private func clearAllTiles(_ positions: [(row: Int, col: Int)]) {
        boardNode.animateRemovals(positions) { [weak self] in
            guard let self = self else { return }
            let result = self.board.removeTiles(at: positions)
            self.recordRemoveResult(result)
            self.updateObjectiveProgress(positions: positions)
            self.addScore(positions.count * GameConstants.scorePerTile * 4)
            self.boardNode.syncWithBoard()
            self.applyGravityAndRefill()
        }
    }

    // MARK: - Booster Handling

    // 处理 HUD 和开局选择中的消耗型道具，包括库存扣减、棋盘变化和玩家反馈。
    private func handleHammerTap(at pos: (row: Int, col: Int)) {
        guard let tile = board.tile(at: pos), !tile.isHole else { return }
        isHammerMode = false

        state = .animating
        boardNode.deselectAll()

        boardNode.animateRemovals([pos]) { [weak self] in
            guard let self = self else { return }
            let result = self.board.removeTiles(at: [pos])
            self.recordRemoveResult(result)
            self.updateObjectiveProgress(positions: [pos])
            self.addScore(GameConstants.scorePerTile * 2)
            self.boardNode.syncWithBoard()
            self.applyGravityAndRefill()
        }
        AudioManager.shared.play(.boosterUse)
    }

    private func activateBooster(_ type: BoosterType) {
        guard state == .idle else { return }

        switch type {
        case .hammer:
            if PlayerData.shared.useBooster(.hammer) {
                LiveOpsManager.shared.recordBoosterUsed()
                usedBoosterThisLevel = true
                AnalyticsManager.shared.track(.boosterUsed,
                                              properties: ["level": "\(level.id)", "type": "hammer"])
                isHammerMode = true
                hud.updateBoosterCounts()
                showBoosterIndicator(L10n.tr("game.hammer_hint", fallback: "🔨 Tap a tile to remove it!"))
            } else {
                showBuyBoosterPrompt(type)
            }
        case .shuffle:
            if PlayerData.shared.useBooster(.shuffle) {
                LiveOpsManager.shared.recordBoosterUsed()
                usedBoosterThisLevel = true
                AnalyticsManager.shared.track(.boosterUsed,
                                              properties: ["level": "\(level.id)", "type": "shuffle"])
                board.shuffle()
                boardNode.animateShuffle { [weak self] in
                    self?.boardNode.rebuildAfterShuffle()
                    self?.state = .idle
                }
                state = .animating
                hud.updateBoosterCounts()
            } else {
                showBuyBoosterPrompt(type)
            }
        case .extraMoves:
            if PlayerData.shared.useBooster(.extraMoves) {
                LiveOpsManager.shared.recordBoosterUsed()
                usedBoosterThisLevel = true
                AnalyticsManager.shared.track(.boosterUsed,
                                              properties: ["level": "\(level.id)", "type": "extra_moves"])
                remainingMoves += 5
                hud.updateMoves(remainingMoves)
                hud.updateBoosterCounts()
                showFloatingText(L10n.tr("game.extra_moves", fallback: "+5 MOVES!"), color: UIColor(hex: "#34C759"))
            } else {
                showBuyBoosterPrompt(type)
            }
        case .colorBomb:
            if PlayerData.shared.useBooster(.colorBomb) {
                LiveOpsManager.shared.recordBoosterUsed()
                usedBoosterThisLevel = true
                AnalyticsManager.shared.track(.boosterUsed,
                                              properties: ["level": "\(level.id)", "type": "color_bomb"])
                placeColorBombBooster()
                hud.updateBoosterCounts()
            } else {
                showBuyBoosterPrompt(type)
            }
        }
    }

    private func placeColorBombBooster() {
        // Find a random non-special tile and make it a color bomb
        var candidates: [(row: Int, col: Int)] = []
        for r in 0..<board.rows {
            for c in 0..<board.cols {
                if let t = board.grid[r][c], !t.isHole, t.special == .none, t.obstacle == .none {
                    candidates.append((r, c))
                }
            }
        }
        guard let target = candidates.randomElement() else { return }
        board.grid[target.row][target.col]?.special = .colorBomb
        boardNode.tileNodes[target.row][target.col]?.refresh()
        boardNode.tileNodes[target.row][target.col]?.pulse(scale: 1.4)
        AudioManager.shared.play(.specialCreated)
    }

    private func showBuyBoosterPrompt(_ type: BoosterType) {
        showFloatingText(L10n.fmt("game.need_more_booster", type.name, type.cost, fallback: "Need more %@!\nCost: %d 🪙"),
                         color: UIColor(hex: "#FF9500"))
    }

    private func showBoosterIndicator(_ text: String) {
        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = text
        lbl.fontSize = 16
        lbl.fontColor = UIColor(hex: "#FFCC00")
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: 0, y: size.height/2 - 190)
        lbl.zPosition = 50
        lbl.name = "boosterIndicator"
        addChild(lbl)

        lbl.run(.sequence([
            .repeatForever(.sequence([
                .fadeAlpha(to: 0.5, duration: 0.4),
                .fadeAlpha(to: 1.0, duration: 0.4)
            ]))
        ]))
    }

    // MARK: - Score & Objectives

    // 维护分数、步数、临时计分事件和目标进度，保证 HUD 与胜负判断同步。
    private func addScore(_ amount: Int) {
        currentScore += amount
        hud.updateScore(currentScore)
        PlayerData.shared.totalScore += amount
    }

    private func spendMove() {
        remainingMoves -= 1
        hud.updateMoves(remainingMoves)
        shouldResolveChocolateAfterCascade = true
        clearedChocolateThisMove = false

        movesUntilNextEvent -= 1
        if movesUntilNextEvent <= 0 && level.id >= 10 && Int.random(in: 0..<5) == 0 {
            triggerScoreMultiplierEvent()
        }
    }

    private func recordRemoveResult(_ result: Board.RemoveResult) {
        if !result.chocolateCleared.isEmpty {
            clearedChocolateThisMove = true
        }
        LiveOpsManager.shared.recordJellyCleared(result.jellyReduced.count)
        LiveOpsManager.shared.recordIceCleared(result.iceCleared.count)
        LiveOpsManager.shared.recordChocolateCleared(result.chocolateCleared.count)
        if !result.chestOpened.isEmpty {
            let reward = result.chestOpened.count * GameConstants.scorePerSpecial
            addScore(reward)
            showFloatingText(L10n.fmt("game.chest_opened", reward.scoreFormatted,
                                      fallback: "CHEST +%@"),
                             color: UIColor(hex: "#FFCC00"))
        }
        if !result.keysCollected.isEmpty {
            collectedKeys += result.keysCollected.count
        }
        if !result.locksOpened.isEmpty {
            let lockReward = result.locksOpened.count * GameConstants.scorePerSpecial
            addScore(lockReward)
            showFloatingText(L10n.fmt("game.lock_opened", result.locksOpened.count, lockReward.scoreFormatted,
                                      fallback: "%d LOCKS +%@"),
                             color: UIColor(hex: "#66D9FF"))
        }
    }

    private func resolveChocolateAfterStableBoardIfNeeded() {
        guard shouldResolveChocolateAfterCascade else { return }
        defer {
            shouldResolveChocolateAfterCascade = false
            clearedChocolateThisMove = false
        }
        guard !clearedChocolateThisMove else { return }

        let newChocolate = board.spreadChocolate()
        guard !newChocolate.isEmpty else { return }

        boardNode.syncWithBoard()
        updateObjectiveProgress(positions: [])
        showFloatingText(L10n.tr("game.chocolate_spread", fallback: "CHOCOLATE SPREAD!"),
                         color: UIColor(hex: "#8B4513"))
    }

    private func triggerScoreMultiplierEvent() {
        guard scoreMultiplier == 1 else { return }
        scoreMultiplier = 2
        movesUntilNextEvent = Int.random(in: 8...15)

        showFloatingText(L10n.tr("game.double_points", fallback: "⚡ DOUBLE POINTS!"), color: UIColor(hex: "#FFCC00"))
        HapticsManager.shared.special()

        multiplierTimer?.invalidate()
        multiplierTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            self?.scoreMultiplier = 1
        }
    }

    private func updateObjectiveProgress(positions: [(row: Int, col: Int)]) {
        for i in 0..<objectives.count {
            switch objectives[i].kind {
            case .score(let t):
                objectives[i].progress = min(currentScore, t)
                hud.updateObjective(i, progress: min(currentScore, t))
            case .collect(let color, let target):
                let count = collectedCounts[color] ?? 0
                objectives[i].progress = min(count, target)
                hud.updateObjective(i, progress: min(count, target))
            case .clearAllJelly:
                let remaining = board.jellyCount
                objectives[i].progress = remaining
                hud.updateObjective(i, progress: remaining)
            case .breakIce:
                let remaining = board.iceCount
                objectives[i].progress = remaining
                hud.updateObjective(i, progress: remaining)
            case .eliminateChocolate:
                let remaining = board.chocolateCount
                objectives[i].progress = remaining
                hud.updateObjective(i, progress: remaining)
            case .openChests:
                let remaining = board.chestCount
                objectives[i].progress = remaining
                hud.updateObjective(i, progress: remaining)
            case .collectKeys(let target):
                let progress = min(collectedKeys, target)
                objectives[i].progress = progress
                hud.updateObjective(i, progress: progress)
            }
        }
    }

    // MARK: - Win / Lose

    // 判断关卡胜负、保存奖励与进度、处理无可行步的洗牌，并跳转到庆祝或结果界面。
    private func checkWin() -> Bool {
        let allComplete = objectives.allSatisfy { obj in
            switch obj.kind {
            case .score(let t): return currentScore >= t
            case .collect(let color, let count): return (collectedCounts[color] ?? 0) >= count
            case .clearAllJelly: return board.jellyCount == 0
            case .breakIce: return board.iceCount <= 0
            case .eliminateChocolate: return board.chocolateCount == 0
            case .openChests: return board.chestCount == 0
            case .collectKeys(let count): return collectedKeys >= count
            }
        }

        if allComplete {
            triggerWin()
            return true
        }
        return false
    }

    private func checkLoss() -> Bool {
        if remainingMoves <= 0 {
            // Check if objectives complete first
            if objectives.allSatisfy({ $0.isComplete }) {
                triggerWin()
                return true
            }
            showOutOfMoves()
            return true
        }
        return false
    }

    private func checkDeadlock() {
        if !board.hasPossibleMove() {
            board.shuffle()
            boardNode.animateShuffle { [weak self] in
                self?.boardNode.rebuildAfterShuffle()
                self?.state = .idle
            }
            state = .animating
            showFloatingText(L10n.tr("game.board_shuffled", fallback: "🔄 Board shuffled!"), color: UIColor(hex: "#FFCC00"))
        }
    }

    private func triggerWin() {
        state = .won
        hintTimer?.invalidate()
        multiplierTimer?.invalidate()
        hideHints()
        // 结算前停掉震屏并归位，避免棋盘停在偏移位置
        boardNode.removeAction(forKey: "shake")
        if let home = boardNodeHomePosition { boardNode.position = home }

        let rewardedMoves = remainingMoves
        let moveBonus = awardRemainingMoveBonus()
        AudioManager.shared.play(.levelWin)
        HapticsManager.shared.win()
        let stars = level.stars(for: currentScore)

        // Save progress
        PlayerData.shared.setStars(stars, forLevel: level.id)
        PlayerData.shared.setBestScore(currentScore, forLevel: level.id)
        PlayerData.shared.unlockLevel(level.id + 1)

        // Coin reward + win streak bonus
        let streak = PlayerData.shared.recordWin()
        let baseCoins = EconomyConfig.shared.winCoins(stars: stars,
                                                      remainingMoves: rewardedMoves,
                                                      winStreak: streak)
        let coinMultiplier = LiveEventManager.shared.winCoinMultiplier
        let coins = baseCoins * coinMultiplier
        PlayerData.shared.addCoins(coins)
        PlayerData.shared.totalMatches += 1
        LiveOpsManager.shared.recordLevelWin(usedBooster: usedBoosterThisLevel)
        AnalyticsManager.shared.track(.levelWin,
                                      properties: ["level": "\(level.id)",
                                                   "score": "\(currentScore)",
                                                   "stars": "\(stars)",
                                                   "remaining_moves": "\(rewardedMoves)",
                                                   "move_bonus": "\(moveBonus)",
                                                   "coin_multiplier": "\(coinMultiplier)",
                                                   "used_booster": "\(usedBoosterThisLevel)",
                                                   "coins": "\(coins)"])
        AnalyticsManager.shared.updateProgressUserProperties(highestLevel: PlayerData.shared.maxUnlockedLevel,
                                                             totalStars: PlayerData.shared.totalStars)

        // Game Center
        GameCenterManager.shared.submitScore(PlayerData.shared.totalScore, to: .totalScore)
        GameCenterManager.shared.submitScore(PlayerData.shared.maxUnlockedLevel, to: .highestLevel)
        GameCenterManager.shared.submitScore(PlayerData.shared.totalStars, to: .totalStars)
        GameCenterManager.shared.checkAchievements()

        // Check if player just entered a new world
        let newWorldUnlocked = checkNewWorldUnlock(fromLevel: level.id, toLevel: level.id + 1)

        // Win animation
        let delay = celebrationBurst()

        run(.wait(forDuration: delay + 0.5)) { [weak self] in
            guard let self = self else { return }
            if let world = newWorldUnlocked {
                self.showWorldUnlockBanner(world: world) {
                    self.showResultScene(won: true, stars: stars, coinsEarned: coins)
                }
            } else {
                self.showResultScene(won: true, stars: stars, coinsEarned: coins)
            }
        }
    }

    private func awardRemainingMoveBonus() -> Int {
        guard remainingMoves > 0 else { return 0 }

        let moves = remainingMoves
        let bonus = moves * GameConstants.scorePerSpecial
        remainingMoves = 0
        hud.updateMoves(remainingMoves)
        addScore(bonus)
        showFloatingText(L10n.fmt("game.move_bonus", moves, bonus.scoreFormatted,
                                  fallback: "%d MOVES BONUS +%@"),
                         color: UIColor(hex: "#FFCC00"))
        return bonus
    }

    private func celebrationBurst() -> TimeInterval {
        var delay = 0.0
        for i in 0..<20 {
            let color = GemColor(rawValue: i % 6)!.primary
            let tex = PixelArt.shared.particleTexture(color: color, size: 10)
            let p = SKSpriteNode(texture: tex, size: CGSize(width: 10, height: 10))
            p.position = CGPoint(x: CGFloat.random(in: -size.width/2...size.width/2),
                                 y: size.height * 0.6)
            p.zPosition = 30
            addChild(p)

            let d = Double(i) * 0.05
            delay = max(delay, d + 0.8)

            p.run(.sequence([
                .wait(forDuration: d),
                .group([
                    .moveBy(x: CGFloat.random(in: -80...80), y: -300, duration: 0.8),
                    .sequence([.fadeIn(withDuration: 0.1), .fadeOut(withDuration: 0.7)])
                ]),
                .removeFromParent()
            ]))
        }
        return delay
    }

    private func showResultScene(won: Bool, stars: Int = 0, coinsEarned: Int = 0) {
        guard let view = view else { return }
        let scene = ResultScene(size: size)
        scene.level = level
        scene.isWin = won
        scene.stars = stars
        scene.score = currentScore
        scene.coinsEarned = coinsEarned
        scene.winStreak = won ? PlayerData.shared.winStreak : 0
        scene.completionRatio = won ? 1 : objectiveCompletionRatio()
        scene.scaleMode = .aspectFill
        view.presentScene(scene, transition: .fade(withDuration: 0.5))
    }

    // MARK: - Pause

    // 展示会阻塞游戏流程的弹窗：暂停、设置、步数耗尽、重开和返回地图。
    // 这里会按场景需要恢复状态或切换到新场景。
    private func showPause() {
        guard state == .idle || state == .animating else { return }
        let prevState = state
        state = .paused
        hintTimer?.invalidate()

        let dialog = PauseDialogNode(sceneSize: size)
        dialog.zPosition = 100
        addChild(dialog)

        dialog.onResume = { [weak self, weak dialog] in
            dialog?.dismiss()
            self?.state = prevState
            self?.startHintTimer()
        }
        dialog.onRestart = { [weak self] in
            self?.restartLevel()
        }
        dialog.onQuit = { [weak self] in
            self?.goToMap()
        }
        dialog.onSettings = { [weak self] in
            dialog.dismiss()
            self?.showSettings()
        }
    }

    private func showSettings() {
        let dialog = SettingsDialog(sceneSize: size)
        dialog.zPosition = 101
        addChild(dialog)
        dialog.onClose = { [weak dialog] in dialog?.dismiss() }
    }

    private func showOutOfMoves() {
        state = .paused
        AnalyticsManager.shared.track(.levelFail,
                                      properties: ["level": "\(level.id)",
                                                   "score": "\(currentScore)",
                                                   "reason": "out_of_moves"])
        let dialog = OutOfMovesDialog(sceneSize: size,
                                      hintText: failureHintText(),
                                      completionRatio: objectiveCompletionRatio())
        dialog.zPosition = 100
        addChild(dialog)

        dialog.onContinue = { [weak self, weak dialog] in
            guard let self = self else { return }
            let cost = EconomyConfig.shared.outOfMovesContinueDiamonds
            if PlayerData.shared.spendDiamonds(cost) {
                self.remainingMoves += 5
                self.hud.updateMoves(self.remainingMoves)
                dialog?.dismiss()
                self.state = .idle
                self.checkDeadlock()
            } else {
                self.showFloatingText(L10n.tr("game.not_enough_diamonds", fallback: "Not enough diamonds!"), color: UIColor(hex: "#FF3B30"))
            }
        }
        // HKAdKit "extraMoves" placement：看激励视频换 +5 步，不消耗钻石。
        // earned=false（用户关闭/SDK 失败/VIP 抑制）保留弹窗，玩家可改走钻石/退出路径。
        dialog.onWatchAd = { [weak self, weak dialog] in
            guard let self = self,
                  let view = self.view,
                  let vc = view.window?.rootViewController else { return }
            AdManager.shared.showRewardedAd(placement: "extraMoves", from: vc) { earned in
                DispatchQueue.main.async {
                    guard earned else { return }
                    self.remainingMoves += 5
                    self.hud.updateMoves(self.remainingMoves)
                    dialog?.dismiss()
                    self.state = .idle
                    self.checkDeadlock()
                }
            }
        }
        dialog.onQuit = { [weak self] in
            AudioManager.shared.play(.levelFail)
            HapticsManager.shared.lose()
            PlayerData.shared.resetWinStreak()
            PlayerData.shared.totalMatches += 1
            self?.run(.wait(forDuration: 0.3)) {
                self?.showResultScene(won: false)
            }
        }
    }

    /// 各目标完成度的最小值（0...1）。≥0.8 视为"近胜"，弹窗换鼓励组并放大续命入口
    /// （近胜时刻的续命转化率最高，是三消商业化的关键触点）。
    private func objectiveCompletionRatio() -> Double {
        guard !objectives.isEmpty else { return 0 }
        var minRatio = 1.0
        for objective in objectives {
            let ratio: Double
            switch objective.kind {
            case .score(let target):
                ratio = target > 0 ? Double(currentScore) / Double(target) : 1
            case .collect(_, let count):
                ratio = count > 0 ? Double(objective.progress) / Double(count) : 1
            case .clearAllJelly:
                ratio = initialJellyCount > 0
                    ? 1 - Double(objective.progress) / Double(initialJellyCount) : 1
            case .breakIce:
                ratio = initialIceCount > 0
                    ? 1 - Double(objective.progress) / Double(initialIceCount) : 1
            case .eliminateChocolate:
                ratio = initialChocolateCount > 0
                    ? 1 - Double(objective.progress) / Double(initialChocolateCount) : 1
            case .openChests:
                ratio = initialChestCount > 0
                    ? 1 - Double(objective.progress) / Double(initialChestCount) : 1
            case .collectKeys(let count):
                ratio = count > 0 ? Double(collectedKeys) / Double(count) : 1
            }
            minRatio = min(minRatio, max(0, min(1, ratio)))
        }
        return minRatio
    }

    private func failureHintText() -> String? {
        guard let objective = objectives.first(where: { !$0.isComplete }) else { return nil }

        switch objective.kind {
        case .score(let target):
            let remaining = max(0, target - currentScore)
            return L10n.fmt("dialog.out_of_moves.hint.score", remaining.scoreFormatted,
                            fallback: "Need %@ more points")
        case .collect(let color, let count):
            let remaining = max(0, count - (collectedCounts[color] ?? 0))
            return L10n.fmt("dialog.out_of_moves.hint.collect", remaining, color.name,
                            fallback: "Need %d more %@")
        case .clearAllJelly:
            return L10n.fmt("dialog.out_of_moves.hint.jelly", board.jellyCount,
                            fallback: "%d jelly left")
        case .breakIce:
            return L10n.fmt("dialog.out_of_moves.hint.ice", board.iceCount,
                            fallback: "%d ice left")
        case .eliminateChocolate:
            return L10n.fmt("dialog.out_of_moves.hint.chocolate", board.chocolateCount,
                            fallback: "%d chocolate left")
        case .openChests:
            return L10n.fmt("dialog.out_of_moves.hint.chests", board.chestCount,
                            fallback: "%d chests left")
        case .collectKeys(let count):
            let remaining = max(0, count - collectedKeys)
            return L10n.fmt("dialog.out_of_moves.hint.keys", remaining,
                            fallback: "%d keys left")
        }
    }

    private func restartLevel() {
        guard let view = view else { return }
        let scene = GameScene(size: size)
        scene.level = level
        scene.scaleMode = .aspectFill
        view.presentScene(scene, transition: .fade(withDuration: 0.3))
    }

    private func goToMap() {
        guard let view = view else { return }
        let scene = MapScene(size: size)
        scene.scaleMode = .aspectFill
        view.presentScene(scene, transition: .fade(withDuration: 0.4))
    }

    // MARK: - Hints

    // 管理延迟提示。玩家输入后会重置提示，只在棋盘空闲时显示。
    private func startHintTimer() {
        hintTimer?.invalidate()
        let interval: TimeInterval = VisualComfort.isReducedMotionEnabled ? 5.5 : 3.5
        hintTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.showHint()
        }
    }

    private func resetHintTimer() {
        hideHints()
        hintShown = false
        startHintTimer()
    }

    private func showHint() {
        guard state == .idle else { return }
        if let candidate = bestHintCandidate() {
            boardNode.showHint(a: candidate.a, b: candidate.b)
            hintShown = true
        }
    }

    private func bestHintCandidate() -> HintCandidate? {
        var best: HintCandidate?

        for r in 0..<board.rows {
            for c in 0..<board.cols {
                if c + 1 < board.cols && board.canSwap((r, c), (r, c + 1)) {
                    best = betterHint(best, candidateForHint(a: (r, c), b: (r, c + 1)))
                }
                if r + 1 < board.rows && board.canSwap((r, c), (r + 1, c)) {
                    best = betterHint(best, candidateForHint(a: (r, c), b: (r + 1, c)))
                }
            }
        }
        return best
    }

    private func betterHint(_ current: HintCandidate?, _ next: HintCandidate) -> HintCandidate {
        guard let current = current else { return next }
        return next.score > current.score ? next : current
    }

    private func candidateForHint(a: (row: Int, col: Int),
                                  b: (row: Int, col: Int)) -> HintCandidate {
        let specialBonus = hintSpecialSwapBonus(a: a, b: b)
        board.doSwap(a, b)
        let matches = board.detectMatches(preferredSpecialPositions: [b, a])
        let positions = uniqueHintPositions(matches.flatMap { $0.positions })
        let score = hintScore(matches: matches, positions: positions) + specialBonus
        board.doSwap(a, b)
        return HintCandidate(a: a, b: b, score: score)
    }

    private func hintSpecialSwapBonus(a: (row: Int, col: Int), b: (row: Int, col: Int)) -> Int {
        guard let first = board.tile(at: a), let second = board.tile(at: b) else { return 0 }
        if first.special == .colorBomb || second.special == .colorBomb {
            let color = first.special == .colorBomb ? second.gemColor : first.gemColor
            return 80 + board.count(of: color) * 4
        }
        if first.special != .none && second.special != .none { return 90 }
        if first.special != .none || second.special != .none { return 45 }
        return 0
    }

    private func hintScore(matches: [TileMatch],
                           positions: [(row: Int, col: Int)]) -> Int {
        var score = positions.count * 4
        for match in matches where match.createsSpecial != .none {
            score += match.createsSpecial == .colorBomb ? 70 : 35
        }

        for objective in objectives where !objective.isComplete {
            switch objective.kind {
            case .score:
                score += positions.count * 2
            case .collect(let color, _):
                score += positions.reduce(0) { total, pos in
                    total + ((board.tile(at: pos)?.gemColor == color) ? 18 : 0)
                }
            case .clearAllJelly:
                score += positions.reduce(0) { total, pos in
                    let obstacle = board.tile(at: pos)?.obstacle
                    return total + ((obstacle == .jelly1 || obstacle == .jelly2) ? 22 : 0)
                }
            case .breakIce:
                score += positions.reduce(0) { total, pos in
                    total + (board.tile(at: pos)?.obstacle == .ice
                        ? 24
                        : adjacentObstacleBonus(from: pos, obstacle: .ice, value: 8))
                }
            case .eliminateChocolate:
                score += positions.reduce(0) { total, pos in
                    total + (board.tile(at: pos)?.obstacle == .chocolate
                        ? 28
                        : adjacentObstacleBonus(from: pos, obstacle: .chocolate, value: 16))
                }
            case .openChests:
                score += positions.reduce(0) { total, pos in
                    let obstacle = board.tile(at: pos)?.obstacle
                    return total + ((obstacle == .chest1 || obstacle == .chest2)
                        ? 34
                        : adjacentChestBonus(from: pos, value: 18))
                }
            case .collectKeys:
                score += positions.reduce(0) { total, pos in
                    total + (board.tile(at: pos)?.obstacle == .key ? 38 : 0)
                }
            }
        }

        return score
    }

    private func adjacentObstacleBonus(from pos: (row: Int, col: Int),
                                       obstacle: ObstacleType,
                                       value: Int) -> Int {
        for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
            let next = (row: pos.row + dr, col: pos.col + dc)
            guard board.valid(next), board.tile(at: next)?.obstacle == obstacle else { continue }
            return value
        }
        return 0
    }

    private func adjacentChestBonus(from pos: (row: Int, col: Int),
                                    value: Int) -> Int {
        for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
            let next = (row: pos.row + dr, col: pos.col + dc)
            guard board.valid(next), let obstacle = board.tile(at: next)?.obstacle,
                  obstacle == .chest1 || obstacle == .chest2 else { continue }
            return value
        }
        return 0
    }

    private func uniqueHintPositions(_ positions: [(row: Int, col: Int)]) -> [(row: Int, col: Int)] {
        var seen = Set<String>()
        var result: [(row: Int, col: Int)] = []
        for position in positions {
            let key = "\(position.row)_\(position.col)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(position)
        }
        return result
    }

    private func hideHints() {
        boardNode.hideHints()
    }

    // MARK: - Utilities

    // 通用视觉反馈工具，包括短暂文本、连击提示和临时覆盖层。
    private func showComboText(_ combo: Int) {
        guard combo >= 2 else { return }
        let messages = [
            "",
            L10n.tr("combo.double", fallback: "DOUBLE!"),
            L10n.tr("combo.triple", fallback: "TRIPLE!"),
            L10n.tr("combo.mega", fallback: "MEGA!"),
            L10n.tr("combo.ultra", fallback: "ULTRA!")
        ]
        let idx = min(combo - 1, messages.count - 1)
        let text = messages[idx]
        guard !text.isEmpty else { return }

        let comboColors: [UIColor] = [
            UIColor(hex: "#FFCC00"),
            UIColor(hex: "#FF9500"),
            UIColor(hex: "#FF3B30"),
            UIColor(hex: "#AF52DE")
        ]
        let color = comboColors[min(combo - 2, comboColors.count - 1)]

        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = "×\(combo) \(text)"
        lbl.fontSize = 28 + CGFloat(combo) * 4
        lbl.fontColor = color
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.position = CGPoint(x: 0, y: 30)
        lbl.zPosition = 55
        addChild(lbl)

        if VisualComfort.isReducedMotionEnabled {
            lbl.setScale(1.0)
            lbl.alpha = 0
            lbl.run(.sequence([
                .fadeIn(withDuration: 0.12),
                .wait(forDuration: 0.7),
                .fadeOut(withDuration: 0.25),
                .removeFromParent()
            ]))
            return
        }

        // 砸入式：从 2.2 倍快速砸到 1.0，比从小放大更有冲击力
        lbl.setScale(2.2)
        lbl.alpha = 0
        lbl.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.06),
                .scale(to: 1.0, duration: 0.12)
            ]),
            .scale(to: 1.06, duration: 0.05),
            .scale(to: 1.0, duration: 0.05),
            .wait(forDuration: 0.55),
            .group([
                .scale(to: 1.8, duration: 0.28),
                .fadeOut(withDuration: 0.28)
            ]),
            .removeFromParent()
        ]))

        // ×4 以上加全屏白闪，强化"大场面"反馈
        if combo >= 4 {
            let flash = SKSpriteNode(color: .white, size: size)
            flash.position = .zero
            flash.zPosition = 54
            flash.alpha = 0
            addChild(flash)
            flash.run(.sequence([
                .fadeAlpha(to: 0.12, duration: 0.06),
                .fadeOut(withDuration: 0.18),
                .removeFromParent()
            ]))
        }
    }

    private func showFloatingText(_ text: String, color: UIColor) {
        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = text
        lbl.fontSize = 18
        lbl.fontColor = color
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.numberOfLines = 2
        lbl.position = CGPoint(x: 0, y: 0)
        lbl.zPosition = 50
        addChild(lbl)

        lbl.run(.sequence([
            .group([
                .moveBy(x: 0, y: 60, duration: 1.5),
                .sequence([.fadeIn(withDuration: 0.2), .wait(forDuration: 0.8), .fadeOut(withDuration: 0.5)])
            ]),
            .removeFromParent()
        ]))
    }

    override func update(_ currentTime: TimeInterval) { }

    // MARK: - World Unlock

    // 检查通关后是否解锁新世界，并在进入正常结果流程前展示庆祝横幅。
    private func checkNewWorldUnlock(fromLevel: Int, toLevel: Int) -> World? {
        guard let from = LevelData.level(fromLevel),
              let to   = LevelData.level(toLevel),
              to.worldId > from.worldId else { return nil }
        return GameWorlds.first { $0.id == to.worldId }
    }

    private func showWorldUnlockBanner(world: World, completion: @escaping () -> Void) {
        let overlay = SKNode()
        overlay.zPosition = 100
        addChild(overlay)

        // Dim background
        let dim = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.75),
                               size: CGSize(width: size.width + 20, height: size.height + 20))
        dim.alpha = 0
        overlay.addChild(dim)

        // Banner panel
        let panelW: CGFloat = min(size.width - 48, 320)
        let panelH: CGFloat = 200
        let panel = SKSpriteNode(color: world.themeColor.withAlphaComponent(0.95),
                                 size: CGSize(width: panelW, height: panelH))
        panel.position = CGPoint(x: 0, y: size.height)
        panel.zPosition = 1
        panel.alpha = 0
        overlay.addChild(panel)

        // Pixel border
        let border = SKShapeNode(rectOf: CGSize(width: panelW + 6, height: panelH + 6))
        border.strokeColor = UIColor.white
        border.lineWidth = 3
        border.fillColor = .clear
        border.position = panel.position
        border.zPosition = 2
        overlay.addChild(border)

        // Star burst particles
        for i in 0..<12 {
            let angle = CGFloat(i) / 12.0 * .pi * 2
            let star = SKLabelNode(text: "✦")
            star.fontSize = 14
            star.fontColor = UIColor.white.withAlphaComponent(0.8)
            star.position = CGPoint(x: cos(angle) * (panelW * 0.42),
                                    y: sin(angle) * (panelH * 0.42))
            star.zPosition = 3
            star.alpha = 0
            panel.addChild(star)
            star.run(.sequence([
                .wait(forDuration: 0.6 + Double(i) * 0.04),
                .fadeIn(withDuration: 0.15),
                .repeatForever(.rotate(byAngle: .pi * 2, duration: 4.0))
            ]))
        }

        // 新世界解锁标题。
        let header = SKLabelNode(fontNamed: "AvenirNext-Bold")
        header.text = L10n.tr("world_unlock.title", fallback: "NEW WORLD!")
        header.fontSize = 18
        header.fontColor = UIColor.white.withAlphaComponent(0.85)
        header.position = CGPoint(x: 0, y: panelH * 0.28)
        header.zPosition = 3
        panel.addChild(header)

        // World name
        let nameLbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        nameLbl.text = L10n.upper(world.localizedName)
        nameLbl.fontSize = 26
        nameLbl.fontColor = .white
        nameLbl.position = CGPoint(x: 0, y: 0)
        nameLbl.zPosition = 3
        panel.addChild(nameLbl)

        // Subtext
        let subLbl = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subLbl.text = L10n.tr("world_unlock.message", fallback: "You've unlocked a new world!")
        subLbl.fontSize = 13
        subLbl.fontColor = UIColor.white.withAlphaComponent(0.75)
        subLbl.position = CGPoint(x: 0, y: -panelH * 0.22)
        subLbl.zPosition = 3
        panel.addChild(subLbl)

        // Tap to continue
        let tapLbl = SKLabelNode(fontNamed: "AvenirNext-Medium")
        tapLbl.text = L10n.tr("world_unlock.tap", fallback: "Tap to continue")
        tapLbl.fontSize = 12
        tapLbl.fontColor = UIColor.white.withAlphaComponent(0.55)
        tapLbl.position = CGPoint(x: 0, y: -panelH * 0.38)
        tapLbl.zPosition = 3
        tapLbl.run(.repeatForever(.sequence([.fadeOut(withDuration: 0.7), .fadeIn(withDuration: 0.7)])))
        panel.addChild(tapLbl)

        // Slide in animation
        let slideIn = SKAction.move(to: .zero, duration: 0.5)
        slideIn.timingMode = .easeOut
        overlay.run(.fadeIn(withDuration: 0.35))
        dim.run(.fadeIn(withDuration: 0.35))
        panel.run(.group([.fadeIn(withDuration: 0.3), slideIn])) {
            // Pulse
            panel.run(.repeatForever(.sequence([
                .scale(to: 1.03, duration: 0.6),
                .scale(to: 1.0, duration: 0.6)
            ])), withKey: "pulse")
        }
        border.run(.group([.fadeIn(withDuration: 0.3),
                           .move(to: .zero, duration: 0.5)]))

        // Haptic
        HapticsManager.shared.special()

        // Auto-advance after 3 seconds then call completion
        let dismissBanner: () -> Void = { [weak overlay, weak panel, weak border] in
            guard let overlay = overlay, overlay.parent != nil else { return }
            let slideOut = SKAction.move(to: CGPoint(x: 0, y: -self.size.height), duration: 0.4)
            slideOut.timingMode = .easeIn
            panel?.run(.group([slideOut, .fadeOut(withDuration: 0.4)]))
            border?.run(.group([.move(to: CGPoint(x: 0, y: -self.size.height), duration: 0.4),
                                .fadeOut(withDuration: 0.4)]))
            overlay.run(.sequence([.wait(forDuration: 0.5),
                                    .fadeOut(withDuration: 0.2),
                                    .removeFromParent()])) {
                completion()
            }
        }
        run(.sequence([.wait(forDuration: 3.5), .run(dismissBanner)]), withKey: "worldBannerAuto")
    }
}
