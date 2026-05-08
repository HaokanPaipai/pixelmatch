import SpriteKit

final class ResultScene: SKScene {

    var level: Level!
    var isWin: Bool = true
    var stars: Int = 0
    var score: Int = 0
    var coinsEarned: Int = 0
    var winStreak: Int = 0

    private var starNodes: [SKNode] = []

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        size = view.bounds.size
        setupBackground()
        if isWin {
            setupWinUI()
        } else {
            setupFailUI()
        }
    }

    // MARK: - Background

    private func setupBackground() {
        backgroundColor = UIColor(hex: isWin ? "#0A1628" : "#1A0808")

        let world = level?.world ?? GameWorlds[0]
        let bgTex = PixelArt.shared.worldBgTexture(world: world, size: size)
        let bg = SKSpriteNode(texture: bgTex, size: size)
        bg.position = .zero
        bg.zPosition = -10
        addChild(bg)

        // Pixel particles for win
        if isWin { spawnConfetti() }
    }

    private func spawnConfetti() {
        for i in 0..<30 {
            let color = GemColor(rawValue: i % 6)!.primary
            let sq = SKShapeNode(rectOf: CGSize(width: 8, height: 8))
            sq.fillColor = color
            sq.strokeColor = .clear
            sq.position = CGPoint(x: CGFloat.random(in: -size.width/2...size.width/2),
                                  y: size.height * 0.6)
            sq.zPosition = 0
            addChild(sq)

            let delay = Double.random(in: 0...2)
            sq.run(.sequence([
                .wait(forDuration: delay),
                .repeatForever(.sequence([
                    .group([
                        .moveBy(x: CGFloat.random(in: -30...30), y: -size.height * 1.5, duration: Double.random(in: 3...5)),
                        .rotate(byAngle: .pi * CGFloat.random(in: 2...6), duration: Double.random(in: 3...5))
                    ])
                ]))
            ]))
        }
    }

    // MARK: - Win UI

    private func setupWinUI() {
        // Title
        let title = makeLargeLabel("LEVEL CLEAR!", color: UIColor(hex: "#FFCC00"), size: 36)
        title.position = CGPoint(x: 0, y: size.height * 0.3)
        title.zPosition = 10
        addChild(title)
        title.popIn()

        // Level info
        let levelLbl = makeLargeLabel(level.displayName.uppercased(),
                                      color: UIColor(hex: level.world?.themeColorHex ?? "#FFFFFF"),
                                      size: 18)
        levelLbl.position = CGPoint(x: 0, y: size.height * 0.22)
        levelLbl.zPosition = 10
        addChild(levelLbl)

        // Stars
        setupStars(y: size.height * 0.1)

        // Score panel
        setupScorePanel(y: -size.height * 0.08)

        // Coins reward
        setupCoinsReward(y: -size.height * 0.2)

        // Win streak
        if winStreak >= 3 {
            let streakLbl = makeLargeLabel("🔥 ×\(winStreak) STREAK BONUS!", color: UIColor(hex: "#FF9500"), size: 15)
            streakLbl.position = CGPoint(x: 0, y: -size.height * 0.27)
            streakLbl.zPosition = 11
            addChild(streakLbl)
            streakLbl.run(.repeatForever(.sequence([
                .scale(to: 1.08, duration: 0.3),
                .scale(to: 1.0, duration: 0.3)
            ])))
        }

        // Buttons
        setupWinButtons()
    }

    private func setupStars(y: CGFloat) {
        for i in 0..<3 {
            let lit = i < stars
            let x = CGFloat(i - 1) * 70

            let container = SKNode()
            container.position = CGPoint(x: x, y: y + (i == 1 ? 20 : 0))
            container.zPosition = 10
            addChild(container)

            let bg = SKShapeNode(circleOfRadius: 28)
            bg.fillColor = lit ? UIColor(hex: "#FFCC00").withAlphaComponent(0.2) : UIColor(hex: "#1C2E4A")
            bg.strokeColor = lit ? UIColor(hex: "#FFCC00") : UIColor(hex: "#334466")
            bg.lineWidth = 2
            container.addChild(bg)

            let tex = PixelArt.shared.iconTexture(pixels: PixelIcons.starIcon,
                                                   primary: lit ? UIColor(hex: "#FFCC00") : UIColor(hex: "#445577"),
                                                   light: lit ? .white : UIColor(hex: "#556688"),
                                                   dark: lit ? UIColor(hex: "#CC8800") : UIColor(hex: "#334466"),
                                                   size: 36)
            let star = SKSpriteNode(texture: tex, size: CGSize(width: 36, height: 36))
            container.addChild(star)

            if lit {
                container.setScale(0)
                let delay = 0.3 + Double(i) * 0.15
                container.run(.sequence([
                    .wait(forDuration: delay),
                    .scale(to: 1.3, duration: 0.15),
                    .scale(to: 1.0, duration: 0.1)
                ])) {
                    AudioManager.shared.play(.starEarn)
                }
            }
            starNodes.append(container)
        }
    }

    private func setupScorePanel(y: CGFloat) {
        let panel = SKShapeNode(rectOf: CGSize(width: 260, height: 80), cornerRadius: 12)
        panel.fillColor = UIColor(hex: "#0D1B2A")
        panel.strokeColor = UIColor(hex: "#2255AA")
        panel.lineWidth = 2
        panel.position = CGPoint(x: 0, y: y)
        panel.zPosition = 10
        addChild(panel)

        let scoreTitleLbl = makeLargeLabel("SCORE", color: UIColor(hex: "#7799CC"), size: 14)
        scoreTitleLbl.position = CGPoint(x: 0, y: y + 25)
        scoreTitleLbl.zPosition = 11
        addChild(scoreTitleLbl)

        let best = PlayerData.shared.bestScore(forLevel: level.id)
        let isNewBest = score >= best
        let scoreColor: UIColor = isNewBest ? UIColor(hex: "#FFCC00") : .white

        let scoreLbl = makeLargeLabel(score.scoreFormatted, color: scoreColor, size: 32)
        scoreLbl.position = CGPoint(x: 0, y: y - 5)
        scoreLbl.zPosition = 11
        addChild(scoreLbl)

        if isNewBest && best > 0 {
            let bestLbl = makeLargeLabel("✦ NEW BEST!", color: UIColor(hex: "#FF9500"), size: 13)
            bestLbl.position = CGPoint(x: 0, y: y - 28)
            bestLbl.zPosition = 11
            addChild(bestLbl)
            bestLbl.run(.repeatForever(.sequence([
                .scale(to: 1.1, duration: 0.4),
                .scale(to: 1.0, duration: 0.4)
            ])))
        }
    }

    private func setupCoinsReward(y: CGFloat) {
        if coinsEarned <= 0 { return }

        let coinTex = PixelArt.shared.iconTexture(pixels: PixelIcons.coin,
                                                   primary: UIColor(hex: "#FFCC00"),
                                                   light: .white,
                                                   dark: UIColor(hex: "#CC8800"),
                                                   size: 28)
        let coinIcon = SKSpriteNode(texture: coinTex, size: CGSize(width: 28, height: 28))
        coinIcon.position = CGPoint(x: -50, y: y)
        coinIcon.zPosition = 11
        addChild(coinIcon)

        let coinsLbl = makeLargeLabel("+\(coinsEarned) Coins!", color: UIColor(hex: "#FFCC00"), size: 22)
        coinsLbl.position = CGPoint(x: 20, y: y)
        coinsLbl.zPosition = 11
        addChild(coinsLbl)

        coinsLbl.run(.sequence([
            .wait(forDuration: 0.8),
            .group([
                .scale(to: 1.2, duration: 0.1),
                .scale(to: 1.0, duration: 0.1)
            ])
        ]))
        AudioManager.shared.play(.coinCollect)
    }

    private func setupWinButtons() {
        let yBase = -size.height * 0.38

        // Next Level button
        let nextBtn = PixelButton(title: "NEXT LEVEL ▶",
                                   size: CGSize(width: 240, height: 54),
                                   style: .primary,
                                   color: UIColor(hex: "#34C759"),
                                   fontSize: 20)
        nextBtn.position = CGPoint(x: 0, y: yBase)
        nextBtn.zPosition = 20
        nextBtn.onTap = { [weak self] in self?.goToNextLevel() }
        addChild(nextBtn)

        let mapBtn = PixelButton(title: "◀ LEVEL MAP",
                                  size: CGSize(width: 240, height: 46),
                                  style: .secondary,
                                  fontSize: 16)
        mapBtn.position = CGPoint(x: 0, y: yBase - 62)
        mapBtn.zPosition = 20
        mapBtn.onTap = { [weak self] in self?.goToMap() }
        addChild(mapBtn)

        let replayBtn = PixelButton(title: "↺ REPLAY",
                                    size: CGSize(width: 240, height: 40),
                                    style: .ghost,
                                    color: UIColor(hex: "#7799CC"),
                                    fontSize: 14)
        replayBtn.position = CGPoint(x: 0, y: yBase - 114)
        replayBtn.zPosition = 20
        replayBtn.onTap = { [weak self] in self?.replayLevel() }
        addChild(replayBtn)
    }

    // MARK: - Fail UI

    private func setupFailUI() {
        // Title
        let title = makeLargeLabel("LEVEL FAILED", color: UIColor(hex: "#FF3B30"), size: 36)
        title.position = CGPoint(x: 0, y: size.height * 0.28)
        title.zPosition = 10
        addChild(title)
        title.popIn()
        title.shake()

        // Score
        let scoreLbl = makeLargeLabel("Score: \(score.scoreFormatted)",
                                      color: UIColor(hex: "#99BBCC"), size: 22)
        scoreLbl.position = CGPoint(x: 0, y: size.height * 0.1)
        scoreLbl.zPosition = 10
        addChild(scoreLbl)

        // Try again message
        let msgLbl = makeLargeLabel("Don't give up!",
                                    color: UIColor(hex: "#FFCC00"), size: 18)
        msgLbl.position = CGPoint(x: 0, y: -10)
        msgLbl.zPosition = 10
        addChild(msgLbl)

        // Pixel broken-X art
        addBrokenX()
        setupFailButtons()
    }

    private func addBrokenX() {
        for i in 0..<8 {
            let size = CGFloat.random(in: 4...12)
            let sq = SKShapeNode(rectOf: CGSize(width: size, height: size))
            sq.fillColor = UIColor(hex: "#FF3B30").withAlphaComponent(0.6)
            sq.strokeColor = .clear
            sq.position = CGPoint(x: CGFloat.random(in: -80...80),
                                  y: CGFloat.random(in: -60...60))
            sq.zPosition = 9
            addChild(sq)
            sq.run(.repeatForever(.sequence([
                .scale(to: 1.2, duration: Double.random(in: 0.3...0.8)),
                .scale(to: 0.7, duration: Double.random(in: 0.3...0.8))
            ])))
        }
    }

    private func setupFailButtons() {
        let yBase = -size.height * 0.3

        let retryBtn = PixelButton(title: "↺ TRY AGAIN",
                                   size: CGSize(width: 240, height: 54),
                                   style: .primary,
                                   color: UIColor(hex: "#FF9500"),
                                   fontSize: 20)
        retryBtn.position = CGPoint(x: 0, y: yBase)
        retryBtn.zPosition = 20
        retryBtn.onTap = { [weak self] in self?.replayLevel() }
        addChild(retryBtn)

        let mapBtn = PixelButton(title: "◀ LEVEL MAP",
                                  size: CGSize(width: 240, height: 46),
                                  style: .secondary,
                                  fontSize: 16)
        mapBtn.position = CGPoint(x: 0, y: yBase - 62)
        mapBtn.zPosition = 20
        mapBtn.onTap = { [weak self] in self?.goToMap() }
        addChild(mapBtn)
    }

    // MARK: - Navigation

    private func goToNextLevel() {
        guard let view = view else { return }
        let nextId = level.id + 1
        if let nextLevel = LevelData.level(nextId),
           PlayerData.shared.isLevelUnlocked(nextId) {
            let scene = GameScene(size: size)
            scene.level = nextLevel
            scene.scaleMode = .aspectFill
            view.presentScene(scene, transition: .push(with: .left, duration: 0.4))
        } else {
            goToMap()
        }
    }

    private func goToMap() {
        guard let view = view else { return }
        let scene = MapScene(size: size)
        scene.scaleMode = .aspectFill
        view.presentScene(scene, transition: .fade(withDuration: 0.4))
    }

    private func replayLevel() {
        guard let view = view else { return }
        let scene = GameScene(size: size)
        scene.level = level
        scene.scaleMode = .aspectFill
        view.presentScene(scene, transition: .fade(withDuration: 0.3))
    }

    // MARK: - Helpers

    private func makeLargeLabel(_ text: String, color: UIColor, size: CGFloat) -> SKLabelNode {
        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = text
        lbl.fontSize = size
        lbl.fontColor = color
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        return lbl
    }
}
