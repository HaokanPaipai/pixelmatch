import SpriteKit

final class MapScene: SKScene {

    private var scrollNode: SKNode!
    private var contentHeight: CGFloat = 0
    private var touchStart: CGPoint?
    private var hasScrolled: Bool = false
    private var scrollVelocity: CGFloat = 0
    private var lastTouchY: CGFloat = 0
    private var lastTouchTime: TimeInterval = 0
    private var levelPositions: [Int: CGFloat] = [:]
    private var safeAreaInsets: UIEdgeInsets = .zero
    private var isTrackingScroll: Bool = false

    // Layout constants
    private let headerContentH: CGFloat = 90
    private var headerH: CGFloat { headerContentH + safeAreaInsets.top }
    private var safeTopY: CGFloat { size.height / 2 - safeAreaInsets.top }
    private var visibleCenterY: CGFloat { (safeAreaInsets.bottom - headerH) / 2 }
    private var visibleH: CGFloat { size.height - headerH - safeAreaInsets.bottom }
    private var visibleTopY: CGFloat { visibleCenterY + visibleH / 2 }
    private var visibleBottomY: CGFloat { visibleCenterY - visibleH / 2 }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        size = view.bounds.size
        safeAreaInsets = view.safeAreaInsets
        backgroundColor = UIColor(hex: "#050D1A")
        setupBackground()
        setupHeader()
        setupScrollContent()
        scrollToCurrentLevel()
        AudioManager.shared.startMusic()
    }

    // MARK: - Background

    private func setupBackground() {
        // Starfield
        for _ in 0..<80 {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...2))
            dot.fillColor = UIColor.white.withAlphaComponent(CGFloat.random(in: 0.2...0.7))
            dot.strokeColor = .clear
            dot.position = CGPoint(x: CGFloat.random(in: -size.width/2...size.width/2),
                                   y: CGFloat.random(in: -size.height/2...size.height/2))
            dot.zPosition = -5
            addChild(dot)
            // Twinkle
            dot.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.1, duration: Double.random(in: 0.5...2)),
                .fadeAlpha(to: 0.8, duration: Double.random(in: 0.5...2))
            ])))
        }
    }

    private func setupHeader() {
        let bg = SKShapeNode(rectOf: CGSize(width: size.width, height: headerH))
        bg.fillColor = UIColor(hex: "#0A1628").withAlphaComponent(0.95)
        bg.strokeColor = UIColor(hex: "#1C3A5C")
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: 0, y: size.height/2 - headerH / 2)
        bg.zPosition = 20
        addChild(bg)

        // Back button
        let backBtn = PixelButton(title: "◀", size: CGSize(width: 40, height: 40),
                                   style: .secondary, fontSize: 20)
        backBtn.position = CGPoint(x: -size.width/2 + safeAreaInsets.left + 32, y: safeTopY - 45)
        backBtn.zPosition = 25
        backBtn.onTap = { [weak self] in self?.goHome() }
        addChild(backBtn)

        // Title
        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.text = "PIXEL MATCH"
        title.fontSize = 24
        title.fontColor = UIColor(hex: "#FFCC00")
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: safeTopY - 38)
        title.zPosition = 25
        addChild(title)

        // Stars count
        let stars = PlayerData.shared.totalStars
        let starTex = PixelArt.shared.iconTexture(pixels: PixelIcons.starIcon,
                                                   primary: UIColor(hex: "#FFCC00"),
                                                   light: .white, dark: UIColor(hex: "#CC8800"),
                                                   size: 22)
        let starIcon = SKSpriteNode(texture: starTex, size: CGSize(width: 22, height: 22))
        starIcon.position = CGPoint(x: size.width/2 - safeAreaInsets.right - 65, y: safeTopY - 45)
        starIcon.zPosition = 25
        addChild(starIcon)

        let starsLbl = SKLabelNode(fontNamed: "Courier-Bold")
        starsLbl.text = "\(stars)"
        starsLbl.fontSize = 18
        starsLbl.fontColor = UIColor(hex: "#FFCC00")
        starsLbl.verticalAlignmentMode = .center
        starsLbl.position = CGPoint(x: size.width/2 - safeAreaInsets.right - 42, y: safeTopY - 45)
        starsLbl.zPosition = 25
        addChild(starsLbl)

        // Coins
        let coinTex = PixelArt.shared.iconTexture(pixels: PixelIcons.coin,
                                                   primary: UIColor(hex: "#FFCC00"),
                                                   light: .white, dark: UIColor(hex: "#CC8800"),
                                                   size: 20)
        let coinIcon = SKSpriteNode(texture: coinTex, size: CGSize(width: 20, height: 20))
        coinIcon.position = CGPoint(x: size.width/2 - safeAreaInsets.right - 65, y: safeTopY - 68)
        coinIcon.zPosition = 25
        addChild(coinIcon)

        let coinsLbl = SKLabelNode(fontNamed: "Courier-Bold")
        coinsLbl.text = "\(PlayerData.shared.coins)"
        coinsLbl.fontSize = 16
        coinsLbl.fontColor = UIColor(hex: "#FFCC00")
        coinsLbl.verticalAlignmentMode = .center
        coinsLbl.position = CGPoint(x: size.width/2 - safeAreaInsets.right - 42, y: safeTopY - 68)
        coinsLbl.zPosition = 25
        addChild(coinsLbl)
    }

    // MARK: - Scroll Content

    private func setupScrollContent() {
        let clip = SKCropNode()
        clip.maskNode = {
            let mask = SKShapeNode(rectOf: CGSize(width: size.width, height: visibleH))
            mask.fillColor = .white
            mask.position = CGPoint(x: 0, y: visibleCenterY)
            return mask
        }()
        clip.position = .zero
        clip.zPosition = 1
        addChild(clip)

        scrollNode = SKNode()
        clip.addChild(scrollNode)

        // Top-down layout: World 1 at top (y near 0), World 10 at bottom (most negative).
        // Each world stacked vertically with header + level grid + gap.
        let cols = 5
        let hMargin: CGFloat = 16 + max(safeAreaInsets.left, safeAreaInsets.right)
        let spacing: CGFloat = (size.width - 2 * hMargin) / CGFloat(cols)
        let headerSize: CGFloat = 56
        let headerGap: CGFloat = 14
        let worldGap: CGFloat = 36
        let topPad: CGFloat = 20

        var cursorY: CGFloat = -topPad

        for world in GameWorlds {
            let worldLevels = LevelData.all.filter { $0.worldId == world.id }
            guard !worldLevels.isEmpty else { continue }

            // Header (centered at cursorY - headerSize/2)
            cursorY -= headerSize / 2
            addWorldHeader(world: world, y: cursorY)
            cursorY -= headerSize / 2 + headerGap

            // Level grid: each row's center is spacing/2 below cursor, then advances by spacing
            let rows = (worldLevels.count + cols - 1) / cols
            for row in 0..<rows {
                cursorY -= spacing / 2
                for col in 0..<cols {
                    let idx = row * cols + col
                    guard idx < worldLevels.count else { continue }
                    let lvl = worldLevels[idx]
                    let x = -size.width/2 + hMargin + CGFloat(col) * spacing + spacing/2
                    let btn = LevelButtonNode(level: lvl, size: spacing - 10, theme: world)
                    btn.position = CGPoint(x: x, y: cursorY)
                    btn.zPosition = 5
                    btn.name = "level_\(lvl.id)"
                    scrollNode.addChild(btn)
                    levelPositions[lvl.id] = cursorY

                    btn.onTap = { [weak self] in self?.showLevelDetail(lvl) }
                }
                cursorY -= spacing / 2
            }

            cursorY -= worldGap
        }

        contentHeight = abs(cursorY) + topPad
        // Initial position: content's top edge (y=0) sits at visible area's top
        scrollNode.position = CGPoint(x: 0, y: visibleTopY)
    }

    private func addWorldHeader(world: World, y: CGFloat) {
        let bg = SKShapeNode(rectOf: CGSize(width: size.width - safeAreaInsets.left - safeAreaInsets.right - 24, height: 50), cornerRadius: 10)
        bg.fillColor = world.themeColor.withAlphaComponent(0.18)
        bg.strokeColor = world.themeColor.withAlphaComponent(0.7)
        bg.lineWidth = 2
        bg.position = CGPoint(x: 0, y: y)
        scrollNode.addChild(bg)

        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = "✦ \(world.name.uppercased()) ✦"
        lbl.fontSize = 17
        lbl.fontColor = world.themeColor
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: 0, y: y)
        scrollNode.addChild(lbl)

        // Sub-label: level range
        let rangeLbl = SKLabelNode(fontNamed: "Courier")
        rangeLbl.text = "Levels \(world.levelRange.lowerBound)-\(world.levelRange.upperBound)"
        rangeLbl.fontSize = 10
        rangeLbl.fontColor = world.themeColor.withAlphaComponent(0.7)
        rangeLbl.verticalAlignmentMode = .center
        rangeLbl.position = CGPoint(x: 0, y: y - 18)
        scrollNode.addChild(rangeLbl)
    }

    private func scrollToCurrentLevel() {
        let maxLevel = PlayerData.shared.maxUnlockedLevel
        let target = min(maxLevel, LevelData.all.count)
        guard let levelY = levelPositions[target] else { return }

        // Place the current level about 1/3 down from the visible top, for context.
        let targetSceneY = visibleTopY - visibleH * 0.30
        let desiredScrollY = targetSceneY - levelY
        let clamped = clampScrollY(desiredScrollY)

        scrollNode.run(.moveTo(y: clamped, duration: 0.45))
    }

    // MARK: - Level Detail

    private func showLevelDetail(_ level: Level) {
        guard PlayerData.shared.isLevelUnlocked(level.id) else {
            shake()
            return
        }

        let dialog = LevelDetailDialog(level: level, sceneSize: size)
        dialog.zPosition = 50
        addChild(dialog)

        dialog.onPlay = { [weak self, weak dialog] in
            dialog?.dismiss()
            self?.startLevel(level)
        }
        dialog.onClose = { [weak dialog] in dialog?.dismiss() }
    }

    private func startLevel(_ level: Level) {
        let lives = LivesManager.shared.currentLives
        guard lives > 0 else {
            showNoLivesDialog()
            return
        }

        // Show pre-level booster dialog for levels 5+
        if level.id >= 5 {
            showPreLevelDialog(level)
        } else {
            launchGameScene(level, selectedBoosters: [])
        }
    }

    private func showPreLevelDialog(_ level: Level) {
        let dialog = PreLevelDialog(level: level, sceneSize: size)
        dialog.zPosition = 55
        addChild(dialog)

        dialog.onPlay = { [weak self, weak dialog] boosters in
            dialog?.dismiss { self?.launchGameScene(level, selectedBoosters: boosters) }
        }
        dialog.onClose = { [weak dialog] in dialog?.dismiss() }
    }

    private func launchGameScene(_ level: Level, selectedBoosters: [BoosterType]) {
        guard let view = view else { return }
        _ = LivesManager.shared.spendLife()

        let scene = GameScene(size: size)
        scene.level = level
        scene.preGameBoosters = selectedBoosters
        scene.scaleMode = .aspectFill
        view.presentScene(scene, transition: .fade(withDuration: 0.4))
    }

    private func showNoLivesDialog() {
        let dialog = NoLivesDialog(sceneSize: size)
        dialog.zPosition = 60
        addChild(dialog)

        dialog.onRefillWithDiamonds = { [weak self, weak dialog] in
            if LivesManager.shared.refillLives(for: 15) {
                dialog?.dismiss()
            } else {
                self?.showFloatingText("Not enough diamonds!", color: UIColor(hex: "#FF3B30"))
            }
        }
        dialog.onWaitForFree = { [weak dialog] in dialog?.dismiss() }
        dialog.onClose = { [weak dialog] in dialog?.dismiss() }
    }

    private func goHome() {
        guard let view = view else { return }
        let scene = HomeScene(size: size)
        scene.scaleMode = .aspectFill
        view.presentScene(scene, transition: .fade(withDuration: 0.4))
    }

    // MARK: - Touch / Scroll

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        isTrackingScroll = loc.y <= visibleTopY && loc.y >= visibleBottomY
        touchStart = loc
        hasScrolled = false
        lastTouchY = loc.y
        lastTouchTime = touch.timestamp
        scrollVelocity = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isTrackingScroll, let touch = touches.first, let start = touchStart else { return }
        let current = touch.location(in: self)
        let dy = current.y - lastTouchY

        // Once finger has moved more than 6pt, treat as scroll (cancels button taps).
        if !hasScrolled && abs(current.y - start.y) > 6 {
            hasScrolled = true
        }

        let dt = touch.timestamp - lastTouchTime
        if dt > 0 { scrollVelocity = dy / CGFloat(dt) * 0.016 }
        lastTouchY = current.y
        lastTouchTime = touch.timestamp

        let newY = scrollNode.position.y + dy
        scrollNode.position.y = clampScrollY(newY)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            touchStart = nil
            isTrackingScroll = false
        }

        guard isTrackingScroll, !hasScrolled, let touch = touches.first else { return }
        if let levelButton = levelButton(at: touch.location(in: self)) {
            levelButton.triggerTap()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
        isTrackingScroll = false
    }

    /// Children check this before treating their own touch as a tap.
    var isCurrentlyScrolling: Bool { hasScrolled }

    override func update(_ currentTime: TimeInterval) {
        guard scrollNode != nil else { return }
        guard abs(scrollVelocity) > 0.5 else { scrollVelocity = 0; return }
        let newY = scrollNode.position.y + scrollVelocity
        let clamped = clampScrollY(newY)
        scrollNode.position.y = clamped
        // If we hit a clamp boundary, kill momentum.
        if clamped != newY { scrollVelocity = 0 } else { scrollVelocity *= 0.88 }
    }

    private func clampScrollY(_ y: CGFloat) -> CGFloat {
        // scrollNode local y range: [-contentHeight, 0]. Map to scene as scrollY + localY.
        // Initial (top of content visible at top of visible area): scrollY = visibleTopY
        // Max (bottom of content visible at bottom of visible area): scrollY = visibleBottomY + contentHeight
        let minY = visibleTopY
        let maxY = max(minY, visibleBottomY + contentHeight)
        return max(minY, min(maxY, y))
    }

    private func levelButton(at scenePoint: CGPoint) -> LevelButtonNode? {
        for node in nodes(at: scenePoint) {
            var current: SKNode? = node
            while let candidate = current {
                if let button = candidate as? LevelButtonNode {
                    return button
                }
                current = candidate.parent
            }
        }
        return nil
    }

    private func showFloatingText(_ text: String, color: UIColor) {
        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = text
        lbl.fontSize = 18
        lbl.fontColor = color
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: 0, y: 0)
        lbl.zPosition = 80
        addChild(lbl)
        lbl.run(.sequence([
            .group([.moveBy(x: 0, y: 50, duration: 1.2),
                    .sequence([.fadeIn(withDuration: 0.1), .wait(forDuration: 0.8), .fadeOut(withDuration: 0.3)])]),
            .removeFromParent()
        ]))
    }

}

// MARK: - Level Button Node

final class LevelButtonNode: SKNode {
    var onTap: (() -> Void)?
    private let level: Level
    private let btnSize: CGFloat

    init(level: Level, size: CGFloat, theme: World) {
        self.level = level
        self.btnSize = size
        super.init()
        buildUI(theme: theme)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(theme: World) {
        let isUnlocked = PlayerData.shared.isLevelUnlocked(level.id)
        let stars = PlayerData.shared.stars(forLevel: level.id)
        let completed = stars > 0

        // Button background
        let bg = SKShapeNode(rectOf: CGSize(width: btnSize - 4, height: btnSize - 4), cornerRadius: 8)
        if completed {
            bg.fillColor = theme.themeColor.withAlphaComponent(0.25)
            bg.strokeColor = theme.themeColor.withAlphaComponent(0.8)
        } else if isUnlocked {
            bg.fillColor = UIColor(hex: "#1C2E4A")
            bg.strokeColor = UIColor(hex: "#2255AA")
        } else {
            bg.fillColor = UIColor(hex: "#0A1020")
            bg.strokeColor = UIColor(hex: "#1A2030")
        }
        bg.lineWidth = 2
        bg.zPosition = 1
        addChild(bg)

        if isUnlocked {
            // Level number
            let lbl = SKLabelNode(fontNamed: "Courier-Bold")
            lbl.text = "\(level.id)"
            lbl.fontSize = min(16, btnSize * 0.3)
            lbl.fontColor = completed ? theme.themeColor : .white
            lbl.verticalAlignmentMode = .center
            lbl.zPosition = 2
            lbl.position = CGPoint(x: 0, y: 4)
            addChild(lbl)

            // Stars row
            if completed {
                for i in 0..<3 {
                    let starTex = PixelArt.shared.iconTexture(
                        pixels: PixelIcons.starIcon,
                        primary: i < stars ? UIColor(hex: "#FFCC00") : UIColor(hex: "#334466"),
                        light: i < stars ? .white : UIColor(hex: "#445577"),
                        dark: i < stars ? UIColor(hex: "#CC8800") : UIColor(hex: "#223355"),
                        size: 10)
                    let s = SKSpriteNode(texture: starTex, size: CGSize(width: 10, height: 10))
                    s.position = CGPoint(x: CGFloat(i-1) * 11, y: -12)
                    s.zPosition = 3
                    addChild(s)
                }
            }
        } else {
            // Lock icon (pixel)
            let lockPixels: [[UInt8]] = [
                [0,0,1,1,1,1,0,0],
                [0,1,0,0,0,0,1,0],
                [0,1,0,0,0,0,1,0],
                [1,1,1,1,1,1,1,1],
                [1,1,0,1,1,0,1,1],
                [1,1,0,1,1,0,1,1],
                [1,1,1,1,1,1,1,1],
                [0,0,0,0,0,0,0,0],
            ]
            let lockTex = PixelArt.shared.iconTexture(pixels: lockPixels,
                                                      primary: UIColor(hex: "#334466"),
                                                      light: UIColor(hex: "#445577"),
                                                      dark: UIColor(hex: "#223355"),
                                                      size: btnSize * 0.5)
            let lock = SKSpriteNode(texture: lockTex, size: CGSize(width: btnSize*0.4, height: btnSize*0.4))
            lock.zPosition = 2
            addChild(lock)
        }
    }

    func triggerTap() {
        run(.sequence([.scale(to: 0.9, duration: 0.05), .scale(to: 1.0, duration: 0.08)]))
        AudioManager.shared.play(.buttonTap)
        onTap?()
    }
}

// MARK: - Level Detail Dialog

final class LevelDetailDialog: DialogNode {
    var onPlay: (() -> Void)?
    var onClose: (() -> Void)?

    init(level: Level, sceneSize: CGSize) {
        super.init(size: CGSize(width: 300, height: 380), sceneSize: sceneSize)
        buildUI(level: level)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(level: Level) {
        // World name
        if let world = level.world {
            let worldLbl = SKLabelNode(fontNamed: "Courier-Bold")
            worldLbl.text = world.name.uppercased()
            worldLbl.fontSize = 14
            worldLbl.fontColor = world.themeColor
            worldLbl.verticalAlignmentMode = .center
            worldLbl.position = CGPoint(x: 0, y: 160)
            addChild(worldLbl)
        }

        addPixelTitle(level.displayName.uppercased(), y: 125)

        // Stars display
        let bestStars = PlayerData.shared.stars(forLevel: level.id)
        for i in 0..<3 {
            let lit = i < bestStars
            let tex = PixelArt.shared.iconTexture(pixels: PixelIcons.starIcon,
                                                   primary: lit ? UIColor(hex: "#FFCC00") : UIColor(hex: "#334466"),
                                                   light: lit ? .white : UIColor(hex: "#445577"),
                                                   dark: lit ? UIColor(hex: "#CC8800") : UIColor(hex: "#223355"),
                                                   size: 32)
            let s = SKSpriteNode(texture: tex, size: CGSize(width: 32, height: 32))
            s.position = CGPoint(x: CGFloat(i-1) * 38, y: 78)
            addChild(s)
        }

        // Objectives
        let objY: CGFloat = 30
        for (i, obj) in level.objectives.enumerated() {
            let lbl = SKLabelNode(fontNamed: "Courier")
            lbl.text = "▸ \(objectiveText(obj))"
            lbl.fontSize = 15
            lbl.fontColor = UIColor(hex: "#99BBCC")
            lbl.verticalAlignmentMode = .center
            lbl.position = CGPoint(x: 0, y: objY - CGFloat(i) * 24)
            addChild(lbl)
        }

        // Moves
        let movesLbl = SKLabelNode(fontNamed: "Courier-Bold")
        movesLbl.text = "Moves: \(level.moves)"
        movesLbl.fontSize = 16
        movesLbl.fontColor = UIColor(hex: "#7799CC")
        movesLbl.verticalAlignmentMode = .center
        movesLbl.position = CGPoint(x: 0, y: -30)
        addChild(movesLbl)

        // Best score
        let best = PlayerData.shared.bestScore(forLevel: level.id)
        if best > 0 {
            let bestLbl = SKLabelNode(fontNamed: "Courier")
            bestLbl.text = "Best: \(best.scoreFormatted)"
            bestLbl.fontSize = 14
            bestLbl.fontColor = UIColor(hex: "#FFCC00")
            bestLbl.verticalAlignmentMode = .center
            bestLbl.position = CGPoint(x: 0, y: -55)
            addChild(bestLbl)
        }

        // Lives display
        let lives = LivesManager.shared.currentLives
        let heartTex = PixelArt.shared.iconTexture(pixels: PixelIcons.heart,
                                                    primary: UIColor(hex: "#FF3B30"),
                                                    light: UIColor(hex: "#FF9999"),
                                                    dark: UIColor(hex: "#991111"),
                                                    size: 20)
        for i in 0..<GameConstants.maxLives {
            let h = SKSpriteNode(texture: heartTex, size: CGSize(width: 20, height: 20))
            h.position = CGPoint(x: CGFloat(i-2) * 24, y: -82)
            h.alpha = i < lives ? 1.0 : 0.25
            addChild(h)
        }

        if !LivesManager.shared.isFull {
            let timeLbl = SKLabelNode(fontNamed: "Courier")
            timeLbl.text = "+♥ in \(LivesManager.shared.timeUntilNextLifeString)"
            timeLbl.fontSize = 12
            timeLbl.fontColor = UIColor(hex: "#FF3B30")
            timeLbl.verticalAlignmentMode = .center
            timeLbl.position = CGPoint(x: 0, y: -105)
            addChild(timeLbl)
        }

        // Play button
        let playBtn = PixelButton(title: lives > 0 ? "▶ PLAY!" : "NO LIVES",
                                   size: CGSize(width: 240, height: 54),
                                   style: .primary,
                                   color: lives > 0 ? UIColor(hex: "#34C759") : UIColor(hex: "#FF3B30"),
                                   fontSize: 22)
        playBtn.position = CGPoint(x: 0, y: -155)
        playBtn.onTap = { [weak self] in self?.onPlay?() }
        addChild(playBtn)

        let closeBtn = PixelButton(title: "✕", size: CGSize(width: 36, height: 36),
                                   style: .ghost, color: UIColor(hex: "#7799CC"), fontSize: 18)
        closeBtn.position = CGPoint(x: 130, y: 170)
        closeBtn.onTap = { [weak self] in self?.onClose?() }
        addChild(closeBtn)
    }

    private func objectiveText(_ obj: LevelObjective) -> String {
        switch obj.kind {
        case .score(let t): return "Score \(t.scoreFormatted) pts"
        case .collect(let c, let n): return "Collect \(n) \(c.name)"
        case .clearAllJelly: return "Clear all jelly"
        case .breakIce(let n): return "Break \(n) ice blocks"
        case .eliminateChocolate: return "Remove chocolate"
        }
    }
}
