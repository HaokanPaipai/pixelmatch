import SpriteKit

final class HomeScene: SKScene {

    private var bgParticles: [SKNode] = []
    private var logoNode: SKNode!
    private var dailyRewardTimer: Timer?
    private var safeAreaInsets: UIEdgeInsets = .zero
    private var safeTopY: CGFloat { size.height / 2 - safeAreaInsets.top }
    private var safeBottomY: CGFloat { -size.height / 2 + safeAreaInsets.bottom }
    private var bottomBarHeight: CGFloat { safeAreaInsets.bottom + 70 }
    private var bottomBarTopY: CGFloat { -size.height / 2 + bottomBarHeight }

    private struct MainButtonLayout {
        let playY: CGFloat
        let dailyY: CGFloat?
        let questY: CGFloat
    }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        size = view.bounds.size
        safeAreaInsets = view.safeAreaInsets
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
        logoNode.position = CGPoint(x: 0, y: min(size.height * 0.16, safeTopY - 195))
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
        let logoBottom = logoNode.position.y - 92
        let playTop = mainButtonLayout().playY + 32
        let availableGap = logoBottom - playTop
        guard availableGap >= 44 else { return }

        let gemY = min(size.height * 0.05, (logoBottom + playTop) / 2)

        for (i, color) in gems.enumerated() {
            let tex = PixelArt.shared.gemTexture(color: color, special: .none)
            let gem = SKSpriteNode(texture: tex, size: CGSize(width: 36, height: 36))
            gem.position = CGPoint(x: -size.width/2 + spacing * CGFloat(i+1),
                                   y: gemY)
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
        let infoY = safeTopY - 72
        let currencyY = infoY - 48
        let heartsY = safeTopY - 24
        let sideInset = safeAreaInsets.left + safeAreaInsets.right
        let infoBar = SKShapeNode(rectOf: CGSize(width: size.width - sideInset - 40, height: 50), cornerRadius: 10)
        infoBar.fillColor = UIColor(hex: "#0D1B2A").withAlphaComponent(0.9)
        infoBar.strokeColor = UIColor(hex: "#1C3A5C")
        infoBar.lineWidth = 1.5
        infoBar.position = CGPoint(x: 0, y: infoY)
        infoBar.zPosition = 6
        addChild(infoBar)

        // Player name
        let nameLbl = SKLabelNode(fontNamed: "Courier-Bold")
        nameLbl.text = PlayerData.shared.playerName
        nameLbl.fontSize = 16
        nameLbl.fontColor = .white
        nameLbl.verticalAlignmentMode = .center
        nameLbl.horizontalAlignmentMode = .left
        nameLbl.position = CGPoint(x: -size.width/2 + safeAreaInsets.left + 36, y: infoY)
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
        lvlLbl.position = CGPoint(x: size.width/2 - safeAreaInsets.right - 36, y: infoY)
        lvlLbl.zPosition = 7
        addChild(lvlLbl)

        // Currency row
        let currencyBar = SKNode()
        currencyBar.position = CGPoint(x: 0, y: currencyY)
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
            h.position = CGPoint(x: -size.width/2 + safeAreaInsets.left + 20 + CGFloat(i) * 22, y: heartsY)
            h.zPosition = 6
            h.alpha = i < lives ? 1.0 : 0.2
            addChild(h)
        }

        addChild(currencyBar)
    }

    // MARK: - Main Buttons

    private func setupMainButtons() {
        LiveOpsManager.shared.refreshDailyQuestsIfNeeded()

        let layout = mainButtonLayout()
        let playY = layout.playY
        let playBtn = PixelButton(title: "▶ PLAY",
                                   size: CGSize(width: 260, height: 64),
                                   style: .primary,
                                   color: UIColor(hex: "#34C759"),
                                   fontSize: 28)
        playBtn.position = CGPoint(x: 0, y: playY)
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
        if let dailyY = layout.dailyY {
            let dailyBtn = PixelButton(title: "🎁 DAILY REWARD!",
                                       size: CGSize(width: 240, height: 50),
                                       style: .primary,
                                       color: UIColor(hex: "#FF9500"),
                                       fontSize: 18)
            dailyBtn.position = CGPoint(x: 0, y: dailyY)
            dailyBtn.zPosition = 10
            dailyBtn.onTap = { [weak self] in self?.claimDailyReward() }
            addChild(dailyBtn)

            dailyBtn.run(.repeatForever(.sequence([
                .scale(to: 1.04, duration: 0.5),
                .scale(to: 1.0, duration: 0.5)
            ])))
        }

        let questY = layout.questY
        let questCount = LiveOpsManager.shared.completedUnclaimedQuestCount
        let questTitle = questCount > 0 ? "✅ QUESTS (\(questCount))" : "📋 QUESTS"
        let questBtn = PixelButton(title: questTitle,
                                   size: CGSize(width: 150, height: 44),
                                   style: .secondary,
                                   color: UIColor(hex: "#34C759"),
                                   fontSize: 15)
        questBtn.position = CGPoint(x: -82, y: questY)
        questBtn.zPosition = 10
        questBtn.onTap = { [weak self] in self?.showQuests() }
        addChild(questBtn)

        let chest = LiveOpsManager.shared.chestProgress
        let chestTitle = LiveOpsManager.shared.canClaimChest
            ? "⭐ CHEST!"
            : "⭐ \(chest.current)/\(chest.target)"
        let chestBtn = PixelButton(title: chestTitle,
                                   size: CGSize(width: 150, height: 44),
                                   style: .secondary,
                                   color: UIColor(hex: "#FFCC00"),
                                   fontSize: 15)
        chestBtn.position = CGPoint(x: 82, y: questY)
        chestBtn.zPosition = 10
        chestBtn.onTap = { [weak self] in self?.showChest() }
        addChild(chestBtn)
    }

    private func setupBottomBar() {
        let barHeight = bottomBarHeight
        let barCenterY = -size.height/2 + barHeight / 2
        let buttonY = safeBottomY + 35
        let labelY = safeBottomY + 12
        let sideInset: CGFloat = 45
        let bar = SKShapeNode(rectOf: CGSize(width: size.width, height: barHeight))
        bar.fillColor = UIColor(hex: "#0A1628").withAlphaComponent(0.95)
        bar.strokeColor = UIColor(hex: "#1C3A5C")
        bar.lineWidth = 1.5
        bar.position = CGPoint(x: 0, y: barCenterY)
        bar.zPosition = 20
        addChild(bar)

        // Shop button
        let shopBtn = PixelButton(icon: PixelIcons.coin,
                                   iconColor: UIColor(hex: "#FFCC00"),
                                   size: CGSize(width: 50, height: 50),
                                   bgColor: UIColor(hex: "#1C2E4A"))
        shopBtn.position = CGPoint(x: -size.width/2 + safeAreaInsets.left + sideInset, y: buttonY)
        shopBtn.zPosition = 25
        shopBtn.onTap = { [weak self] in self?.showShop() }
        addChild(shopBtn)

        let shopLbl = SKLabelNode(fontNamed: "Courier")
        shopLbl.text = "SHOP"
        shopLbl.fontSize = 10
        shopLbl.fontColor = UIColor(hex: "#7799CC")
        shopLbl.verticalAlignmentMode = .center
        shopLbl.position = CGPoint(x: -size.width/2 + safeAreaInsets.left + sideInset, y: labelY)
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
        settingsBtn.position = CGPoint(x: size.width/2 - safeAreaInsets.right - sideInset, y: buttonY)
        settingsBtn.zPosition = 25
        settingsBtn.onTap = { [weak self] in self?.showSettings() }
        addChild(settingsBtn)

        let settingsLbl = SKLabelNode(fontNamed: "Courier")
        settingsLbl.text = "SETTINGS"
        settingsLbl.fontSize = 10
        settingsLbl.fontColor = UIColor(hex: "#7799CC")
        settingsLbl.verticalAlignmentMode = .center
        settingsLbl.position = CGPoint(x: size.width/2 - safeAreaInsets.right - sideInset, y: labelY)
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
        lbBtn.position = CGPoint(x: 0, y: buttonY)
        lbBtn.zPosition = 25
        lbBtn.onTap = { [weak self] in self?.showLeaderboard() }
        addChild(lbBtn)

        let lbLbl = SKLabelNode(fontNamed: "Courier")
        lbLbl.text = "RANKS"
        lbLbl.fontSize = 10
        lbLbl.fontColor = UIColor(hex: "#7799CC")
        lbLbl.verticalAlignmentMode = .center
        lbLbl.position = CGPoint(x: 0, y: labelY)
        lbLbl.zPosition = 25
        addChild(lbLbl)
    }

    private func mainButtonLayout() -> MainButtonLayout {
        // 主按钮区从底部工具栏往上排，再与 Logo 底部做碰撞限制。
        // 小屏时优先保证按钮不进入安全区和底栏，大屏时保持原来的视觉中心。
        let hasDailyReward = PlayerData.shared.canClaimDailyReward
        let preferredPlayY = max(safeBottomY + 180, -size.height * 0.12)
        let minPlayY = bottomBarTopY + (hasDailyReward ? 164 : 106)
        let logoBottom = (logoNode?.position.y ?? safeTopY - 195) - 92
        let maxPlayY = logoBottom - 40
        let playY = min(max(preferredPlayY, minPlayY), maxPlayY)

        if hasDailyReward {
            let dailyY = playY - 69
            return MainButtonLayout(playY: playY,
                                    dailyY: dailyY,
                                    questY: dailyY - 59)
        }
        return MainButtonLayout(playY: playY,
                                dailyY: nil,
                                questY: playY - 70)
    }

    // MARK: - Daily Reward

    private func checkDailyReward() {
        if PlayerData.shared.canClaimDailyReward {
            // Slight delay for entrance
            run(.wait(forDuration: 0.8)) {
                // Badge already shown on button
            }
        }
    }

    private func claimDailyReward() {
        let reward = PlayerData.shared.claimDailyReward()
        showRewardPopup(title: "🎁 DAILY REWARD!",
                        coins: reward.coins,
                        diamonds: reward.diamonds)
    }

    private func showRewardPopup(title: String,
                                 coins: Int,
                                 diamonds: Int,
                                 hammer: Int = 0,
                                 shuffle: Int = 0) {
        let popup = SKNode()
        popup.zPosition = 100

        let bg = SKShapeNode(rectOf: CGSize(width: 280, height: 220), cornerRadius: 16)
        bg.fillColor = UIColor(hex: "#0D1B2A")
        bg.strokeColor = UIColor(hex: "#FFCC00")
        bg.lineWidth = 3
        popup.addChild(bg)

        let titleLbl = SKLabelNode(fontNamed: "Courier-Bold")
        titleLbl.text = title
        titleLbl.fontSize = 22
        titleLbl.fontColor = UIColor(hex: "#FFCC00")
        titleLbl.verticalAlignmentMode = .center
        titleLbl.position = CGPoint(x: 0, y: 75)
        popup.addChild(titleLbl)

        let streakLbl = SKLabelNode(fontNamed: "Courier")
        streakLbl.text = title.contains("DAILY")
            ? "Day \(PlayerData.shared.dailyStreak) Streak!"
            : "Rewards added to your inventory"
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

        if hammer > 0 || shuffle > 0 {
            let boosterLbl = SKLabelNode(fontNamed: "Courier-Bold")
            boosterLbl.text = "+\(hammer) Hammer  +\(shuffle) Shuffle"
            boosterLbl.fontSize = 14
            boosterLbl.fontColor = UIColor(hex: "#99BBCC")
            boosterLbl.verticalAlignmentMode = .center
            boosterLbl.position = CGPoint(x: 0, y: -42)
            popup.addChild(boosterLbl)
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
        let dialog = ShopDialog(sceneSize: size, safeAreaInsets: safeAreaInsets)
        dialog.zPosition = 50
        addChild(dialog)
        dialog.onClose = { [weak dialog] in dialog?.dismiss() }
    }

    private func showQuests() {
        let dialog = QuestsDialog(sceneSize: size)
        dialog.zPosition = 50
        addChild(dialog)
        dialog.onClose = { [weak dialog] in dialog?.dismiss() }
        dialog.onClaim = { [weak self, weak dialog] questId in
            guard let reward = LiveOpsManager.shared.claimQuest(id: questId) else { return }
            dialog?.dismiss()
            self?.showRewardPopup(title: "✅ QUEST COMPLETE!",
                                  coins: reward.coins,
                                  diamonds: reward.diamonds)
        }
    }

    private func showChest() {
        guard let reward = LiveOpsManager.shared.claimChest() else {
            let chest = LiveOpsManager.shared.chestProgress
            showFloatingText("Collect stars to open chest: \(chest.current)/\(chest.target)",
                             color: UIColor(hex: "#FFCC00"))
            return
        }
        showRewardPopup(title: "⭐ STAR CHEST!",
                        coins: reward.coins,
                        diamonds: reward.diamonds,
                        hammer: reward.hammer,
                        shuffle: reward.shuffle)
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

// MARK: - Quests Dialog

final class QuestsDialog: DialogNode {
    var onClose: (() -> Void)?
    var onClaim: ((String) -> Void)?

    private let dialogSize: CGSize

    init(sceneSize: CGSize) {
        dialogSize = CGSize(width: min(sceneSize.width - 36, 330), height: 360)
        super.init(size: dialogSize, sceneSize: sceneSize)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        addPixelTitle("DAILY QUESTS", y: 145)

        let quests = LiveOpsManager.shared.quests
        for (index, quest) in quests.enumerated() {
            addQuestRow(quest, y: 78 - CGFloat(index) * 78)
        }

        let closeBtn = PixelButton(title: "CLOSE",
                                   size: CGSize(width: 220, height: 44),
                                   style: .secondary,
                                   fontSize: 16)
        closeBtn.position = CGPoint(x: 0, y: -145)
        closeBtn.onTap = { [weak self] in self?.onClose?() }
        addChild(closeBtn)
    }

    private func addQuestRow(_ quest: DailyQuest, y: CGFloat) {
        let rowWidth = dialogSize.width - 28
        let claimWidth: CGFloat = min(84, max(72, rowWidth * 0.30))
        let textLeft = -rowWidth / 2 + 12
        let claimX = rowWidth / 2 - claimWidth / 2 - 10
        let maxTextWidth = rowWidth - claimWidth - 34

        let bg = SKShapeNode(rectOf: CGSize(width: rowWidth, height: 60), cornerRadius: 8)
        bg.fillColor = UIColor(hex: "#0F1E33")
        bg.strokeColor = quest.isComplete ? UIColor(hex: "#34C759") : UIColor(hex: "#1C3A5C")
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: 0, y: y)
        addChild(bg)

        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.text = quest.displayText
        title.fontSize = 13
        title.fontColor = .white
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: textLeft, y: y + 10)
        fitLabel(title, maxWidth: maxTextWidth)
        addChild(title)

        let reward = SKLabelNode(fontNamed: "Courier")
        reward.text = "+\(EconomyConfig.shared.questRewardCoins) coins  +\(EconomyConfig.shared.questRewardDiamonds) diamond"
        reward.fontSize = 11
        reward.fontColor = UIColor(hex: "#99BBCC")
        reward.verticalAlignmentMode = .center
        reward.horizontalAlignmentMode = .left
        reward.position = CGPoint(x: textLeft, y: y - 13)
        fitLabel(reward, maxWidth: maxTextWidth, minScale: 0.72)
        addChild(reward)

        let claimTitle: String
        if quest.claimed {
            claimTitle = "DONE"
        } else if quest.isComplete {
            claimTitle = "CLAIM"
        } else {
            claimTitle = "..."
        }

        let claimBtn = PixelButton(title: claimTitle,
                                   size: CGSize(width: claimWidth, height: 34),
                                   style: quest.isComplete && !quest.claimed ? .primary : .secondary,
                                   color: UIColor(hex: "#34C759"),
                                   fontSize: 12)
        claimBtn.position = CGPoint(x: claimX, y: y)
        claimBtn.onTap = { [weak self] in
            guard quest.isComplete && !quest.claimed else { return }
            self?.onClaim?(quest.id)
        }
        addChild(claimBtn)
    }

    private func fitLabel(_ label: SKLabelNode, maxWidth: CGFloat, minScale: CGFloat = 0.68) {
        // 任务文案和奖励文字在小屏上不能挤进领取按钮。
        label.setScale(1)
        let width = max(label.frame.width, 1)
        if width > maxWidth {
            label.setScale(max(minScale, maxWidth / width))
        }
    }
}

// MARK: - Shop Dialog

final class ShopDialog: DialogNode {
    var onClose: (() -> Void)?

    private let dialogSize: CGSize
    private let viewportHeight: CGFloat
    private let viewportTop: CGFloat
    private let viewportBottom: CGFloat
    private let scrollNode = SKNode()
    private var contentHeight: CGFloat = 0
    private var touchStartY: CGFloat = 0
    private var scrollStartY: CGFloat = 0
    private var isTrackingScroll = false
    private var didDrag = false

    init(sceneSize: CGSize, safeAreaInsets: UIEdgeInsets) {
        let width = min(sceneSize.width - safeAreaInsets.left - safeAreaInsets.right - 32, 320)
        let height = min(sceneSize.height - safeAreaInsets.top - safeAreaInsets.bottom - 40, 520)
        dialogSize = CGSize(width: width, height: height)
        viewportTop = height / 2 - 66
        viewportBottom = -height / 2 + 78
        viewportHeight = viewportTop - viewportBottom

        super.init(size: dialogSize, sceneSize: sceneSize)
        isUserInteractionEnabled = true
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        addPixelTitle("🛒 SHOP", y: dialogSize.height / 2 - 34)

        let closeBtn = PixelButton(title: "CLOSE",
                                   size: CGSize(width: 240, height: 44),
                                   style: .secondary, fontSize: 16)
        closeBtn.position = CGPoint(x: 0, y: -dialogSize.height / 2 + 38)
        closeBtn.zPosition = 20
        closeBtn.onTap = { [weak self] in self?.onClose?() }
        addChild(closeBtn)

        let clip = SKCropNode()
        let mask = SKShapeNode(rectOf: CGSize(width: dialogSize.width - 24, height: viewportHeight), cornerRadius: 8)
        mask.fillColor = .white
        mask.position = CGPoint(x: 0, y: (viewportTop + viewportBottom) / 2)
        clip.maskNode = mask
        clip.zPosition = 1
        addChild(clip)

        scrollNode.position = CGPoint(x: 0, y: viewportTop)
        clip.addChild(scrollNode)

        var yPos: CGFloat = -36

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
        scrollNode.addChild(boosterTitle)
        yPos -= 60

        for type in BoosterType.allCases {
            addBoosterItem(type: type, y: yPos)
            yPos -= 55
        }

        contentHeight = abs(yPos) + 24
    }

    private func addShopItem(name: String, diamonds: Int, coins: Int, price: String, y: CGFloat) {
        let bg = SKShapeNode(rectOf: CGSize(width: dialogSize.width - 40, height: 64), cornerRadius: 8)
        bg.fillColor = UIColor(hex: "#0F1E33")
        bg.strokeColor = UIColor(hex: "#1C3A5C")
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: 0, y: y)
        scrollNode.addChild(bg)

        let nameLbl = SKLabelNode(fontNamed: "Courier-Bold")
        nameLbl.text = name
        nameLbl.fontSize = 14
        nameLbl.fontColor = .white
        nameLbl.verticalAlignmentMode = .center
        nameLbl.horizontalAlignmentMode = .left
        nameLbl.position = CGPoint(x: -dialogSize.width / 2 + 34, y: y + 12)
        scrollNode.addChild(nameLbl)

        let rewardLbl = SKLabelNode(fontNamed: "Courier")
        let rewardText = diamonds > 0 ? "+\(diamonds) 💎" : "" + (coins > 0 ? " +\(coins) 🪙" : "")
        rewardLbl.text = rewardText
        rewardLbl.fontSize = 13
        rewardLbl.fontColor = UIColor(hex: "#AF52DE")
        rewardLbl.verticalAlignmentMode = .center
        rewardLbl.horizontalAlignmentMode = .left
        rewardLbl.position = CGPoint(x: -dialogSize.width / 2 + 34, y: y - 12)
        scrollNode.addChild(rewardLbl)

        let buyBtn = PixelButton(title: price,
                                  size: CGSize(width: 110, height: 36),
                                  style: .primary,
                                  color: UIColor(hex: "#FF9500"),
                                  fontSize: 13)
        buyBtn.position = CGPoint(x: dialogSize.width / 2 - 78, y: y)
        buyBtn.onTap = { AudioManager.shared.play(.buttonTap) }
        scrollNode.addChild(buyBtn)
    }

    private func addBoosterItem(type: BoosterType, y: CGFloat) {
        let bg = SKShapeNode(rectOf: CGSize(width: dialogSize.width - 40, height: 48), cornerRadius: 8)
        bg.fillColor = UIColor(hex: "#0F1E33")
        bg.strokeColor = UIColor(hex: "#1C3A5C")
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: 0, y: y)
        scrollNode.addChild(bg)

        let icon = SKSpriteNode(texture: PixelArt.shared.iconTexture(
            pixels: type.iconPixels, primary: .white, light: UIColor.white.lighter(), dark: .gray, size: 28),
                                size: CGSize(width: 28, height: 28))
        icon.position = CGPoint(x: -dialogSize.width / 2 + 40, y: y)
        scrollNode.addChild(icon)

        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = type.name
        lbl.fontSize = 14
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .left
        lbl.position = CGPoint(x: -dialogSize.width / 2 + 70, y: y)
        scrollNode.addChild(lbl)

        let buyBtn = PixelButton(title: "\(type.cost) 🪙",
                                  size: CGSize(width: 90, height: 34),
                                  style: .primary,
                                  color: UIColor(hex: "#FFCC00"),
                                  fontSize: 13)
        buyBtn.onTap = {
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
        buyBtn.position = CGPoint(x: dialogSize.width / 2 - 70, y: y)
        scrollNode.addChild(buyBtn)
    }

    private func clampScrollY(_ y: CGFloat) -> CGFloat {
        let minY = viewportTop
        let maxY = max(minY, viewportBottom + contentHeight)
        return max(minY, min(maxY, y))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        isTrackingScroll = abs(loc.x) <= dialogSize.width / 2 - 12
            && loc.y <= viewportTop
            && loc.y >= viewportBottom
        didDrag = false
        touchStartY = loc.y
        scrollStartY = scrollNode.position.y
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isTrackingScroll, let touch = touches.first else { return }
        let currentY = touch.location(in: self).y
        if abs(currentY - touchStartY) > 4 { didDrag = true }
        scrollNode.position.y = clampScrollY(scrollStartY + currentY - touchStartY)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            isTrackingScroll = false
            didDrag = false
        }
        guard !didDrag, let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let closeY = -dialogSize.height / 2 + 38
        if abs(loc.x) <= 120 && abs(loc.y - closeY) <= 26 {
            onClose?()
        }
    }
}
