import SpriteKit
import GameplayKit

// MARK: - Game State

enum GameState {
    case idle, selecting, animating, paused, won, failed
}

// MARK: - GameScene

final class GameScene: SKScene {

    // Level
    var level: Level!
    var preGameBoosters: [BoosterType] = []

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

    // Collected counts (for collect objectives)
    private var collectedCounts: [GemColor: Int] = [:]
    private var initialIceCount: Int = 0

    // Score multiplier event
    private var scoreMultiplier: Int = 1
    private var multiplierTimer: Timer?
    private var movesUntilNextEvent: Int = 10

    // MARK: - Lifecycle

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
    }

    // MARK: - Setup

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
        worldLbl.text = world.name.uppercased()
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

        boardNode = BoardNode(board: board)

        // Center the board in the playable area between the top HUD and bottom boosters.
        let topReservedHeight = safeAreaInsets.top + GameHUD.contentHeight + 15
        let bottomReservedHeight = safeAreaInsets.bottom + GameHUD.boosterReservedHeight
        let playableTop = size.height / 2 - topReservedHeight
        let playableBottom = -size.height / 2 + bottomReservedHeight
        let boardY = (playableTop + playableBottom) / 2

        boardNode.position = CGPoint(x: 0, y: boardY)
        boardNode.zPosition = 1
        addChild(boardNode)
    }

    private func setupHUD() {
        objectives = level.objectives
        remainingMoves = level.moves
        collectedCounts = [:]
        initialIceCount = board.iceCount

        // Initialize "remaining" objectives with board state
        for i in 0..<objectives.count {
            switch objectives[i].kind {
            case .clearAllJelly: objectives[i].progress = board.jellyCount
            case .breakIce:     objectives[i].progress = board.iceCount
            case .eliminateChocolate: break
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

        // Apply pre-game boosters
        for booster in preGameBoosters {
            _ = PlayerData.shared.useBooster(booster)
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

        let worldName = level.world?.name ?? "Level"
        let lbl1 = SKLabelNode(fontNamed: "Courier-Bold")
        lbl1.text = worldName.uppercased()
        lbl1.fontSize = 14
        lbl1.fontColor = UIColor(hex: level.world?.themeColorHex ?? "#FFCC00")
        lbl1.verticalAlignmentMode = .center
        lbl1.position = CGPoint(x: 0, y: 22)
        intro.addChild(lbl1)

        let lbl2 = SKLabelNode(fontNamed: "Courier-Bold")
        lbl2.text = level.displayName.uppercased()
        lbl2.fontSize = 38
        lbl2.fontColor = .white
        lbl2.verticalAlignmentMode = .center
        lbl2.position = CGPoint(x: 0, y: -8)
        intro.addChild(lbl2)

        let lbl3 = SKLabelNode(fontNamed: "Courier")
        lbl3.text = objectiveSummary()
        lbl3.fontSize = 13
        lbl3.fontColor = UIColor(hex: "#99BBCC")
        lbl3.verticalAlignmentMode = .center
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
        case .score(let t): return "Score \(t.scoreFormatted) pts"
        case .collect(let c, let n): return "Collect \(n) \(c.name)s"
        case .clearAllJelly: return "Clear all jelly"
        case .breakIce(let n): return "Break \(n) ice blocks"
        case .eliminateChocolate: return "Eliminate chocolate"
        }
    }

    // MARK: - Touch Handling

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

    private func attemptSwap(from a: (row: Int, col: Int), to b: (row: Int, col: Int)) {
        guard state == .idle else { return }
        guard board.isAdjacent(a, b) else { return }
        guard let ta = board.tile(at: a), let tb = board.tile(at: b) else { return }
        guard !ta.isHole && !tb.isHole else { return }

        // Color bomb combo – determine bomb/target BEFORE swap
        if ta.special == .colorBomb || tb.special == .colorBomb {
            state = .animating
            let bombPos    = ta.special == .colorBomb ? a : b
            let targetPos  = ta.special == .colorBomb ? b : a
            let targetColor = board.tile(at: targetPos)?.gemColor
            boardNode.animateSwap(from: a, to: b) { [weak self] in
                guard let self = self else { return }
                self.handleColorBombActivation(bombPos: bombPos, targetColor: targetColor)
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
                self.processMatches()
            }
            spendMove()
        } else {
            HapticsManager.shared.invalidSwap()
            boardNode.animateInvalidSwap(from: a, to: b) { }
        }
    }

    // MARK: - Match Processing Pipeline

    private func processMatches() {
        let matches = board.detectMatches()
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

        // Score calculation with combo multiplier + event multiplier
        let comboMult = cascadeCount > 0 ? min(cascadeCount + 1, 5) : 1
        let matchScore = (allPositions.count * GameConstants.scorePerTile * comboMult
            + specialCreations.count * GameConstants.scorePerSpecial) * scoreMultiplier
        addScore(matchScore)

        // Haptic + combo text feedback
        if cascadeCount > 0 {
            HapticsManager.shared.cascade()
            showComboText(cascadeCount + 1)
        } else {
            HapticsManager.shared.match()
        }

        // Remove tiles (creating specials where needed)
        let firstSpecial = specialCreations.first
        let firstSpecialPos = firstSpecial?.pos
        let firstSpecialKind = firstSpecial?.special ?? .none

        boardNode.animateRemovals(allPositions,
                                   specialPos: firstSpecialPos,
                                   newSpecial: firstSpecialKind) { [weak self] in
            guard let self = self else { return }
            let _ = self.board.removeTiles(at: allPositions,
                                           specialPos: firstSpecialPos,
                                           newSpecial: firstSpecialKind)

            self.updateObjectiveProgress(positions: allPositions)
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
                    // Activate specials that were just created
                    self.checkAndActivateSpecials()
                }
            }
        }
    }

    private func checkAndActivateSpecials() {
        // Check if any remaining special needs activation
        state = .idle

        if checkWin() { return }
        if checkLoss() { return }
        checkDeadlock()
    }

    // MARK: - Special Activation

    private func activateSpecialTile(at pos: (row: Int, col: Int), targetColor: GemColor? = nil) {
        guard let tile = board.tile(at: pos), tile.special != .none else { return }
        let special = tile.special

        let affected = board.positionsForSpecial(special, at: pos, targetColor: targetColor)
        tile.special = .none  // consume

        state = .animating
        HapticsManager.shared.special()
        boardNode.animateSpecialActivation(at: pos, affectedPositions: affected, special: special) { [weak self] in
            guard let self = self else { return }
            let _ = self.board.removeTiles(at: affected)
            self.updateObjectiveProgress(positions: affected)
            let score = affected.count * GameConstants.scorePerTile * 2
            self.addScore(score)
            self.applyGravityAndRefill()
        }
    }

    // MARK: - Color Bomb Activation

    private func handleColorBombActivation(bombPos: (row: Int, col: Int), targetColor: GemColor?) {
        guard let bombTile = board.tile(at: bombPos), bombTile.special == .colorBomb else {
            // Both might be color bombs (double bomb)
            handleDoubleBomb()
            return
        }

        let affected = board.positionsForSpecial(.colorBomb, at: bombPos, targetColor: targetColor)
        board.grid[bombPos.row][bombPos.col]?.special = .none

        HapticsManager.shared.colorBomb()
        boardNode.animateSpecialActivation(at: bombPos, affectedPositions: affected, special: .colorBomb) { [weak self] in
            guard let self = self else { return }
            let _ = self.board.removeTiles(at: affected)
            self.updateObjectiveProgress(positions: affected)
            self.addScore(affected.count * GameConstants.scorePerTile * 3)
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
            let _ = self.board.removeTiles(at: positions)
            self.updateObjectiveProgress(positions: positions)
            self.addScore(positions.count * GameConstants.scorePerTile * 4)
            self.applyGravityAndRefill()
        }
    }

    // MARK: - Booster Handling

    private func handleHammerTap(at pos: (row: Int, col: Int)) {
        guard let tile = board.tile(at: pos), !tile.isHole else { return }
        isHammerMode = false

        state = .animating
        boardNode.deselectAll()

        boardNode.animateRemovals([pos]) { [weak self] in
            guard let self = self else { return }
            let _ = self.board.removeTiles(at: [pos])
            self.updateObjectiveProgress(positions: [pos])
            self.addScore(GameConstants.scorePerTile * 2)
            self.applyGravityAndRefill()
        }
        AudioManager.shared.play(.boosterUse)
    }

    private func activateBooster(_ type: BoosterType) {
        guard state == .idle else { return }

        switch type {
        case .hammer:
            if PlayerData.shared.useBooster(.hammer) {
                isHammerMode = true
                hud.updateBoosterCounts()
                showBoosterIndicator("🔨 Tap a tile to remove it!")
            } else {
                showBuyBoosterPrompt(type)
            }
        case .shuffle:
            if PlayerData.shared.useBooster(.shuffle) {
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
                remainingMoves += 5
                hud.updateMoves(remainingMoves)
                hud.updateBoosterCounts()
                showFloatingText("+5 MOVES!", color: UIColor(hex: "#34C759"))
            } else {
                showBuyBoosterPrompt(type)
            }
        case .colorBomb:
            if PlayerData.shared.useBooster(.colorBomb) {
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
        showFloatingText("Need more \(type.name)s!\nCost: \(type.cost) 🪙",
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

    private func addScore(_ amount: Int) {
        currentScore += amount
        hud.updateScore(currentScore)
        PlayerData.shared.totalScore += amount
    }

    private func spendMove() {
        remainingMoves -= 1
        hud.updateMoves(remainingMoves)
        board.spreadChocolate()

        movesUntilNextEvent -= 1
        if movesUntilNextEvent <= 0 && level.id >= 10 && Int.random(in: 0..<5) == 0 {
            triggerScoreMultiplierEvent()
        }
    }

    private func triggerScoreMultiplierEvent() {
        guard scoreMultiplier == 1 else { return }
        scoreMultiplier = 2
        movesUntilNextEvent = Int.random(in: 8...15)

        showFloatingText("⚡ DOUBLE POINTS!", color: UIColor(hex: "#FFCC00"))
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
                var chocolateCount = 0
                for r in 0..<board.rows {
                    for c in 0..<board.cols {
                        if board.grid[r][c]?.obstacle == .chocolate { chocolateCount += 1 }
                    }
                }
                objectives[i].progress = chocolateCount
                hud.updateObjective(i, progress: chocolateCount)
            }
        }
    }

    // MARK: - Win / Lose

    private func checkWin() -> Bool {
        let allComplete = objectives.allSatisfy { obj in
            switch obj.kind {
            case .score(let t): return currentScore >= t
            case .collect(let color, let count): return (collectedCounts[color] ?? 0) >= count
            case .clearAllJelly: return board.jellyCount == 0
            case .breakIce: return board.iceCount <= 0
            case .eliminateChocolate:
                for r in 0..<board.rows {
                    for c in 0..<board.cols {
                        if board.grid[r][c]?.obstacle == .chocolate { return false }
                    }
                }
                return true
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
            showFloatingText("🔄 Board shuffled!", color: UIColor(hex: "#FFCC00"))
        }
    }

    private func triggerWin() {
        state = .won
        hintTimer?.invalidate()
        multiplierTimer?.invalidate()
        hideHints()

        AudioManager.shared.play(.levelWin)
        HapticsManager.shared.win()
        let stars = level.stars(for: currentScore)

        // Save progress
        PlayerData.shared.setStars(stars, forLevel: level.id)
        PlayerData.shared.setBestScore(currentScore, forLevel: level.id)
        PlayerData.shared.unlockLevel(level.id + 1)

        // Coin reward + win streak bonus
        let streak = PlayerData.shared.recordWin()
        let streakBonus = min(streak / 3, 5) * 10
        let coins = (stars + 1) * 15 + remainingMoves * 5 + streakBonus
        PlayerData.shared.addCoins(coins)
        PlayerData.shared.totalMatches += 1

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
        scene.scaleMode = .aspectFill
        view.presentScene(scene, transition: .fade(withDuration: 0.5))
    }

    // MARK: - Pause

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
        let dialog = OutOfMovesDialog(sceneSize: size)
        dialog.zPosition = 100
        addChild(dialog)

        dialog.onContinue = { [weak self, weak dialog] in
            guard let self = self else { return }
            let cost = 10
            if PlayerData.shared.spendDiamonds(cost) {
                self.remainingMoves += 5
                self.hud.updateMoves(self.remainingMoves)
                dialog?.dismiss()
                self.state = .idle
                self.checkDeadlock()
            } else {
                self.showFloatingText("Not enough diamonds!", color: UIColor(hex: "#FF3B30"))
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

    private func startHintTimer() {
        hintTimer?.invalidate()
        hintTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
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
        // Find a possible move
        for r in 0..<board.rows {
            for c in 0..<board.cols {
                if c + 1 < board.cols && board.canSwap((r, c), (r, c + 1)) {
                    boardNode.showHint(a: (r, c), b: (r, c + 1))
                    hintShown = true
                    return
                }
                if r + 1 < board.rows && board.canSwap((r, c), (r + 1, c)) {
                    boardNode.showHint(a: (r, c), b: (r + 1, c))
                    hintShown = true
                    return
                }
            }
        }
    }

    private func hideHints() {
        boardNode.hideHints()
    }

    // MARK: - Utilities

    private func showComboText(_ combo: Int) {
        guard combo >= 2 else { return }
        let messages = ["", "DOUBLE!", "TRIPLE!", "MEGA!", "ULTRA!"]
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
        lbl.setScale(0.1)
        addChild(lbl)

        lbl.run(.sequence([
            .scale(to: 1.3, duration: 0.15),
            .scale(to: 1.0, duration: 0.08),
            .wait(forDuration: 0.6),
            .group([
                .scale(to: 2.0, duration: 0.3),
                .fadeOut(withDuration: 0.3)
            ]),
            .removeFromParent()
        ]))
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

        // "NEW WORLD!" header
        let header = SKLabelNode(fontNamed: "AvenirNext-Bold")
        header.text = "NEW WORLD!"
        header.fontSize = 18
        header.fontColor = UIColor.white.withAlphaComponent(0.85)
        header.position = CGPoint(x: 0, y: panelH * 0.28)
        header.zPosition = 3
        panel.addChild(header)

        // World name
        let nameLbl = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        nameLbl.text = world.name.uppercased()
        nameLbl.fontSize = 26
        nameLbl.fontColor = .white
        nameLbl.position = CGPoint(x: 0, y: 0)
        nameLbl.zPosition = 3
        panel.addChild(nameLbl)

        // Subtext
        let subLbl = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subLbl.text = "You've unlocked a new world!"
        subLbl.fontSize = 13
        subLbl.fontColor = UIColor.white.withAlphaComponent(0.75)
        subLbl.position = CGPoint(x: 0, y: -panelH * 0.22)
        subLbl.zPosition = 3
        panel.addChild(subLbl)

        // Tap to continue
        let tapLbl = SKLabelNode(fontNamed: "AvenirNext-Medium")
        tapLbl.text = "Tap to continue"
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
