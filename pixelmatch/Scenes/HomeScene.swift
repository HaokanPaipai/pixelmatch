import SpriteKit

final class HomeScene: SKScene {

    private var bgParticles: [SKNode] = []
    private var logoNode: SKNode!
    private var dailyRewardTimer: Timer?
    private var safeAreaInsets: UIEdgeInsets = .zero
    private var safeTopY: CGFloat { size.height / 2 - safeAreaInsets.top }
    private var safeBottomY: CGFloat { -size.height / 2 + safeAreaInsets.bottom }
    private var playButtonY: CGFloat { max(safeBottomY + 180, -size.height * 0.12) }

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
        let reducedMotion = VisualComfort.isReducedMotionEnabled

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
            if !reducedMotion {
                dot.run(.repeatForever(.sequence([
                    .fadeAlpha(to: CGFloat.random(in: 0.05...0.3), duration: Double.random(in: 0.8...3)),
                    .fadeAlpha(to: 0.9, duration: Double.random(in: 0.8...3))
                ])))
            }
        }

        // Floating pixel squares
        for i in 0..<(reducedMotion ? 8 : 12) {
            let sqSize = CGFloat.random(in: 6...20)
            let color = GemColor(rawValue: i % 6)!.primary.withAlphaComponent(reducedMotion ? 0.10 : 0.15)
            let sq = SKShapeNode(rectOf: CGSize(width: sqSize, height: sqSize))
            sq.fillColor = color
            sq.strokeColor = color.withAlphaComponent(0.3)
            sq.lineWidth = 1
            sq.position = CGPoint(x: CGFloat.random(in: -size.width/2...size.width/2),
                                  y: CGFloat.random(in: -size.height/2...size.height/2))
            sq.zPosition = -8
            addChild(sq)
            bgParticles.append(sq)

            guard !reducedMotion else { continue }
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

        // 像素风品牌标题。
        let titleLbl = SKLabelNode(fontNamed: "Courier-Bold")
        titleLbl.text = L10n.tr("home.logo.pixel", fallback: "PIXEL")
        titleLbl.fontSize = 52
        titleLbl.fontColor = UIColor(hex: "#FFCC00")
        titleLbl.verticalAlignmentMode = .center
        titleLbl.position = CGPoint(x: 0, y: 28)
        logoNode.addChild(titleLbl)

        let subtitleLbl = SKLabelNode(fontNamed: "Courier-Bold")
        subtitleLbl.text = L10n.tr("home.logo.match", fallback: "MATCH")
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

            if !VisualComfort.isReducedMotionEnabled {
                dot.run(.repeatForever(.sequence([
                    .wait(forDuration: Double(i) * 0.12),
                    .scale(to: 1.4, duration: 0.2),
                    .scale(to: 1.0, duration: 0.2),
                    .wait(forDuration: 0.8)
                ])))
            }
        }

        // Tagline
        let tagLbl = SKLabelNode(fontNamed: "Courier")
        tagLbl.text = L10n.tr("home.tagline", fallback: "The Ultimate Pixel Puzzle")
        tagLbl.fontSize = 14
        tagLbl.fontColor = UIColor(hex: "#7799CC")
        tagLbl.verticalAlignmentMode = .center
        tagLbl.position = CGPoint(x: 0, y: -82)
        logoNode.addChild(tagLbl)

        // Subtle logo float
        if !VisualComfort.isReducedMotionEnabled {
            logoNode.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 6, duration: 2.0),
                .moveBy(x: 0, y: -6, duration: 2.0)
            ])))
        }
    }

    // MARK: - Gems Decoration

    private func setupPixelGems() {
        let gems: [GemColor] = [.red, .blue, .green, .yellow, .purple, .orange]
        let spacing = size.width / CGFloat(gems.count + 1)
        let logoBottom = logoNode.position.y - 92
        let playTop = playButtonY + 36
        let gemY = min(size.height * 0.05, (logoBottom + playTop) / 2)

        for (i, color) in gems.enumerated() {
            let tex = PixelArt.shared.gemTexture(color: color, special: .none)
            let gem = SKSpriteNode(texture: tex, size: CGSize(width: 36, height: 36))
            gem.position = CGPoint(x: -size.width/2 + spacing * CGFloat(i+1),
                                   y: gemY)
            gem.zPosition = 3
            addChild(gem)

            let delay = Double(i) * 0.1
            if !VisualComfort.isReducedMotionEnabled {
                gem.run(.repeatForever(.sequence([
                    .wait(forDuration: delay),
                    .scale(to: 1.2, duration: 0.3),
                    .scale(to: 0.9, duration: 0.3),
                    .scale(to: 1.0, duration: 0.2),
                    .wait(forDuration: 1.5)
                ])))
            }
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
        lvlLbl.text = L10n.fmt("home.level", maxLvl, fallback: "Level %d")
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
        let coinTex = PixelArt.shared.softIconTexture(.coin, size: 24)
        let coinIcon = SKSpriteNode(texture: coinTex, size: CGSize(width: 22, height: 22))
        coinIcon.position = CGPoint(x: -80, y: 0)
        currencyBar.addChild(coinIcon)

        let coinsLbl = SKLabelNode(fontNamed: "Courier-Bold")
        coinsLbl.name = "home.coins"
        coinsLbl.text = "\(PlayerData.shared.coins)"
        coinsLbl.fontSize = 16
        coinsLbl.fontColor = UIColor(hex: "#FFCC00")
        coinsLbl.verticalAlignmentMode = .center
        coinsLbl.horizontalAlignmentMode = .left
        coinsLbl.position = CGPoint(x: -66, y: 0)
        currencyBar.addChild(coinsLbl)

        // Diamonds
        let dTex = PixelArt.shared.softIconTexture(.diamond, size: 24)
        let dIcon = SKSpriteNode(texture: dTex, size: CGSize(width: 22, height: 22))
        dIcon.position = CGPoint(x: 40, y: 0)
        currencyBar.addChild(dIcon)

        let diamondsLbl = SKLabelNode(fontNamed: "Courier-Bold")
        diamondsLbl.name = "home.diamonds"
        diamondsLbl.text = "\(PlayerData.shared.diamonds)"
        diamondsLbl.fontSize = 16
        diamondsLbl.fontColor = UIColor(hex: "#AF52DE")
        diamondsLbl.verticalAlignmentMode = .center
        diamondsLbl.horizontalAlignmentMode = .left
        diamondsLbl.position = CGPoint(x: 54, y: 0)
        currencyBar.addChild(diamondsLbl)

        // Hearts
        let lives = LivesManager.shared.currentLives
        for i in 0..<GameConstants.maxLives {
            let filled = i < lives
            let heartTex = PixelArt.shared.heartBadgeTexture(filled: filled, size: 22)
            let h = SKSpriteNode(texture: heartTex, size: CGSize(width: 19, height: 19))
            h.position = CGPoint(x: -size.width/2 + safeAreaInsets.left + 20 + CGFloat(i) * 22, y: heartsY)
            h.zPosition = 6
            h.alpha = filled ? 1.0 : 0.72
            addChild(h)
        }

        addChild(currencyBar)
    }

    // MARK: - Main Buttons

    private func setupMainButtons() {
        LiveOpsManager.shared.refreshDailyQuestsIfNeeded()

        let playY = playButtonY
        let playBtn = PixelButton(title: L10n.tr("home.play", fallback: "▶ PLAY"),
                                   icon: .play,
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
        if PlayerData.shared.canClaimDailyReward {
            let dailyBtn = PixelButton(title: L10n.tr("home.daily_reward", fallback: "🎁 DAILY REWARD!"),
                                       icon: .gift,
                                       size: CGSize(width: 240, height: 50),
                                       style: .primary,
                                       color: UIColor(hex: "#FF9500"),
                                       fontSize: 18)
            dailyBtn.position = CGPoint(x: 0, y: playY - 78)
            dailyBtn.zPosition = 10
            dailyBtn.onTap = { [weak self, weak dailyBtn] in self?.claimDailyReward(button: dailyBtn) }
            addChild(dailyBtn)

            dailyBtn.run(.repeatForever(.sequence([
                .scale(to: 1.04, duration: 0.5),
                .scale(to: 1.0, duration: 0.5)
            ])))
        }

        let questY = playY - (PlayerData.shared.canClaimDailyReward ? 140 : 78)
        let questCount = LiveOpsManager.shared.completedUnclaimedQuestCount
        let questTitle = questCount > 0
            ? L10n.fmt("home.quests_count", questCount, fallback: "✅ QUESTS (%d)")
            : L10n.tr("home.quests", fallback: "📋 QUESTS")
        let questBtn = PixelButton(title: questTitle,
                                   icon: questCount > 0 ? .check : .quest,
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
            ? L10n.tr("home.chest_ready", fallback: "⭐ CHEST!")
            : L10n.fmt("home.chest_progress", chest.current, chest.target, fallback: "⭐ %d/%d")
        let chestBtn = PixelButton(title: chestTitle,
                                   icon: .chest,
                                   size: CGSize(width: 150, height: 44),
                                   style: .secondary,
                                   color: UIColor(hex: "#FFCC00"),
                                   fontSize: 15)
        chestBtn.position = CGPoint(x: 82, y: questY)
        chestBtn.zPosition = 10
        chestBtn.onTap = { [weak self] in self?.showChest() }
        addChild(chestBtn)

        // 赛季通行证 + 每周挑战（一行两钮，挂在任务行下方）
        let passRowY = questY - 52
        let pass = SeasonPassManager.shared
        let passTitle = pass.claimableCount > 0
            ? L10n.tr("pass.title", fallback: "SEASON PASS") + " (\(pass.claimableCount))"
            : L10n.tr("pass.title", fallback: "SEASON PASS")
        let passBtn = PixelButton(title: "🎫 " + passTitle,
                                  icon: .gift,
                                  size: CGSize(width: 150, height: 44),
                                  style: .secondary,
                                  color: UIColor(hex: "#FFD700"),
                                  fontSize: 12)
        passBtn.position = CGPoint(x: -82, y: passRowY)
        passBtn.zPosition = 10
        passBtn.onTap = { [weak self] in self?.showSeasonPass() }
        addChild(passBtn)
        if pass.claimableCount > 0 {
            passBtn.run(.repeatForever(.sequence([
                .scale(to: 1.04, duration: 0.5),
                .scale(to: 1.0, duration: 0.5)
            ])))
        }

        let weekly = LiveEventManager.shared
        let weeklyTitle = weekly.isWeeklyComplete && !weekly.isWeeklyClaimed
            ? L10n.tr("weekly.done", fallback: "COMPLETED!")
            : "\(weekly.weeklyProgress)/\(weekly.weeklyChallenge().target)"
        let weeklyBtn = PixelButton(title: "🏆 " + weeklyTitle,
                                    icon: .leaderboard,
                                    size: CGSize(width: 150, height: 44),
                                    style: .secondary,
                                    color: UIColor(hex: "#5AC8FA"),
                                    fontSize: 12)
        weeklyBtn.position = CGPoint(x: 82, y: passRowY)
        weeklyBtn.zPosition = 10
        weeklyBtn.onTap = { [weak self] in self?.showWeeklyChallenge() }
        addChild(weeklyBtn)
    }

    // MARK: - Season Pass & Weekly Challenge

    private func showSeasonPass() {
        AudioManager.shared.play(.buttonTap)
        let dialog = SeasonPassDialog(sceneSize: size)
        dialog.zPosition = 100
        addChild(dialog)
        dialog.onClose = { [weak dialog] in dialog?.dismiss() }
        dialog.onUnlockPremium = { [weak self, weak dialog] in
            guard let self = self else { return }
            IAPManager.shared.purchase(.seasonPass) { [weak self] success, message in
                DispatchQueue.main.async {
                    if success {
                        dialog?.dismiss()
                        self?.showSeasonPass()   // 重开刷新付费轨状态
                    } else if let message = message {
                        self?.showFloatingText(message, color: UIColor(hex: "#FF3B30"))
                    }
                }
            }
        }
    }

    private func showWeeklyChallenge() {
        AudioManager.shared.play(.buttonTap)
        let weekly = LiveEventManager.shared
        let challenge = weekly.weeklyChallenge()

        if weekly.isWeeklyComplete && !weekly.isWeeklyClaimed {
            if let reward = weekly.claimWeeklyReward() {
                HapticsManager.shared.win()
                AudioManager.shared.play(.coinCollect)
                showRewardPopup(title: "🏆 " + L10n.tr("weekly.done", fallback: "COMPLETED!"),
                                coins: reward.coins,
                                diamonds: reward.diamonds)
            }
            return
        }

        // 未完成：浮层展示挑战详情与剩余时间
        let status = weekly.isWeeklyClaimed
            ? L10n.tr("weekly.done", fallback: "COMPLETED!")
            : "\(challenge.kind.title): \(weekly.weeklyProgress)/\(challenge.target)"
        let timeLeft = L10n.fmt("weekly.time_left", weekly.weeklyTimeLeftString, fallback: "%@ left")
        showFloatingText("🏆 \(L10n.tr("weekly.title", fallback: "WEEKLY CHALLENGE"))\n\(status) · \(timeLeft)",
                         color: UIColor(hex: "#5AC8FA"))
    }

    private func setupBottomBar() {
        let barHeight = safeAreaInsets.bottom + 70
        let barCenterY = -size.height/2 + barHeight / 2
        let buttonY = safeBottomY + 35
        let labelY = safeBottomY + 12
        let sideInset: CGFloat = 38
        let itemXs = [
            -size.width/2 + safeAreaInsets.left + sideInset,
            -size.width * 0.16,
            size.width * 0.16,
            size.width/2 - safeAreaInsets.right - sideInset
        ]
        let bar = SKShapeNode(rectOf: CGSize(width: size.width, height: barHeight))
        bar.fillColor = UIColor(hex: "#0A1628").withAlphaComponent(0.95)
        bar.strokeColor = UIColor(hex: "#1C3A5C")
        bar.lineWidth = 1.5
        bar.position = CGPoint(x: 0, y: barCenterY)
        bar.zPosition = 20
        addChild(bar)

        // Shop button
        let shopBtn = PixelButton(icon: .coin,
                                   size: CGSize(width: 50, height: 50),
                                   bgColor: UIColor(hex: "#1C2E4A"))
        shopBtn.position = CGPoint(x: itemXs[0], y: buttonY)
        shopBtn.zPosition = 25
        shopBtn.onTap = { [weak self] in self?.showShop() }
        addChild(shopBtn)

        let shopLbl = SKLabelNode(fontNamed: "Courier")
        shopLbl.text = L10n.tr("home.shop", fallback: "SHOP")
        shopLbl.fontSize = 10
        shopLbl.fontColor = UIColor(hex: "#7799CC")
        shopLbl.verticalAlignmentMode = .center
        shopLbl.position = CGPoint(x: itemXs[0], y: labelY)
        shopLbl.zPosition = 25
        addChild(shopLbl)

        // Pixel album button
        let albumBtn = PixelButton(icon: .album,
                                   size: CGSize(width: 50, height: 50),
                                   bgColor: UIColor(hex: "#1C2E4A"))
        albumBtn.position = CGPoint(x: itemXs[1], y: buttonY)
        albumBtn.zPosition = 25
        albumBtn.onTap = { [weak self] in self?.showPixelAlbum() }
        addChild(albumBtn)

        let albumLbl = SKLabelNode(fontNamed: "Courier")
        albumLbl.text = L10n.tr("home.album", fallback: "ALBUM")
        albumLbl.fontSize = 10
        albumLbl.fontColor = UIColor(hex: "#7799CC")
        albumLbl.verticalAlignmentMode = .center
        albumLbl.position = CGPoint(x: itemXs[1], y: labelY)
        albumLbl.zPosition = 25
        addChild(albumLbl)

        // Settings button
        let settingsBtn = PixelButton(icon: .settings,
                                      size: CGSize(width: 50, height: 50),
                                      bgColor: UIColor(hex: "#1C2E4A"))
        settingsBtn.position = CGPoint(x: itemXs[3], y: buttonY)
        settingsBtn.zPosition = 25
        settingsBtn.onTap = { [weak self] in self?.showSettings() }
        addChild(settingsBtn)

        let settingsLbl = SKLabelNode(fontNamed: "Courier")
        settingsLbl.text = L10n.tr("home.settings", fallback: "SETTINGS")
        settingsLbl.fontSize = 10
        settingsLbl.fontColor = UIColor(hex: "#7799CC")
        settingsLbl.verticalAlignmentMode = .center
        settingsLbl.position = CGPoint(x: itemXs[3], y: labelY)
        settingsLbl.zPosition = 25
        addChild(settingsLbl)

        // Leaderboard button
        let lbBtn = PixelButton(icon: .leaderboard,
                                 size: CGSize(width: 50, height: 50),
                                 bgColor: UIColor(hex: "#1C2E4A"))
        lbBtn.position = CGPoint(x: itemXs[2], y: buttonY)
        lbBtn.zPosition = 25
        lbBtn.onTap = { [weak self] in self?.showLeaderboard() }
        addChild(lbBtn)

        let lbLbl = SKLabelNode(fontNamed: "Courier")
        lbLbl.text = L10n.tr("home.ranks", fallback: "RANKS")
        lbLbl.fontSize = 10
        lbLbl.fontColor = UIColor(hex: "#7799CC")
        lbLbl.verticalAlignmentMode = .center
        lbLbl.position = CGPoint(x: itemXs[2], y: labelY)
        lbLbl.zPosition = 25
        addChild(lbLbl)
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

    private func claimDailyReward(button: PixelButton? = nil) {
        guard let reward = PlayerData.shared.claimDailyReward() else {
            button?.setEnabled(false)
            button?.removeFromParent()
            return
        }

        button?.onTap = nil
        button?.setEnabled(false)
        button?.removeAllActions()
        button?.run(.sequence([
            .fadeOut(withDuration: 0.18),
            .removeFromParent()
        ]))

        showRewardPopup(title: L10n.tr("home.daily_reward", fallback: "🎁 DAILY REWARD!"),
                        coins: reward.coins,
                        diamonds: reward.diamonds,
                        isDailyReward: true)
    }

    private func showRewardPopup(title: String,
                                 coins: Int,
                                 diamonds: Int,
                                 hammer: Int = 0,
                                 shuffle: Int = 0,
                                 isDailyReward: Bool = false) {
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
        streakLbl.text = isDailyReward
            ? L10n.fmt("home.daily_streak", PlayerData.shared.dailyStreak, fallback: "Day %d Streak!")
            : L10n.tr("home.reward_inventory", fallback: "Rewards added to your inventory")
        streakLbl.fontSize = 16
        streakLbl.fontColor = UIColor(hex: "#FF9500")
        streakLbl.verticalAlignmentMode = .center
        streakLbl.position = CGPoint(x: 0, y: 35)
        popup.addChild(streakLbl)

        let rewardItems = [
            coins > 0 ? CurrencyAmountItem(.coins, coins) : nil,
            diamonds > 0 ? CurrencyAmountItem(.diamonds, diamonds) : nil
        ].compactMap { $0 }
        if !rewardItems.isEmpty {
            let rewardNode = CurrencyAmountsNode(items: rewardItems,
                                                 amountPrefix: "+",
                                                 fontSize: 28,
                                                 iconSize: 24,
                                                 spacing: 20)
            rewardNode.position = CGPoint(x: 0, y: -10)
            popup.addChild(rewardNode)
        }

        if hammer > 0 || shuffle > 0 {
            let boosterLbl = SKLabelNode(fontNamed: "Courier-Bold")
            boosterLbl.text = L10n.fmt("home.booster_reward", hammer, shuffle, fallback: "+%d Hammer  +%d Shuffle")
            boosterLbl.fontSize = 14
            boosterLbl.fontColor = UIColor(hex: "#99BBCC")
            boosterLbl.verticalAlignmentMode = .center
            boosterLbl.position = CGPoint(x: 0, y: -42)
            popup.addChild(boosterLbl)
        }

        let closeBtn = PixelButton(title: L10n.tr("home.claim", fallback: "CLAIM!"), size: CGSize(width: 200, height: 46),
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
        let dialog = ShopDialog(sceneSize: size, safeAreaInsets: safeAreaInsets, source: "home")
        dialog.zPosition = 50
        addChild(dialog)
        dialog.onClose = { [weak dialog] in dialog?.dismiss() }
        dialog.onCurrencyChanged = { [weak self] in self?.refreshCurrency() }
    }

    private func showPixelAlbum() {
        let dialog = PixelAlbumDialog(sceneSize: size)
        dialog.zPosition = 50
        addChild(dialog)
        dialog.onClose = { [weak dialog] in dialog?.dismiss() }
    }

    /// 购买/恢复成功后即时刷新顶部货币条。
    func refreshCurrency() {
        (childNode(withName: "//home.coins") as? SKLabelNode)?.text = "\(PlayerData.shared.coins)"
        (childNode(withName: "//home.diamonds") as? SKLabelNode)?.text = "\(PlayerData.shared.diamonds)"
    }

    private func showQuests() {
        let dialog = QuestsDialog(sceneSize: size)
        dialog.zPosition = 50
        addChild(dialog)
        dialog.onClose = { [weak dialog] in dialog?.dismiss() }
        dialog.onClaim = { [weak self, weak dialog] questId in
            guard let reward = LiveOpsManager.shared.claimQuest(id: questId) else { return }
            dialog?.dismiss()
            self?.showRewardPopup(title: L10n.tr("home.quest_complete_title", fallback: "✅ QUEST COMPLETE!"),
                                  coins: reward.coins,
                                  diamonds: reward.diamonds)
        }
    }

    private func showChest() {
        guard let reward = LiveOpsManager.shared.claimChest() else {
            let chest = LiveOpsManager.shared.chestProgress
            showFloatingText(L10n.fmt("home.chest_need", chest.current, chest.target, fallback: "Collect stars to open chest: %d/%d"),
                             color: UIColor(hex: "#FFCC00"))
            return
        }
        showRewardPopup(title: L10n.tr("home.star_chest_title", fallback: "⭐ STAR CHEST!"),
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
            showFloatingText(L10n.tr("home.gc_sign_in", fallback: "Sign in to Game Center to view leaderboards!"), color: UIColor(hex: "#FFCC00"))
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
        dialogSize = CGSize(width: min(sceneSize.width - 36, 330), height: 420)
        super.init(size: dialogSize, sceneSize: sceneSize)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        addPixelTitle(L10n.tr("home.daily_quests", fallback: "DAILY QUESTS"), y: 172)
        addEventStrip(y: 130)

        let quests = LiveOpsManager.shared.quests
        for (index, quest) in quests.enumerated() {
            addQuestRow(quest, y: 72 - CGFloat(index) * 68)
        }

        let closeBtn = PixelButton(title: L10n.tr("common.close", fallback: "CLOSE"),
                                   size: CGSize(width: 220, height: 44),
                                   style: .secondary,
                                   fontSize: 16)
        closeBtn.position = CGPoint(x: 0, y: -174)
        closeBtn.onTap = { [weak self] in self?.onClose?() }
        addChild(closeBtn)
    }

    private func addEventStrip(y: CGFloat) {
        guard let event = LiveEventManager.shared.activeEvents().first else { return }
        let rowWidth = dialogSize.width - 28

        let bg = SKShapeNode(rectOf: CGSize(width: rowWidth, height: 36), cornerRadius: 8)
        bg.fillColor = UIColor(hex: "#231A0A")
        bg.strokeColor = UIColor(hex: "#FFCC00").withAlphaComponent(0.85)
        bg.lineWidth = 1.4
        bg.position = CGPoint(x: 0, y: y)
        addChild(bg)

        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.text = L10n.fmt("home.event_today", event.title, fallback: "TODAY: %@")
        title.fontSize = 11
        title.fontColor = UIColor(hex: "#FFCC00")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: -rowWidth / 2 + 12, y: y + 7)
        fitLabel(title, maxWidth: rowWidth - 24, minScale: 0.72)
        addChild(title)

        let desc = SKLabelNode(fontNamed: "Courier")
        desc.text = event.description
        desc.fontSize = 10
        desc.fontColor = UIColor(hex: "#FFE8A3")
        desc.verticalAlignmentMode = .center
        desc.horizontalAlignmentMode = .left
        desc.position = CGPoint(x: -rowWidth / 2 + 12, y: y - 8)
        fitLabel(desc, maxWidth: rowWidth - 24, minScale: 0.72)
        addChild(desc)
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
        reward.text = L10n.fmt("home.quest_reward", EconomyConfig.shared.questRewardCoins, EconomyConfig.shared.questRewardDiamonds, fallback: "+%d coins  +%d diamond")
        reward.fontSize = 11
        reward.fontColor = UIColor(hex: "#99BBCC")
        reward.verticalAlignmentMode = .center
        reward.horizontalAlignmentMode = .left
        reward.position = CGPoint(x: textLeft, y: y - 13)
        fitLabel(reward, maxWidth: maxTextWidth, minScale: 0.72)
        addChild(reward)

        let claimTitle: String
        if quest.claimed {
            claimTitle = L10n.tr("home.done", fallback: "DONE")
        } else if quest.isComplete {
            claimTitle = L10n.tr("home.claim_short", fallback: "CLAIM")
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

// MARK: - Pixel Album Dialog

final class PixelAlbumDialog: DialogNode {
    var onClose: (() -> Void)?

    private let dialogSize: CGSize

    init(sceneSize: CGSize) {
        dialogSize = CGSize(width: min(sceneSize.width - 36, 340), height: 430)
        super.init(size: dialogSize, sceneSize: sceneSize)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        addPixelTitle(L10n.tr("home.pixel_album", fallback: "PIXEL ALBUM"), y: 178)

        let overall = WorldRepairManager.shared.overall
        let overallLbl = SKLabelNode(fontNamed: "Courier-Bold")
        overallLbl.text = L10n.fmt("home.album_overall",
                                   overall.unlockedPieces,
                                   overall.totalPieces,
                                   overall.percent,
                                   fallback: "%d/%d pieces · %d%% restored")
        overallLbl.fontSize = 13
        overallLbl.fontColor = UIColor(hex: "#FFCC00")
        overallLbl.verticalAlignmentMode = .center
        overallLbl.position = CGPoint(x: 0, y: 143)
        fitLabel(overallLbl, maxWidth: dialogSize.width - 36, minScale: 0.72)
        addChild(overallLbl)

        for (index, snapshot) in albumRows().enumerated() {
            addAlbumRow(snapshot, y: 88 - CGFloat(index) * 56)
        }

        let closeBtn = PixelButton(title: L10n.tr("common.close", fallback: "CLOSE"),
                                   size: CGSize(width: 220, height: 44),
                                   style: .secondary,
                                   fontSize: 16)
        closeBtn.position = CGPoint(x: 0, y: -178)
        closeBtn.onTap = { [weak self] in self?.onClose?() }
        addChild(closeBtn)
    }

    private func albumRows() -> [WorldRepairSnapshot] {
        let currentWorldId = max(1, min(GameWorlds.count, (PlayerData.shared.maxUnlockedLevel - 1) / 20 + 1))
        let startWorldId = max(1, min(currentWorldId - 1, GameWorlds.count - 4))
        let shownWorldIds = startWorldId...min(GameWorlds.count, startWorldId + 4)
        return WorldRepairManager.shared.snapshots().filter { shownWorldIds.contains($0.world.id) }
    }

    private func addAlbumRow(_ snapshot: WorldRepairSnapshot, y: CGFloat) {
        let rowWidth = dialogSize.width - 28
        let unlocked = PlayerData.shared.isLevelUnlocked(snapshot.world.levelRange.lowerBound)

        let bg = SKShapeNode(rectOf: CGSize(width: rowWidth, height: 48), cornerRadius: 8)
        bg.fillColor = UIColor(hex: "#0F1E33")
        bg.strokeColor = unlocked
            ? snapshot.world.themeColor.withAlphaComponent(0.8)
            : UIColor(hex: "#1C3A5C")
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: 0, y: y)
        bg.alpha = unlocked ? 1.0 : 0.65
        addChild(bg)

        addAlbumPixels(snapshot, unlocked: unlocked, x: -rowWidth / 2 + 42, y: y)

        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.text = L10n.upper(snapshot.world.localizedName)
        title.fontSize = 12
        title.fontColor = unlocked ? snapshot.world.themeColor : UIColor(hex: "#7799CC")
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: -rowWidth / 2 + 82, y: y + 10)
        fitLabel(title, maxWidth: rowWidth - 112, minScale: 0.7)
        addChild(title)

        let status = SKLabelNode(fontNamed: "Courier")
        if !unlocked {
            status.text = L10n.tr("home.album_locked", fallback: "Locked")
        } else if snapshot.isComplete {
            status.text = L10n.tr("home.album_complete", fallback: "Restored")
        } else {
            status.text = L10n.fmt("home.album_world_status",
                                   snapshot.percent,
                                   snapshot.earnedStars,
                                   snapshot.totalStars,
                                   fallback: "%d%% · %d/%d stars")
        }
        status.fontSize = 10
        status.fontColor = UIColor(hex: "#99BBCC")
        status.verticalAlignmentMode = .center
        status.horizontalAlignmentMode = .left
        status.position = CGPoint(x: -rowWidth / 2 + 82, y: y - 10)
        fitLabel(status, maxWidth: rowWidth - 112, minScale: 0.7)
        addChild(status)
    }

    private func addAlbumPixels(_ snapshot: WorldRepairSnapshot, unlocked: Bool, x: CGFloat, y: CGFloat) {
        let pixelSize: CGFloat = 11
        let gap: CGFloat = 2
        let columns = 3
        for index in 0..<snapshot.totalPieces {
            let col = index % columns
            let row = index / columns
            let filled = unlocked && index < snapshot.unlockedPieces
            let pixel = SKShapeNode(rectOf: CGSize(width: pixelSize, height: pixelSize), cornerRadius: 2)
            pixel.fillColor = filled ? snapshot.world.themeColor : UIColor(hex: "#0A1628")
            pixel.strokeColor = snapshot.world.themeColor.withAlphaComponent(filled ? 0.85 : 0.32)
            pixel.lineWidth = 1
            pixel.position = CGPoint(x: x + CGFloat(col) * (pixelSize + gap),
                                     y: y + CGFloat(1 - row) * (pixelSize + gap) - 4)
            addChild(pixel)
        }
    }

    private func fitLabel(_ label: SKLabelNode, maxWidth: CGFloat, minScale: CGFloat = 0.68) {
        label.setScale(1)
        let width = max(label.frame.width, 1)
        if width > maxWidth {
            label.setScale(max(minScale, maxWidth / width))
        }
    }
}
