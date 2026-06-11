import SpriteKit
import HKAdKit

final class ResultScene: SKScene {

    var level: Level!
    var isWin: Bool = true
    var stars: Int = 0
    var score: Int = 0
    var coinsEarned: Int = 0
    var winStreak: Int = 0
    /// 失败时的目标完成度（0...1），用于失败页展示进度与鼓励语
    var completionRatio: Double = 0

    private var starNodes: [SKNode] = []
    private var safeAreaInsets: UIEdgeInsets = .zero
    private var safeBottomY: CGFloat { -size.height / 2 + safeAreaInsets.bottom }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        size = view.bounds.size
        safeAreaInsets = view.safeAreaInsets
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
        // 数量随星级递增：纸屑密度本身就是"打得好"的视觉奖励
        let count = [20, 20, 35, 50][max(0, min(stars, 3))]
        let reducedMotion = VisualComfort.isReducedMotionEnabled

        for i in 0..<(reducedMotion ? count / 3 : count) {
            let color = GemColor(rawValue: i % 6)!.primary
            let w = CGFloat.random(in: 5...10)
            let sq = SKShapeNode(rectOf: CGSize(width: w, height: w * CGFloat.random(in: 0.5...1.0)))
            sq.fillColor = color
            sq.strokeColor = .clear
            sq.position = CGPoint(x: CGFloat.random(in: -size.width/2...size.width/2),
                                  y: size.height * 0.6)
            sq.zPosition = 0
            addChild(sq)

            let delay = Double.random(in: 0...2)
            let fallDur = Double.random(in: 3...5)
            // 水平摇摆模拟纸片飘落
            let sway = SKAction.repeatForever(.sequence([
                .moveBy(x: CGFloat.random(in: 14...26), y: 0, duration: 0.45),
                .moveBy(x: -CGFloat.random(in: 14...26), y: 0, duration: 0.45)
            ]))
            sq.run(.sequence([
                .wait(forDuration: delay),
                .repeatForever(.group([
                    .moveBy(x: 0, y: -size.height * 1.5, duration: fallDur),
                    .rotate(byAngle: .pi * CGFloat.random(in: 2...6), duration: fallDur)
                ]))
            ]))
            if !reducedMotion { sq.run(sway) }
        }
    }

    // MARK: - Win UI

    private func setupWinUI() {
        let buttonBaseY = winButtonBaseY()
        let buttonTopY = buttonBaseY + 27
        let hasStreakBonus = winStreak >= 3
        let hasRewardLine = coinsEarned > 0 || hasStreakBonus

        let titleY = size.height * 0.30
        let levelY = size.height * 0.225
        let repairY = size.height * 0.155
        let starsY = size.height * 0.075

        // Title
        let title = makeLargeLabel(L10n.tr("result.level_clear", fallback: "LEVEL CLEAR!"), color: UIColor(hex: "#FFCC00"), size: 36)
        title.position = CGPoint(x: 0, y: titleY)
        title.zPosition = 10
        addChild(title)
        title.popIn()

        // Level info
        let levelLbl = makeLargeLabel(L10n.upper(level.displayName),
                                      color: UIColor(hex: level.world?.themeColorHex ?? "#FFFFFF"),
                                      size: 18)
        levelLbl.position = CGPoint(x: 0, y: levelY)
        levelLbl.zPosition = 10
        addChild(levelLbl)

        setupWorldRepairRibbon(y: repairY)

        // Stars
        setupStars(y: starsY)

        // Score panel
        let scoreY = max(-size.height * 0.08, buttonTopY + (hasRewardLine ? 92 : 72))
        setupScorePanel(y: scoreY)

        let scoreBottomY = scoreY - 40

        // Coins reward
        let rewardY = hasStreakBonus
            ? min(buttonTopY + 62, scoreBottomY - 18)
            : min(buttonTopY + 45, scoreBottomY - 18)
        setupCoinsReward(y: rewardY)

        // Win streak
        if hasStreakBonus {
            let streakLbl = makeLargeLabel(L10n.fmt("result.streak_bonus", winStreak, fallback: "🔥 ×%d STREAK BONUS!"), color: UIColor(hex: "#FF9500"), size: 15)
            let streakY = coinsEarned > 0 ? max(buttonTopY + 15, rewardY - 28) : rewardY
            streakLbl.position = CGPoint(x: 0, y: streakY)
            streakLbl.zPosition = 11
            addChild(streakLbl)
            streakLbl.run(.repeatForever(.sequence([
                .scale(to: 1.08, duration: 0.3),
                .scale(to: 1.0, duration: 0.3)
            ])))
        }

        // Buttons
        setupWinButtons(yBase: buttonBaseY)
    }

    private func setupWorldRepairRibbon(y: CGFloat) {
        guard let world = level.world else { return }

        let repair = WorldRepairManager.shared.snapshot(for: world)
        let panelWidth = min(size.width * 0.78, 310)
        let panelHeight: CGFloat = 44
        let panel = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 8)
        panel.fillColor = world.bgColor.darker(by: 0.12).withAlphaComponent(0.80)
        panel.strokeColor = world.themeColor.withAlphaComponent(0.48)
        panel.lineWidth = 1.4
        panel.position = CGPoint(x: 0, y: y)
        panel.zPosition = 10
        addChild(panel)

        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.text = L10n.tr("result.world_repair", fallback: "WORLD REPAIR")
        title.fontSize = 10
        title.fontColor = world.themeColor
        title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: -panelWidth / 2 + 14, y: y + 10)
        title.zPosition = 11
        addChild(title)
        fitLabel(title, maxWidth: panelWidth * 0.46, minScale: 0.72)

        let status = SKLabelNode(fontNamed: "Courier-Bold")
        status.text = repair.isComplete
            ? L10n.tr("result.world_restored", fallback: "RESTORED")
            : L10n.fmt("result.world_repair_percent", repair.percent, fallback: "%d%%")
        status.fontSize = 12
        status.fontColor = UIColor(hex: repair.isComplete ? "#FFCC00" : world.themeColorHex)
        status.verticalAlignmentMode = .center
        status.horizontalAlignmentMode = .right
        status.position = CGPoint(x: panelWidth / 2 - 14, y: y + 10)
        status.zPosition = 11
        addChild(status)
        fitLabel(status, maxWidth: panelWidth * 0.30, minScale: 0.72)

        addRepairPixels(repair, panelWidth: panelWidth, y: y - 11)

        panel.setScale(0.96)
        panel.alpha = 0
        panel.run(.group([
            .fadeIn(withDuration: 0.18),
            .scale(to: 1, duration: 0.18)
        ]))
    }

    private func addRepairPixels(_ repair: WorldRepairSnapshot, panelWidth: CGFloat, y: CGFloat) {
        let gap: CGFloat = 4
        let pixelCount = max(1, repair.totalPieces)
        let availableWidth = panelWidth - 34
        let pixelWidth = min(36, (availableWidth - CGFloat(pixelCount - 1) * gap) / CGFloat(pixelCount))
        let totalWidth = CGFloat(pixelCount) * pixelWidth + CGFloat(pixelCount - 1) * gap
        let startX = -totalWidth / 2 + pixelWidth / 2

        for index in 0..<pixelCount {
            let filled = index < repair.unlockedPieces
            let pixel = SKShapeNode(rectOf: CGSize(width: pixelWidth, height: 8), cornerRadius: 2)
            pixel.fillColor = filled
                ? repair.world.themeColor.withAlphaComponent(0.88)
                : UIColor(hex: "#07101D").withAlphaComponent(0.82)
            pixel.strokeColor = repair.world.themeColor.withAlphaComponent(filled ? 0.85 : 0.28)
            pixel.lineWidth = 1
            pixel.position = CGPoint(x: startX + CGFloat(index) * (pixelWidth + gap), y: y)
            pixel.zPosition = 11
            addChild(pixel)

            guard filled else { continue }
            pixel.setScale(0)
            pixel.run(.sequence([
                .wait(forDuration: 0.48 + Double(index) * 0.08),
                .scale(to: 1.18, duration: 0.10),
                .scale(to: 1.0, duration: 0.08)
            ]))
            if index == repair.unlockedPieces - 1 {
                addRepairSparkle(at: pixel.position, delay: 0.64 + Double(index) * 0.08, color: repair.world.themeColor)
            }
        }
    }

    private func addRepairSparkle(at position: CGPoint, delay: TimeInterval, color: UIColor) {
        let sparkle = SKShapeNode(rectOf: CGSize(width: 10, height: 10), cornerRadius: 2)
        sparkle.fillColor = color.withAlphaComponent(0.72)
        sparkle.strokeColor = UIColor.white.withAlphaComponent(0.74)
        sparkle.lineWidth = 1
        sparkle.position = position
        sparkle.zPosition = 12
        sparkle.alpha = 0
        sparkle.setScale(0.2)
        addChild(sparkle)
        sparkle.run(.sequence([
            .wait(forDuration: delay),
            .group([
                .fadeAlpha(to: 0.88, duration: 0.08),
                .scale(to: 1.4, duration: 0.12),
                .rotate(byAngle: .pi / 4, duration: 0.12)
            ]),
            .group([
                .fadeOut(withDuration: 0.18),
                .scale(to: 0.2, duration: 0.18)
            ]),
            .removeFromParent()
        ]))
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

            let tex = PixelArt.shared.starBadgeTexture(lit: lit, size: 38)
            let star = SKSpriteNode(texture: tex, size: CGSize(width: 36, height: 36))
            container.addChild(star)

            if lit {
                container.setScale(0)
                let delay = 0.3 + Double(i) * 0.15
                container.run(.sequence([
                    .wait(forDuration: delay),
                    .scale(to: 1.3, duration: 0.15),
                    .scale(to: 1.0, duration: 0.1)
                ])) { [weak self] in
                    // 星星音效随序号升调 + 落位放射爆点
                    AudioManager.shared.play(.starEarn, pitchStep: i * 2)
                    self?.spawnStarBurst(at: container.position)
                }
            }
            starNodes.append(container)
        }
    }

    /// 星星落位时的金色放射爆点
    private func spawnStarBurst(at position: CGPoint) {
        guard !VisualComfort.isReducedMotionEnabled else { return }
        let gold = UIColor(hex: "#FFCC00")
        for _ in 0..<10 {
            let sz = CGFloat.random(in: 3...6)
            let p = SKSpriteNode(texture: PixelArt.shared.particleTexture(color: gold, size: sz),
                                 size: CGSize(width: sz, height: sz))
            p.position = position
            p.zPosition = 12
            addChild(p)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 26...54)
            p.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * dist, y: sin(angle) * dist, duration: 0.3),
                    .scale(to: 0.3, duration: 0.3),
                    .fadeOut(withDuration: 0.3)
                ]),
                .removeFromParent()
            ]))
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

        let scoreTitleLbl = makeLargeLabel(L10n.tr("hud.score", fallback: "SCORE"), color: UIColor(hex: "#7799CC"), size: 14)
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
            let bestLbl = makeLargeLabel(L10n.tr("result.new_best", fallback: "✦ NEW BEST!"), color: UIColor(hex: "#FF9500"), size: 13)
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

        let coinTex = PixelArt.shared.softIconTexture(.coin, size: 30)
        let coinIcon = SKSpriteNode(texture: coinTex, size: CGSize(width: 28, height: 28))
        coinIcon.position = CGPoint(x: -50, y: y)
        coinIcon.zPosition = 11
        addChild(coinIcon)

        let coinsLbl = makeLargeLabel(L10n.fmt("result.coins", coinsEarned, fallback: "+%d Coins!"), color: UIColor(hex: "#FFCC00"), size: 22)
        coinsLbl.position = CGPoint(x: 20, y: y)
        coinsLbl.zPosition = 11
        addChild(coinsLbl)

        if VisualComfort.isReducedMotionEnabled {
            // 降级：跳过飞行，仅数字滚动
            runCoinCountUp(on: coinsLbl, from: 0, to: coinsEarned, duration: 0.6, delay: 0.3)
            AudioManager.shared.play(.coinCollect)
            return
        }

        // 金币飞入演出：从分数面板飞向计数行，逐枚音效音高递增 + 计数滚动
        coinsLbl.text = L10n.fmt("result.coins", 0, fallback: "+%d Coins!")
        let flyCount = min(12, max(6, coinsEarned / 10))
        let startPoint = CGPoint(x: 0, y: y + 110)   // 分数面板附近
        let target = coinIcon.position
        let interval = 0.06

        for i in 0..<flyCount {
            let coin = SKSpriteNode(texture: coinTex, size: CGSize(width: 22, height: 22))
            coin.position = startPoint
            coin.zPosition = 30
            coin.alpha = 0
            addChild(coin)

            // 随机二次贝塞尔路径：先散开再汇入
            let ctrl = CGPoint(x: CGFloat.random(in: -130...130),
                               y: y + CGFloat.random(in: 30...90))
            let path = CGMutablePath()
            path.move(to: startPoint)
            path.addQuadCurve(to: target, control: ctrl)

            let delay = 0.5 + Double(i) * interval
            coin.run(.sequence([
                .wait(forDuration: delay),
                .fadeIn(withDuration: 0.05),
                .follow(path, asOffset: false, orientToPath: false, duration: 0.42),
                .run { [weak self, weak coinIcon] in
                    AudioManager.shared.play(.coinCollect, pitchStep: min(i, 8))
                    coinIcon?.removeAction(forKey: "bounce")
                    coinIcon?.setScale(1.0)
                    coinIcon?.run(.sequence([.scale(to: 1.18, duration: 0.06),
                                             .scale(to: 1.0, duration: 0.08)]), withKey: "bounce")
                    _ = self
                },
                .removeFromParent()
            ]))
        }

        // 计数滚动与飞行同步
        let flightTotal = 0.5 + Double(flyCount) * interval + 0.42
        runCoinCountUp(on: coinsLbl, from: 0, to: coinsEarned,
                       duration: flightTotal - 0.5, delay: 0.55)
    }

    /// 数字滚动累加（SKAction.customAction 插值）
    private func runCoinCountUp(on label: SKLabelNode, from: Int, to: Int,
                                duration: TimeInterval, delay: TimeInterval) {
        let countUp = SKAction.customAction(withDuration: duration) { node, elapsed in
            guard let lbl = node as? SKLabelNode else { return }
            let progress = min(1, max(0, Double(elapsed) / duration))
            let value = from + Int(Double(to - from) * progress)
            lbl.text = L10n.fmt("result.coins", value, fallback: "+%d Coins!")
        }
        label.run(.sequence([
            .wait(forDuration: delay),
            countUp,
            .run { label.text = L10n.fmt("result.coins", to, fallback: "+%d Coins!") },
            .scale(to: 1.2, duration: 0.1),
            .scale(to: 1.0, duration: 0.1)
        ]))
    }

    private func setupWinButtons(yBase: CGFloat) {

        // Next Level button
        let nextBtn = PixelButton(title: L10n.tr("result.next_level", fallback: "NEXT LEVEL ▶"),
                                   icon: .play,
                                   size: CGSize(width: 240, height: 54),
                                   style: .primary,
                                   color: UIColor(hex: "#34C759"),
                                   fontSize: 20)
        nextBtn.position = CGPoint(x: 0, y: yBase)
        nextBtn.zPosition = 20
        nextBtn.onTap = { [weak self] in self?.goToNextLevel() }
        addChild(nextBtn)

        let mapBtn = PixelButton(title: L10n.tr("result.level_map", fallback: "◀ LEVEL MAP"),
                                  icon: .back,
                                  size: CGSize(width: 240, height: 46),
                                  style: .secondary,
                                  fontSize: 16)
        mapBtn.position = CGPoint(x: 0, y: yBase - 62)
        mapBtn.zPosition = 20
        mapBtn.onTap = { [weak self] in self?.goToMap() }
        addChild(mapBtn)

        let replayBtn = PixelButton(title: L10n.tr("result.replay", fallback: "↺ REPLAY"),
                                    icon: .restart,
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
        let title = makeLargeLabel(L10n.tr("result.level_failed", fallback: "LEVEL FAILED"), color: UIColor(hex: "#FF3B30"), size: 36)
        title.position = CGPoint(x: 0, y: size.height * 0.28)
        title.zPosition = 10
        addChild(title)
        title.popIn()
        title.shake()

        // Score
        let scoreLbl = makeLargeLabel(L10n.fmt("result.score_line", score.scoreFormatted, fallback: "Score: %@"),
                                      color: UIColor(hex: "#99BBCC"), size: 22)
        scoreLbl.position = CGPoint(x: 0, y: size.height * 0.1)
        scoreLbl.zPosition = 10
        addChild(scoreLbl)

        // 完成度展示（>0 时）：让玩家看到"已经走了多远"而不是只看到失败
        if completionRatio > 0 {
            let pctLbl = makeLargeLabel(L10n.fmt("result.fail.progress", Int(completionRatio * 100),
                                                 fallback: "You finished %d%%"),
                                        color: UIColor(hex: "#99CCFF"), size: 16)
            pctLbl.position = CGPoint(x: 0, y: size.height * 0.045)
            pctLbl.zPosition = 10
            addChild(pctLbl)
        }

        // 随机鼓励语轮换，替代固定文案
        let encourageKeys = ["encourage.fail.1", "encourage.fail.2", "encourage.fail.3"]
        let fallbacks = ["Every master was once a beginner!",
                         "That board was tough — you got this!",
                         "So near! Try a different first move."]
        let idx = Int.random(in: 0..<encourageKeys.count)
        let msgLbl = makeLargeLabel(L10n.tr(encourageKeys[idx], fallback: fallbacks[idx]),
                                    color: UIColor(hex: "#FFCC00"), size: 16)
        msgLbl.position = CGPoint(x: 0, y: -10)
        msgLbl.zPosition = 10
        msgLbl.preferredMaxLayoutWidth = size.width * 0.86
        msgLbl.numberOfLines = 2
        addChild(msgLbl)
        fitLabel(msgLbl, maxWidth: size.width * 0.88)

        // Pixel broken-X art
        addBrokenX()
        setupFailButtons()
    }

    private func addBrokenX() {
        for _ in 0..<8 {
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
        // 非 VIP 多两个广告位（continueLevel + bonusCoins），按钮组更长，基线相应抬高。
        let hasAdButtons = !PlayerData.shared.noAds
        let yBase = hasAdButtons
            ? max(-size.height * 0.26, safeBottomY + 175)
            : max(-size.height * 0.3, safeBottomY + 99)

        let retryBtn = PixelButton(title: L10n.tr("result.try_again", fallback: "↺ TRY AGAIN"),
                                   icon: .restart,
                                   size: CGSize(width: 240, height: 54),
                                   style: .primary,
                                   color: UIColor(hex: "#FF9500"),
                                   fontSize: 20)
        retryBtn.position = CGPoint(x: 0, y: yBase)
        retryBtn.zPosition = 20
        retryBtn.onTap = { [weak self] in self?.replayLevel() }
        addChild(retryBtn)

        // HKAdKit "continueLevel" / "bonusCoins" placement 的承载按钮。VIP 用户不渲染。
        var nextY = yBase - 60
        if hasAdButtons {
            let continueBtn = PixelButton(title: L10n.tr("result.continue_ad",
                                                          fallback: "📹 WATCH AD: RETRY +5 MOVES"),
                                          icon: .video,
                                          size: CGSize(width: 280, height: 46),
                                          style: .secondary,
                                          color: UIColor(hex: "#34C759"),
                                          fontSize: 14)
            continueBtn.position = CGPoint(x: 0, y: nextY)
            continueBtn.zPosition = 20
            continueBtn.onTap = { [weak self, weak continueBtn] in self?.showContinueAd(button: continueBtn) }
            addChild(continueBtn)
            nextY -= 54

            let bonusBtn = PixelButton(title: L10n.tr("result.bonus_ad",
                                                       fallback: "📹 WATCH AD: +50 COINS"),
                                       icon: .video,
                                       size: CGSize(width: 280, height: 46),
                                       style: .secondary,
                                       color: UIColor(hex: "#AF52DE"),
                                       fontSize: 14)
            bonusBtn.position = CGPoint(x: 0, y: nextY)
            bonusBtn.zPosition = 20
            bonusBtn.onTap = { [weak self, weak bonusBtn] in self?.showBonusAd(button: bonusBtn) }
            addChild(bonusBtn)
            nextY -= 54
        }

        let mapBtn = PixelButton(title: L10n.tr("result.level_map", fallback: "◀ LEVEL MAP"),
                                  icon: .back,
                                  size: CGSize(width: 240, height: 46),
                                  style: .secondary,
                                  fontSize: 16)
        mapBtn.position = CGPoint(x: 0, y: nextY)
        mapBtn.zPosition = 20
        mapBtn.onTap = { [weak self] in self?.goToMap() }
        addChild(mapBtn)
    }

    /// HKAdKit "continueLevel" placement：看完激励视频免费重玩当前关，且开局 +5 步。
    /// 与"TRY AGAIN"区别在于额外步数；reward 不走 AdRewardProvider（关卡跳转副作用绑定本 Scene）。
    private func showContinueAd(button: PixelButton?) {
        guard let view = view, let vc = view.window?.rootViewController else { return }
        button?.setEnabled(false)
        AdManager.shared.showRewardedAd(placement: "continueLevel", from: vc) { [weak self, weak button] earned in
            DispatchQueue.main.async {
                if earned {
                    self?.replayLevel(bonusMoves: 5)
                } else {
                    button?.setEnabled(true)
                }
            }
        }
    }

    private func showBonusAd(button: PixelButton?) {
        guard let view = view, let vc = view.window?.rootViewController else { return }
        button?.setEnabled(false)
        AdManager.shared.showRewardedAd(placement: "bonusCoins", from: vc) { [weak button] earned in
            DispatchQueue.main.async {
                if earned {
                    // PixelMatchAdRewardProvider.grantReward 已在内部加了 +50 金币。
                    button?.setTitle(L10n.tr("result.bonus_done", fallback: "✓ +50 COINS"))
                } else {
                    // 失败/未发奖：恢复按钮态，玩家可重试。
                    button?.setTitle(L10n.tr("result.bonus_ad", fallback: "📹 WATCH AD: +50 COINS"))
                    button?.setEnabled(true)
                }
            }
        }
    }

    // MARK: - Navigation

    private func winButtonBaseY() -> CGFloat {
        // Replay 是按钮组最底部的控件，按安全区反推整组按钮基线。
        max(-size.height * 0.38, safeBottomY + 154)
    }

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
        // 切场景前先试插屏：HKAdKit 自己有 VIP/频次/间隔 gate，不达条件立即回调 false。
        // 不让玩家等：插屏播完或被 gate 拒绝都走同一段切场景代码。
        if let vc = view.window?.rootViewController, !PlayerData.shared.noAds {
            AdManager.shared.showInterstitial(from: vc) { [weak self] _ in
                DispatchQueue.main.async { self?.transitionToMap() }
            }
        } else {
            transitionToMap()
        }
    }

    private func transitionToMap() {
        guard let view = view else { return }
        let scene = MapScene(size: size)
        scene.scaleMode = .aspectFill
        view.presentScene(scene, transition: .fade(withDuration: 0.4))
    }

    private func replayLevel(bonusMoves: Int = 0) {
        guard let view = view else { return }
        let scene = GameScene(size: size)
        scene.level = level
        scene.bonusMovesFromAd = bonusMoves
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

    private func fitLabel(_ label: SKLabelNode, maxWidth: CGFloat, minScale: CGFloat = 0.68) {
        label.setScale(1)
        let width = max(label.frame.width, 1)
        if width > maxWidth {
            label.setScale(max(minScale, maxWidth / width))
        }
    }
}
