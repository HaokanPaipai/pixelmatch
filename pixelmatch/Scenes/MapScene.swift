import SpriteKit
import HKAdKit

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
        let backBtn = PixelButton(icon: .back,
                                  size: CGSize(width: 40, height: 40),
                                  bgColor: UIColor(hex: "#1C2E4A"))
        backBtn.position = CGPoint(x: -size.width/2 + safeAreaInsets.left + 32, y: safeTopY - 45)
        backBtn.zPosition = 25
        backBtn.onTap = { [weak self] in self?.goHome() }
        addChild(backBtn)

        // Title
        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.text = L10n.tr("app.name.upper", fallback: "PIXEL MATCH")
        title.fontSize = 24
        title.fontColor = UIColor(hex: "#FFCC00")
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: safeTopY - 38)
        title.zPosition = 25
        addChild(title)

        let titleRightEdge = title.frame.maxX + 12
        addHeaderCounter(iconTexture: PixelArt.shared.starBadgeTexture(lit: true, size: 24),
                         iconSize: CGSize(width: 22, height: 22),
                         text: "\(PlayerData.shared.totalStars)",
                         fontSize: 18,
                         y: safeTopY - 45,
                         leftLimit: titleRightEdge)

        addHeaderCounter(iconTexture: PixelArt.shared.softIconTexture(.coin, size: 22),
                         iconSize: CGSize(width: 20, height: 20),
                         text: "\(PlayerData.shared.coins)",
                         fontSize: 16,
                         y: safeTopY - 68,
                         leftLimit: -size.width / 2 + safeAreaInsets.left + 64)
    }

    private func addHeaderCounter(iconTexture: SKTexture,
                                  iconSize: CGSize,
                                  text: String,
                                  fontSize: CGFloat,
                                  y: CGFloat,
                                  leftLimit: CGFloat) {
        let rightX = size.width / 2 - safeAreaInsets.right - 18
        let gap: CGFloat = 7

        let label = SKLabelNode(fontNamed: "Courier-Bold")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = UIColor(hex: "#FFCC00")
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .right
        label.position = CGPoint(x: rightX, y: y)
        label.zPosition = 25

        let rawTextWidth = max(label.frame.width, 1)
        let maxTextWidth = max(20, rightX - leftLimit - iconSize.width - gap)
        let labelScale = rawTextWidth > maxTextWidth
            ? max(0.62, maxTextWidth / rawTextWidth)
            : 1
        label.setScale(labelScale)

        let icon = SKSpriteNode(texture: iconTexture, size: iconSize)
        icon.position = CGPoint(x: rightX - rawTextWidth * labelScale - gap - iconSize.width / 2, y: y)
        icon.zPosition = 25

        addChild(icon)
        addChild(label)
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
        let headerSize: CGFloat = 66
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
        let width = size.width - safeAreaInsets.left - safeAreaInsets.right - 24
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: 60), cornerRadius: 10)
        bg.fillColor = world.themeColor.withAlphaComponent(0.18)
        bg.strokeColor = world.themeColor.withAlphaComponent(0.7)
        bg.lineWidth = 2
        bg.position = CGPoint(x: 0, y: y)
        scrollNode.addChild(bg)

        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = "✦ \(L10n.upper(world.localizedName)) ✦"
        lbl.fontSize = 17
        lbl.fontColor = world.themeColor
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: 0, y: y + 10)
        scrollNode.addChild(lbl)

        // Sub-label: level range
        let rangeLbl = SKLabelNode(fontNamed: "Courier")
        rangeLbl.text = L10n.fmt("map.levels_range", world.levelRange.lowerBound, world.levelRange.upperBound, fallback: "Levels %d-%d")
        rangeLbl.fontSize = 10
        rangeLbl.fontColor = world.themeColor.withAlphaComponent(0.7)
        rangeLbl.verticalAlignmentMode = .center
        rangeLbl.horizontalAlignmentMode = .left
        rangeLbl.position = CGPoint(x: -width / 2 + 16, y: y - 11)
        scrollNode.addChild(rangeLbl)

        let repair = WorldRepairManager.shared.snapshot(for: world)
        let repairLbl = SKLabelNode(fontNamed: "Courier-Bold")
        repairLbl.text = repair.isComplete
            ? L10n.tr("map.repair_complete", fallback: "RESTORED")
            : L10n.fmt("map.repair_progress", repair.percent, fallback: "REPAIR %d%%")
        repairLbl.fontSize = 10
        repairLbl.fontColor = world.themeColor
        repairLbl.verticalAlignmentMode = .center
        repairLbl.horizontalAlignmentMode = .right
        repairLbl.position = CGPoint(x: width / 2 - 16, y: y - 11)
        scrollNode.addChild(repairLbl)

        addRepairPixels(repair, width: width - 32, y: y - 25)
    }

    private func addRepairPixels(_ repair: WorldRepairSnapshot, width: CGFloat, y: CGFloat) {
        let gap: CGFloat = 4
        let pixelCount = max(1, repair.totalPieces)
        let pixelWidth = min(28, (width - CGFloat(pixelCount - 1) * gap) / CGFloat(pixelCount))
        let totalWidth = CGFloat(pixelCount) * pixelWidth + CGFloat(pixelCount - 1) * gap
        let startX = -totalWidth / 2 + pixelWidth / 2

        for index in 0..<pixelCount {
            let filled = index < repair.unlockedPieces
            let pixel = SKShapeNode(rectOf: CGSize(width: pixelWidth, height: 6), cornerRadius: 2)
            pixel.fillColor = filled
                ? repair.world.themeColor
                : UIColor(hex: "#0A1628").withAlphaComponent(0.9)
            pixel.strokeColor = repair.world.themeColor.withAlphaComponent(filled ? 0.8 : 0.35)
            pixel.lineWidth = 1
            pixel.position = CGPoint(x: startX + CGFloat(index) * (pixelWidth + gap), y: y)
            scrollNode.addChild(pixel)
        }
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
                self?.showFloatingText(L10n.tr("game.not_enough_diamonds", fallback: "Not enough diamonds!"), color: UIColor(hex: "#FF3B30"))
            }
        }
        dialog.onRefillWithAd = { [weak self, weak dialog] in
            guard let view = self?.view, let vc = view.window?.rootViewController else { return }
            AdManager.shared.showRewardedAd(placement: "refillLife", from: vc) { earned in
                DispatchQueue.main.async {
                    if earned {
                        // PixelMatchAdRewardProvider.grantReward 已经 +1 ❤；关弹窗刷新心数显示。
                        dialog?.dismiss()
                    }
                    // 失败/未发奖：保留弹窗，玩家可改走"REFILL 15💎"或"WAIT"。
                }
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
                    let starTex = PixelArt.shared.starBadgeTexture(lit: i < stars, size: 14)
                    let s = SKSpriteNode(texture: starTex, size: CGSize(width: 13, height: 13))
                    s.position = CGPoint(x: CGFloat(i-1) * 13, y: -13)
                    s.zPosition = 3
                    addChild(s)
                }
            }
        } else {
            let lockTex = PixelArt.shared.lockBadgeTexture(size: btnSize * 0.52)
            let lock = SKSpriteNode(texture: lockTex, size: CGSize(width: btnSize * 0.44, height: btnSize * 0.44))
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
        super.init(size: CGSize(width: 320, height: 440), sceneSize: sceneSize)
        buildUI(level: level)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(level: Level) {
        // World name
        if let world = level.world {
            let worldLbl = SKLabelNode(fontNamed: "Courier-Bold")
            worldLbl.text = L10n.upper(world.localizedName)
            worldLbl.fontSize = 14
            worldLbl.fontColor = world.themeColor
            worldLbl.verticalAlignmentMode = .center
            worldLbl.position = CGPoint(x: 0, y: 190)
            addChild(worldLbl)
        }

        addPixelTitle(L10n.upper(level.displayName), y: 154)

        // Stars display
        let bestStars = PlayerData.shared.stars(forLevel: level.id)
        for i in 0..<3 {
            let lit = i < bestStars
            let tex = PixelArt.shared.starBadgeTexture(lit: lit, size: 34)
            let s = SKSpriteNode(texture: tex, size: CGSize(width: 32, height: 32))
            s.position = CGPoint(x: CGFloat(i-1) * 38, y: 110)
            addChild(s)
        }

        addMechanicTags(for: level, y: 76)

        // Objectives
        let objY: CGFloat = 42
        for (i, obj) in level.objectives.enumerated() {
            let lbl = SKLabelNode(fontNamed: "Courier")
            lbl.text = "▸ \(objectiveText(obj))"
            lbl.fontSize = 15
            lbl.fontColor = UIColor(hex: "#99BBCC")
            lbl.verticalAlignmentMode = .center
            lbl.horizontalAlignmentMode = .center
            lbl.position = CGPoint(x: 0, y: objY - CGFloat(i) * 24)
            addChild(lbl)
        }

        // Moves
        let movesLbl = SKLabelNode(fontNamed: "Courier-Bold")
        movesLbl.text = L10n.fmt("map.moves", level.moves, fallback: "Moves: %d")
        movesLbl.fontSize = 16
        movesLbl.fontColor = UIColor(hex: "#7799CC")
        movesLbl.verticalAlignmentMode = .center
        movesLbl.position = CGPoint(x: 0, y: -42)
        addChild(movesLbl)

        // Best score
        let best = PlayerData.shared.bestScore(forLevel: level.id)
        if best > 0 {
            let bestLbl = SKLabelNode(fontNamed: "Courier")
            bestLbl.text = L10n.fmt("map.best", best.scoreFormatted, fallback: "Best: %@")
            bestLbl.fontSize = 14
            bestLbl.fontColor = UIColor(hex: "#FFCC00")
            bestLbl.verticalAlignmentMode = .center
            bestLbl.position = CGPoint(x: 0, y: -68)
            addChild(bestLbl)
        }

        // Lives display
        let lives = LivesManager.shared.currentLives
        for i in 0..<GameConstants.maxLives {
            let filled = i < lives
            let heartTex = PixelArt.shared.heartBadgeTexture(filled: filled, size: 22)
            let h = SKSpriteNode(texture: heartTex, size: CGSize(width: 20, height: 20))
            h.position = CGPoint(x: CGFloat(i-2) * 24, y: -100)
            h.alpha = filled ? 1.0 : 0.72
            addChild(h)
        }

        if !LivesManager.shared.isFull {
            let timeLbl = SKLabelNode(fontNamed: "Courier")
            timeLbl.text = L10n.fmt("map.life_timer", LivesManager.shared.timeUntilNextLifeString, fallback: "+♥ in %@")
            timeLbl.fontSize = 12
            timeLbl.fontColor = UIColor(hex: "#FF3B30")
            timeLbl.verticalAlignmentMode = .center
            timeLbl.position = CGPoint(x: 0, y: -122)
            addChild(timeLbl)
        }

        // Play button
        let playBtn = PixelButton(title: lives > 0 ? L10n.tr("map.play", fallback: "▶ PLAY!") : L10n.tr("map.no_lives", fallback: "NO LIVES"),
                                   icon: lives > 0 ? .play : .heart,
                                   size: CGSize(width: 240, height: 54),
                                   style: .primary,
                                   color: lives > 0 ? UIColor(hex: "#34C759") : UIColor(hex: "#FF3B30"),
                                   fontSize: 22)
        playBtn.position = CGPoint(x: 0, y: -174)
        playBtn.onTap = { [weak self] in self?.onPlay?() }
        addChild(playBtn)

        let closeBtn = PixelButton(icon: .close,
                                   size: CGSize(width: 36, height: 36),
                                   bgColor: UIColor(hex: "#1C2E4A"))
        closeBtn.position = CGPoint(x: 140, y: 200)
        closeBtn.onTap = { [weak self] in self?.onClose?() }
        addChild(closeBtn)
    }

    private func addMechanicTags(for level: Level, y: CGFloat) {
        let tags = levelTags(level)
        guard !tags.isEmpty else { return }

        let tagWidth: CGFloat = 76
        let gap: CGFloat = 7
        let totalWidth = CGFloat(tags.count) * tagWidth + CGFloat(tags.count - 1) * gap

        for (index, tag) in tags.enumerated() {
            let x = -totalWidth / 2 + tagWidth / 2 + CGFloat(index) * (tagWidth + gap)
            addTag(title: tag.title, color: tag.color, position: CGPoint(x: x, y: y))
        }
    }

    private func addTag(title: String, color: UIColor, position: CGPoint) {
        let bg = SKShapeNode(rectOf: CGSize(width: 76, height: 22), cornerRadius: 4)
        bg.fillColor = color.withAlphaComponent(0.16)
        bg.strokeColor = color.withAlphaComponent(0.75)
        bg.lineWidth = 1
        bg.position = position
        addChild(bg)

        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = title
        lbl.fontSize = 11
        lbl.fontColor = color
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        bg.addChild(lbl)
    }

    private func levelTags(_ level: Level) -> [(title: String, color: UIColor)] {
        var tags: [(title: String, color: UIColor)] = []
        let hasChocolate = level.obstacles.contains { $0.type == .chocolate }
        let hasStone = level.obstacles.contains { $0.type == .stone }
        let hasCage = level.obstacles.contains { $0.type == .cage }
        let hasChest = level.obstacles.contains { $0.type == .chest1 || $0.type == .chest2 }
        let hasKeyLock = level.obstacles.contains { $0.type == .key || $0.type == .lock }
        let hasPortal = !level.portalLinks.isEmpty
        let hasIce = level.obstacles.contains { $0.type == .ice }
        let hasJelly = level.obstacles.contains { $0.type == .jelly1 || $0.type == .jelly2 }

        if level.id % 20 == 0 {
            tags.append((L10n.tr("map.tag.boss", fallback: "BOSS"), UIColor(hex: "#FF2D55")))
        }
        if level.objectives.count >= 2 {
            tags.append((L10n.tr("map.tag.mixed", fallback: "MIXED"), UIColor(hex: "#AF52DE")))
        }
        if hasChocolate {
            tags.append((L10n.tr("map.tag.chocolate", fallback: "CHOCO"), UIColor(hex: "#D2691E")))
        } else if hasPortal {
            tags.append((L10n.tr("map.tag.portal", fallback: "PORTAL"), UIColor(hex: "#AF52DE")))
        } else if hasKeyLock {
            tags.append((L10n.tr("map.tag.key_lock", fallback: "KEY"), UIColor(hex: "#66D9FF")))
        } else if hasChest {
            tags.append((L10n.tr("map.tag.chest", fallback: "CHEST"), UIColor(hex: "#FFCC00")))
        } else if hasCage {
            tags.append((L10n.tr("map.tag.cage", fallback: "CAGE"), UIColor(hex: "#C0C7D0")))
        } else if hasStone {
            tags.append((L10n.tr("map.tag.stone", fallback: "STONE"), UIColor(hex: "#9A9AA3")))
        } else if hasIce {
            tags.append((L10n.tr("map.tag.ice", fallback: "ICE"), UIColor(hex: "#66D9FF")))
        } else if hasJelly {
            tags.append((L10n.tr("map.tag.jelly", fallback: "JELLY"), UIColor(hex: "#FF66CC")))
        }
        if tags.count < 3 && !level.holes.isEmpty {
            tags.append((L10n.tr("map.tag.holes", fallback: "HOLES"), UIColor(hex: "#99BBCC")))
        }
        if tags.count < 3 && (level.moves <= 21 || level.availableColors.count >= 6 || level.objectives.count >= 3) {
            tags.append((L10n.tr("map.tag.hard", fallback: "HARD"), UIColor(hex: "#FF9500")))
        }

        return Array(tags.prefix(3))
    }

    private func objectiveText(_ obj: LevelObjective) -> String {
        switch obj.kind {
        case .score(let t): return L10n.fmt("objective.score", t.scoreFormatted, fallback: "Score %@ pts")
        case .collect(let c, let n): return L10n.fmt("objective.collect", n, c.name, fallback: "Collect %d %@")
        case .clearAllJelly:
            guard obj.progress > 0 else {
                return L10n.tr("objective.clear_jelly", fallback: "Clear all jelly")
            }
            return L10n.fmt("objective.clear_jelly_count", obj.progress, fallback: "Clear %d jelly")
        case .breakIce(let n): return L10n.fmt("objective.break_ice", n, fallback: "Break %d ice blocks")
        case .eliminateChocolate:
            guard obj.progress > 0 else {
                return L10n.tr("objective.eliminate_chocolate", fallback: "Eliminate chocolate")
            }
            return L10n.fmt("objective.eliminate_chocolate_count", obj.progress, fallback: "Remove %d chocolate")
        case .openChests(let n):
            return L10n.fmt("objective.open_chests", n, fallback: "Open %d chests")
        case .collectKeys(let n):
            return L10n.fmt("objective.collect_keys", n, fallback: "Collect %d keys")
        }
    }
}
