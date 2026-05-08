import SpriteKit

final class HomeScene: SKScene {

    private var bgParticles: [SKNode] = []
    private var logoNode: SKNode!
    private var dailyRewardTimer: Timer?

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        size = view.bounds.size
        PlayerData.shared.completeFirstLaunch()
        setupBackground()
        setupLogo()
        setupPixelGems()
        setupPlayerInfo()
        setupMainButtons()
        setupBottomBar()
        checkDailyReward()
        animateEntrance()
        AudioManager.shared.startMusic()
        GameCenterManager.shared.authenticate()
    }

    override func willMove(from view: SKView) {
        dailyRewardTimer?.invalidate()
    }

    // MARK: - Background

    private func setupBackground() {
        backgroundColor = UIColor(hex: "#050D1A")

        // Deep space gradient
        let grad = SKShapeNode(rectOf: size)
        grad.fillColor = .clear
        grad.strokeColor = .clear
        grad.zPosition = -10
        addChild(grad)

        // Starfield
        for _ in 0..<120 {
            let r = CGFloat.random(in: 0.5...2.5)
            let dot = SKShapeNode(circleOfRadius: r)
            dot.fillColor = UIColor.white.withAlphaComponent(CGFloat.random(in: 0.1...0.8))
            dot.strokeColor = .clear
            dot.position = CGPoint(x: CGFloat.random(in: -size.width/2...size.width/2),
                                   y: CGFloat.random(in: -size.height/2...size.height/2))
            dot.zPosition = -9
            addChild(dot)
            dot.run(.repeatForever(.sequence([
                .fadeAlpha(to: CGFloat.random(in: 0.05...0.3), duration: Double.random(in: 0.8...3)),
                .fadeAlpha(to: 0.9, duration: Double.random(in: 0.8...3))
            ])))
        }

        // Floating pixel squares
        for i in 0..<12 {
            let sqSize = CGFloat.random(in: 6...20)
            let color = GemColor(rawValue: i % 6)!.primary.withAlphaComponent(0.15)
            let sq = SKShapeNode(rectOf: CGSize(width: sqSize, height: sqSize))
            sq.fillColor = color
            sq.strokeColor = color.withAlphaComponent(0.3)
            sq.lineWidth = 1
            sq.position = CGPoint(x: CGFloat.random(in: -size.width/2...size.width/2),
                                  y: CGFloat.random(in: -size.height/2...size.height/2))
            sq.zPosition = -8
            addChild(sq)
            bgParticles.append(sq)

            let floatY = CGFloat.random(in: 20...60)
            sq.run(.repeatForever(.sequence([
                .group([
                    .moveBy(x: CGFloat.random(in: -10...10), y: floatY, duration: Double.random(in: 2...4)),
                    .rotate(byAngle: .pi/4, duration: Double.random(in: 2...4))
                ]),
                .group([
                    .moveBy(x: CGFloat.random(in: -10...10), y: -floatY, duration: Double.random(in: 2...4)),
                    .rotate(byAngle: -.pi/4, duration: Double.random(in: 2...4))
                ])
            ])))
        }
    }

    // MARK: - Logo

    private func setupLogo() {
        logoNode = SKNode()
        logoNode.position = CGPoint(x: 0, y: size.height * 0.2)
        logoNode.zPosition = 5
        addChild(logoNode)

        // Pixel art title: "PIXEL MATCH"
        let titleLbl = SKLabelNode(fontNamed: "Courier-Bold")
        titleLbl.text = "PIXEL"
        titleLbl.fontSize = 52
        titleLbl.fontColor = UIColor(hex: "#FFCC00")
        titleLbl.verticalAlignmentMode = .center
        titleLbl.position = CGPoint(x: 0, y: 28)
        logoNode.addChild(titleLbl)

        let subtitleLbl = SKLabelNode(fontNamed: "Courier-Bold")
        subtitleLbl.text = "MATCH"
        subtitleLbl.fontSize = 52
        subtitleLbl.fontColor = .white
        subtitleLbl.verticalAlignmentMode = .center
        subtitleLbl.position = CGPoint(x: 0, y: -28)
        logoNode.addChild(subtitleLbl)

        // Pixel decoration dots
        for i in 0..<6 {
            let color = GemColor(rawValue: i)!.primary
            let dot = SKShapeNode(rectOf: CGSize(width: 12, height: 12))
            dot.fillColor = color
            dot.strokeColor = color.lighter()
            dot.lineWidth = 1
            dot.position = CGPoint(x: (CGFloat(i) - 2.5) * 22, y: -60)
            logoNode.addChild(dot)

            dot.run(.repeatForever(.sequence([
                .wait(forDuration: Double(i) * 0.12),
                .scale(to: 1.4, duration: 0.2),
                .scale(to: 1.0, duration: 0.2),
                .wait(forDuration: 0.8)
            ])))
        }

        // Tagline
        let tagLbl = SKLabelNode(fontNamed: "Courier")
        tagLbl.text = "The Ultimate Pixel Puzzle"
        tagLbl.fontSize = 14
        tagLbl.fontColor = UIColor(hex: "#7799CC")
        tagLbl.verticalAlignmentMode = .center
        tagLbl.position = CGPoint(x: 0, y: -82)
        logoNode.addChild(tagLbl)

        // Subtle logo float
        logoNode.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 6, duration: 2.0),
            .moveBy(x: 0, y: -6, duration: 2.0)
        ])))
    }

    // MARK: - Gems Decoration

    private func setupPixelGems() {
        let gems: [GemColor] = [.red, .blue, .green, .yellow, .purple, .orange]
        let spacing = size.width / CGFloat(gems.count + 1)

        for (i, color) in gems.enumerated() {
            let tex = PixelArt.shared.gemTexture(color: color, special: .none)
            let gem = SKSpriteNode(texture: tex, size: CGSize(width: 36, height: 36))
            gem.position = CGPoint(x: -size.width/2 + spacing * CGFloat(i+1),
                                   y: size.height * 0.05)
            gem.zPosition = 3
            addChild(gem)

            let delay = Double(i) * 0.1
            gem.run(.repeatForever(.sequence([
                .wait(forDuration: delay),
                .scale(to: 1.2, duration: 0.3),
                .scale(to: 0.9, duration: 0.3),
                .scale(to: 1.0, duration: 0.2),
                .wait(forDuration: 1.5)
            ])))
        }
    }

    // MARK: - Player Info

    private func setupPlayerInfo() {
        let infoBar = SKShapeNode(rectOf: CGSize(width: size.width - 40, height: 50), cornerRadius: 10)
        infoBar.fillColor = UIColor(hex: "#0D1B2A").withAlphaComponent(0.9)
        infoBar.strokeColor = UIColor(hex: "#1C3A5C")
        infoBar.lineWidth = 1.5
        infoBar.position = CGPoint(x: 0, y: size.height * 0.28)
        infoBar.zPosition = 6
        addChild(infoBar)

        // Player name
        let nameLbl = SKLabelNode(fontNamed: "Courier-Bold")
        nameLbl.text = PlayerData.shared.playerName
        nameLbl.fontSize = 16
        nameLbl.fontColor = .white
        nameLbl.verticalAlignmentMode = .center
        nameLbl.horizontalAlignmentMode = .left
        nameLbl.position = CGPoint(x: -size.width/2 + 36, y: size.height * 0.28)
        nameLbl.zPosition = 7
        addChild(nameLbl)

        // Level indicator
        let maxLvl = PlayerData.shared.maxUnlockedLevel
        let lvlLbl = SKLabelNode(fontNamed: "Courier-Bold")
        lvlLbl.text = "Level \(maxLvl)"
        lvlLbl.fontSize = 14
        lvlLbl.fontColor = UIColor(hex: "#FFCC00")
        lvlLbl.verticalAlignmentMode = .center
        lvlLbl.horizontalAlignmentMode = .right
        lvlLbl.position = CGPoint(x: size.width/2 - 36, y: size.height * 0.28)
        lvlLbl.zPosition = 7
        addChild(lvlLbl)

        // Currency row
        let currencyBar = SKNode()
        currencyBar.position = CGPoint(x: 0, y: size.height * 0.22)
        currencyBar.zPosition = 6

        // Coins
        let coinTex = PixelArt.shared.iconTexture(pixels: PixelIcons.coin,
                                                   primary: UIColor(hex: "#FFCC00"),
                                                   light: .white, dark: UIColor(hex: "#CC8800"), size: 22)
        let coinIcon = SKSpriteNode(texture: coinTex, size: CGSize(width: 22, height: 22))
        coinIcon.position = CGPoint(x: -80, y: 0)
        currencyBar.addChild(coinIcon)

        let coinsLbl = SKLabelNode(fontNamed: "Courier-Bold")
        coinsLbl.text = "\(PlayerData.shared.coins)"
        coinsLbl.fontSize = 16
        coinsLbl.fontColor = UIColor(hex: "#FFCC00")
        coinsLbl.verticalAlignmentMode = .center
        coinsLbl.horizontalAlignmentMode = .left
        coinsLbl.position = CGPoint(x: -66, y: 0)
        currencyBar.addChild(coinsLbl)

        // Diamonds
        let dTex = PixelArt.shared.iconTexture(pixels: PixelIcons.diamond,
                                               primary: UIColor(hex: "#AF52DE"),
                                               light: UIColor(hex: "#DDA0FF"),
                                               dark: UIColor(hex: "#7711CC"), size: 22)
        let dIcon = SKSpriteNode(texture: dTex, size: CGSize(width: 22, height: 22))
        dIcon.position = CGPoint(x: 40, y: 0)
        currencyBar.addChild(dIcon)

        let diamondsLbl = SKLabelNode(fontNamed: "Courier-Bold")
        diamondsLbl.text = "\(PlayerData.shared.diamonds)"
        diamondsLbl.fontSize = 16
        diamondsLbl.fontColor = UIColor(hex: "#AF52DE")
        diamondsLbl.verticalAlignmentMode = .center
        diamondsLbl.horizontalAlignmentMode = .left
        diamondsLbl.position = CGPoint(x: 54, y: 0)
        currencyBar.addChild(diamondsLbl)

        // Hearts
        let lives = LivesManager.shared.currentLives
        let heartTex = PixelArt.shared.iconTexture(pixels: PixelIcons.heart,
                                                    primary: UIColor(hex: "#FF3B30"),
                                                    light: UIColor(hex: "#FF9999"),
                                                    dark: UIColor(hex: "#991111"), size: 20)
        for i in 0..<GameConstants.maxLives {
            let h = SKSpriteNode(texture: heartTex, size: CGSize(width: 18, height: 18))
            h.position = CGPoint(x: -size.width/2 + 20 + CGFloat(i) * 22, y: size.height * 0.36)
            h.zPosition = 6
            h.alpha = i < lives ? 1.0 : 0.2
            addChild(h)
        }

        addChild(currencyBar)
    }

    // MARK: - Main Buttons

    private func setupMainButtons() {
        let playBtn = PixelButton(title: "▶ PLAY",
                                   size: CGSize(width: 260, height: 64),
                                   style: .primary,
                                   color: UIColor(hex: "#34C759"),
                                   fontSize: 28)
        playBtn.position = CGPoint(x: 0, y: -size.height * 0.12)
        playBtn.zPosition = 10
        playBtn.onTap = { [weak self] in self?.goToMap() }
        addChild(playBtn)

        // Pulse play button
        playBtn.run(.repeatForever(.sequence([
            .wait(forDuration: 1.5),
            .scale(to: 1.05, duration: 0.2),
            .scale(to: 1.0, duration: 0.2)
        ])))

        // Daily reward button (if available)
        if PlayerData.shared.canClaimDailyReward {
            let dailyBtn = PixelButton(title: "🎁 DAILY REWARD!",
                                       size: CGSize(width: 240, height: 50),
                                       style: .primary,
                                       color: UIColor(hex: "#FF9500"),
                                       fontSize: 18)
            dailyBtn.position = CGPoint(x: 0, y: -size.height * 0.23)
            dailyBtn.zPosition = 10
            dailyBtn.onTap = { [weak self] in self?.claimDailyReward() }
            addChild(dailyBtn)

            dailyBtn.run(.repeatForever(.sequence([
                .scale(to: 1.04, duration: 0.5),
                .scale(to: 1.0, duration: 0.5)
            ])))
        }
    }

    private func setupBottomBar() {
        let bar = SKShapeNode(rectOf: CGSize(width: size.width, height: 70))
        bar.fillColor = UIColor(hex: "#0A1628").withAlphaComponent(0.95)
        bar.strokeColor = UIColor(hex: "#1C3A5C")
        bar.lineWidth = 1.5
        bar.position = CGPoint(x: 0, y: -size.height/2 + 35)
        bar.zPosition = 20
        addChild(bar)

        // Shop button
        let shopBtn = PixelButton(icon: PixelIcons.coin,
                                   iconColor: UIColor(hex: "#FFCC00"),
                                   size: CGSize(width: 50, height: 50),
                                   bgColor: UIColor(hex: "#1C2E4A"))
        shopBtn.position = CGPoint(x: -size.width/2 + 45, y: -size.height/2 + 35)
        shopBtn.zPosition = 25
        shopBtn.onTap = { [weak self] in self?.showShop() }
        addChild(shopBtn)

        let shopLbl = SKLabelNode(fontNamed: "Courier")
        shopLbl.text = "SHOP"
        shopLbl.fontSize = 10
        shopLbl.fontColor = UIColor(hex: "#7799CC")
        shopLbl.verticalAlignmentMode = .center
        shopLbl.position = CGPoint(x: -size.width/2 + 45, y: -size.height/2 + 12)
        shopLbl.zPosition = 25
        addChild(shopLbl)

        // Settings button
        let settingsPixels: [[UInt8]] = [
            [0,0,1,1,1,1,0,0],
            [0,1,1,0,0,1,1,0],
            [1,1,0,0,0,0,1,1],
            [1,0,0,2,2,0,0,1],
            [1,0,0,2,2,0,0,1],
            [1,1,0,0,0,0,1,1],
            [0,1,1,0,0,1,1,0],
            [0,0,1,1,1,1,0,0],
        ]
        let settingsBtn = PixelButton(icon: settingsPixels,
                                      iconColor: UIColor(hex: "#7799CC"),
                                      size: CGSize(width: 50, height: 50),
                                      bgColor: UIColor(hex: "#1C2E4A"))
        settingsBtn.position = CGPoint(x: size.width/2 - 45, y: -size.height/2 + 35)
        settingsBtn.zPosition = 25
        settingsBtn.onTap = { [weak self] in self?.showSettings() }
        addChild(settingsBtn)

        let settingsLbl = SKLabelNode(fontNamed: "Courier")
        settingsLbl.text = "SETTINGS"
        settingsLbl.fontSize = 10
        settingsLbl.fontColor = UIColor(hex: "#7799CC")
        settingsLbl.verticalAlignmentMode = .center
        settingsLbl.position = CGPoint(x: size.width/2 - 45, y: -size.height/2 + 12)
        settingsLbl.zPosition = 25
        addChild(settingsLbl)

        // Leaderboard button
        let lbPixels: [[UInt8]] = [
            [0,0,0,1,1,0,0,0],
            [0,0,1,1,1,1,0,0],
            [0,1,1,0,0,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,0,1,1,1,1,0,0],
            [0,0,0,1,1,0,0,0],
            [0,1,1,1,1,1,1,0],
            [0,0,0,0,0,0,0,0],
        ]
        let lbBtn = PixelButton(icon: lbPixels,
                                 iconColor: UIColor(hex: "#FFCC00"),
                                 size: CGSize(width: 50, height: 50),
                                 bgColor: UIColor(hex: "#1C2E4A"))
        lbBtn.position = CGPoint(x: 0, y: -size.height/2 + 35)
        lbBtn.zPosition = 25
        lbBtn.onTap = { [weak self] in self?.showLeaderboard() }
        addChild(lbBtn)

        let lbLbl = SKLabelNode(fontNamed: "Courier")
        lbLbl.text = "RANKS"
        lbLbl.fontSize = 10
        lbLbl.fontColor = UIColor(hex: "#7799CC")
        lbLbl.verticalAlignmentMode = .center
        lbLbl.position = CGPoint(x: 0, y: -size.height/2 + 12)
        lbLbl.zPosition = 25
        addChild(lbLbl)
    }

    // MARK: - Daily Reward

    private func checkDailyReward() {
        if PlayerData.shared.canClaimDailyReward {
            // Slight delay for entrance
            run(.wait(forDuration: 0.8)) { [weak self] in
                // Badge already shown on button
            }
        }
    }

    private func claimDailyReward() {
        let reward = PlayerData.shared.claimDailyReward()
        showRewardPopup(coins: reward.coins, diamonds: reward.diamonds)
    }

    private func showRewardPopup(coins: Int, diamonds: Int) {
        let popup = SKNode()
        popup.zPosition = 100

        let bg = SKShapeNode(rectOf: CGSize(width: 280, height: 220), cornerRadius: 16)
        bg.fillColor = UIColor(hex: "#0D1B2A")
        bg.strokeColor = UIColor(hex: "#FFCC00")
        bg.lineWidth = 3
        popup.addChild(bg)

        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.text = "🎁 DAILY REWARD!"
        title.fontSize = 22
        title.fontColor = UIColor(hex: "#FFCC00")
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 75)
        popup.addChild(title)

        let streakLbl = SKLabelNode(fontNamed: "Courier")
        streakLbl.text = "Day \(PlayerData.shared.dailyStreak) Streak! 🔥"
        streakLbl.fontSize = 16
        streakLbl.fontColor = UIColor(hex: "#FF9500")
        streakLbl.verticalAlignmentMode = .center
        streakLbl.position = CGPoint(x: 0, y: 35)
        popup.addChild(streakLbl)

        let coinsLbl = SKLabelNode(fontNamed: "Courier-Bold")
        coinsLbl.text = "+\(coins) 🪙"
        coinsLbl.fontSize = 28
        coinsLbl.fontColor = UIColor(hex: "#FFCC00")
        coinsLbl.verticalAlignmentMode = .center
        coinsLbl.position = CGPoint(x: diamonds > 0 ? -50 : 0, y: -10)
        popup.addChild(coinsLbl)

        if diamonds > 0 {
            let dLbl = SKLabelNode(fontNamed: "Courier-Bold")
            dLbl.text = "+\(diamonds) 💎"
            dLbl.fontSize = 28
            dLbl.fontColor = UIColor(hex: "#AF52DE")
            dLbl.verticalAlignmentMode = .center
            dLbl.position = CGPoint(x: 50, y: -10)
            popup.addChild(dLbl)
        }

        let closeBtn = PixelButton(title: "CLAIM!", size: CGSize(width: 200, height: 46),
                                   style: .primary, color: UIColor(hex: "#34C759"), fontSize: 20)
        closeBtn.position = CGPoint(x: 0, y: -72)
        closeBtn.onTap = { popup.removeFromParent() }
        popup.addChild(closeBtn)

        // Overlay
        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = UIColor.black.withAlphaComponent(0.5)
        overlay.strokeColor = .clear
        overlay.zPosition = -1
        popup.addChild(overlay)

        addChild(popup)
        popup.popIn(from: 0.2)
        AudioManager.shared.play(.coinCollect)
    }

    // MARK: - Navigation

    private func goToMap() {
        guard let view = view else { return }
        let scene = MapScene(size: size)
        scene.scaleMode = .aspectFill
        view.presentScene(scene, transition: .push(with: .left, duration: 0.4))
    }

    private func showShop() {
        let dialog = ShopDialog(sceneSize: size)
        dialog.zPosition = 50
        addChild(dialog)
        dialog.onClose = { [weak dialog] in dialog?.dismiss() }
    }

    private func showSettings() {
        let dialog = SettingsDialog(sceneSize: size)
        dialog.zPosition = 50
        addChild(dialog)
        dialog.onClose = { [weak dialog] in dialog?.dismiss() }
    }

    private func showLeaderboard() {
        guard let vc = view?.window?.rootViewController else { return }
        if GameCenterManager.shared.isAuthenticated {
            GameCenterManager.shared.showLeaderboard(from: vc)
        } else {
            GameCenterManager.shared.authenticate()
            showFloatingText("Sign in to Game Center to view leaderboards!", color: UIColor(hex: "#FFCC00"))
        }
    }

    private func showFloatingText(_ text: String, color: UIColor) {
        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = text
        lbl.fontSize = 18
        lbl.fontColor = color
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: 0, y: 0)
        lbl.zPosition = 90
        addChild(lbl)
        lbl.run(.sequence([
            .group([.moveBy(x: 0, y: 50, duration: 1.5),
                    .sequence([.fadeIn(withDuration: 0.1), .wait(forDuration: 0.9), .fadeOut(withDuration: 0.5)])]),
            .removeFromParent()
        ]))
    }

    // MARK: - Entrance Animation

    private func animateEntrance() {
        logoNode.setScale(0.0)
        logoNode.alpha = 0
        logoNode.run(.sequence([
            .wait(forDuration: 0.2),
            .group([
                .fadeIn(withDuration: 0.4),
                .scale(to: 1.1, duration: 0.3)
            ]),
            .scale(to: 1.0, duration: 0.1)
        ]))
    }
}

// MARK: - Shop Dialog

final class ShopDialog: DialogNode {
    var onClose: (() -> Void)?

    init(sceneSize: CGSize) {
        super.init(size: CGSize(width: 320, height: 520), sceneSize: sceneSize)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        addPixelTitle("🛒 SHOP", y: 230)

        var yPos: CGFloat = 160

        // Diamond packs
        let packs: [(name: String, diamonds: Int, coins: Int, price: String)] = [
            ("Starter Pack", 20, 200, "Free → Watch Ad"),
            ("Small Pack", 50, 0, "$ 0.99"),
            ("Medium Pack", 120, 0, "$ 1.99"),
            ("Large Pack", 300, 0, "$ 4.99"),
        ]

        for pack in packs {
            addShopItem(name: pack.name, diamonds: pack.diamonds,
                        coins: pack.coins, price: pack.price, y: yPos)
            yPos -= 80
        }

        // Booster section
        yPos -= 20
        let boosterTitle = SKLabelNode(fontNamed: "Courier-Bold")
        boosterTitle.text = "──── BOOSTERS ────"
        boosterTitle.fontSize = 14
        boosterTitle.fontColor = UIColor(hex: "#7799CC")
        boosterTitle.verticalAlignmentMode = .center
        boosterTitle.position = CGPoint(x: 0, y: yPos)
        addChild(boosterTitle)
        yPos -= 60

        for type in BoosterType.allCases {
            addBoosterItem(type: type, y: yPos)
            yPos -= 55
        }

        let closeBtn = PixelButton(title: "CLOSE",
                                   size: CGSize(width: 240, height: 44),
                                   style: .secondary, fontSize: 16)
        closeBtn.position = CGPoint(x: 0, y: yPos - 20)
        closeBtn.onTap = { [weak self] in self?.onClose?() }
        addChild(closeBtn)
    }

    private func addShopItem(name: String, diamonds: Int, coins: Int, price: String, y: CGFloat) {
        let bg = SKShapeNode(rectOf: CGSize(width: 280, height: 64), cornerRadius: 8)
        bg.fillColor = UIColor(hex: "#0F1E33")
        bg.strokeColor = UIColor(hex: "#1C3A5C")
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: 0, y: y)
        addChild(bg)

        let nameLbl = SKLabelNode(fontNamed: "Courier-Bold")
        nameLbl.text = name
        nameLbl.fontSize = 14
        nameLbl.fontColor = .white
        nameLbl.verticalAlignmentMode = .center
        nameLbl.horizontalAlignmentMode = .left
        nameLbl.position = CGPoint(x: -130, y: y + 12)
        addChild(nameLbl)

        let rewardLbl = SKLabelNode(fontNamed: "Courier")
        let rewardText = diamonds > 0 ? "+\(diamonds) 💎" : "" + (coins > 0 ? " +\(coins) 🪙" : "")
        rewardLbl.text = rewardText
        rewardLbl.fontSize = 13
        rewardLbl.fontColor = UIColor(hex: "#AF52DE")
        rewardLbl.verticalAlignmentMode = .center
        rewardLbl.horizontalAlignmentMode = .left
        rewardLbl.position = CGPoint(x: -130, y: y - 12)
        addChild(rewardLbl)

        let buyBtn = PixelButton(title: price,
                                  size: CGSize(width: 110, height: 36),
                                  style: .primary,
                                  color: UIColor(hex: "#FF9500"),
                                  fontSize: 13)
        buyBtn.position = CGPoint(x: 80, y: y)
        buyBtn.onTap = { AudioManager.shared.play(.buttonTap) }
        addChild(buyBtn)
    }

    private func addBoosterItem(type: BoosterType, y: CGFloat) {
        let bg = SKShapeNode(rectOf: CGSize(width: 280, height: 48), cornerRadius: 8)
        bg.fillColor = UIColor(hex: "#0F1E33")
        bg.strokeColor = UIColor(hex: "#1C3A5C")
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: 0, y: y)
        addChild(bg)

        let icon = SKSpriteNode(texture: PixelArt.shared.iconTexture(
            pixels: type.iconPixels, primary: .white, light: UIColor.white.lighter(), dark: .gray, size: 28),
                                size: CGSize(width: 28, height: 28))
        icon.position = CGPoint(x: -120, y: y)
        addChild(icon)

        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = type.name
        lbl.fontSize = 14
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .left
        lbl.position = CGPoint(x: -90, y: y)
        addChild(lbl)

        let buyBtn = PixelButton(title: "\(type.cost) 🪙",
                                  size: CGSize(width: 90, height: 34),
                                  style: .primary,
                                  color: UIColor(hex: "#FFCC00"),
                                  fontSize: 13)
        buyBtn.onTap = { [weak self] in
            if PlayerData.shared.spendCoins(type.cost) {
                switch type {
                case .hammer: PlayerData.shared.hammerCount += 1
                case .shuffle: PlayerData.shared.shuffleCount += 1
                case .extraMoves: PlayerData.shared.extraMovesCount += 1
                case .colorBomb: PlayerData.shared.colorBombCount += 1
                }
                AudioManager.shared.play(.coinCollect)
            }
        }
        buyBtn.position = CGPoint(x: 90, y: y)
        addChild(buyBtn)
    }
}
