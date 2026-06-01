import SpriteKit

// MARK: - Base Dialog

class DialogNode: SKNode {

    let panel: SKShapeNode
    let panelSize: CGSize
    let sceneSize: CGSize

    init(size: CGSize, sceneSize: CGSize) {
        self.panelSize = size
        self.sceneSize = sceneSize

        // Overlay
        let overlay = SKShapeNode(rectOf: sceneSize)
        overlay.fillColor = UIColor.black.withAlphaComponent(0.65)
        overlay.strokeColor = .clear
        overlay.zPosition = -1
        panel = SKShapeNode(rectOf: size, cornerRadius: 16)
        panel.fillColor = UIColor(hex: "#0D1B2A")
        panel.strokeColor = UIColor(hex: "#2255AA")
        panel.lineWidth = 3
        panel.zPosition = 0

        super.init()
        zPosition = 100
        addChild(overlay)
        addChild(panel)
        popIn(from: 0.3)
    }

    required init?(coder: NSCoder) { fatalError() }

    func dismiss(completion: (() -> Void)? = nil) {
        run(.sequence([
            .scale(to: 0.0, duration: 0.15),
            .removeFromParent()
        ])) { completion?() }
    }

    func addPixelTitle(_ text: String, y: CGFloat, color: UIColor = UIColor(hex: "#FFCC00"), size: CGFloat = 24) {
        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = text
        lbl.fontSize = size
        lbl.fontColor = color
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint(x: 0, y: y)
        addChild(lbl)
    }
}

// MARK: - Pause Dialog

final class PauseDialogNode: DialogNode {

    var onResume: (() -> Void)?
    var onRestart: (() -> Void)?
    var onQuit: (() -> Void)?
    var onSettings: (() -> Void)?

    init(sceneSize: CGSize) {
        super.init(size: CGSize(width: 280, height: 360), sceneSize: sceneSize)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        addPixelTitle(L10n.tr("dialog.pause.title", fallback: "⏸ PAUSED"), y: 140)

        // Pixel decoration
        for i in 0...5 {
            let sq = SKShapeNode(rectOf: CGSize(width: 8, height: 8))
            sq.fillColor = GemColor(rawValue: i)!.primary
            sq.strokeColor = .clear
            sq.position = CGPoint(x: -100 + CGFloat(i) * 40, y: 110)
            addChild(sq)
        }

        let resumeBtn = PixelButton(title: L10n.tr("dialog.resume", fallback: "▶ RESUME"), icon: .play, size: CGSize(width: 220, height: 48),
                                    style: .primary, color: UIColor(hex: "#34C759"))
        resumeBtn.position = CGPoint(x: 0, y: 55)
        resumeBtn.onTap = { [weak self] in self?.onResume?() }
        addChild(resumeBtn)

        let restartBtn = PixelButton(title: L10n.tr("dialog.restart", fallback: "↺ RESTART"), icon: .restart, size: CGSize(width: 220, height: 48),
                                     style: .primary, color: UIColor(hex: "#FF9500"))
        restartBtn.position = CGPoint(x: 0, y: -5)
        restartBtn.onTap = { [weak self] in self?.onRestart?() }
        addChild(restartBtn)

        let settingsBtn = PixelButton(title: L10n.tr("dialog.settings", fallback: "⚙ SETTINGS"), icon: .settings, size: CGSize(width: 220, height: 48),
                                      style: .secondary)
        settingsBtn.position = CGPoint(x: 0, y: -65)
        settingsBtn.onTap = { [weak self] in self?.onSettings?() }
        addChild(settingsBtn)

        let quitBtn = PixelButton(title: L10n.tr("dialog.quit", fallback: "✕ QUIT"), icon: .close, size: CGSize(width: 220, height: 48),
                                   style: .danger)
        quitBtn.position = CGPoint(x: 0, y: -125)
        quitBtn.onTap = { [weak self] in self?.onQuit?() }
        addChild(quitBtn)
    }
}

// MARK: - Out of Moves Dialog

final class OutOfMovesDialog: DialogNode {

    var onContinue: (() -> Void)?  // spend diamonds
    var onWatchAd: (() -> Void)?   // 看激励视频 +5 步（非 VIP 才挂载到 HKAdKit "extraMoves" placement）
    var onQuit: (() -> Void)?

    init(sceneSize: CGSize, movesCount: Int = 5, diamondCost: Int = 10, hintText: String? = nil) {
        // 高度按"是否展示看广告按钮"动态：VIP 维持 340，非 VIP 拉到 400 留 +5 步入口。
        let hasHint = !(hintText?.isEmpty ?? true)
        let height: CGFloat = PlayerData.shared.noAds ? (hasHint ? 370 : 340) : (hasHint ? 430 : 400)
        super.init(size: CGSize(width: 300, height: height), sceneSize: sceneSize)
        buildUI(moves: movesCount, cost: diamondCost, hintText: hintText)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(moves: Int, cost: Int, hintText: String?) {
        let hasHint = !(hintText?.isEmpty ?? true)
        let panelHalf = panelSize.height / 2
        let titleY = panelHalf - 65
        let msgY = titleY - 55
        let hintY = msgY - 28
        let diamondY = hasHint ? hintY - 43 : msgY - 45
        let haveY = diamondY - 40
        let quitY = -panelHalf + 38
        let adY = quitY + 55
        let continueY = PlayerData.shared.noAds ? quitY + 60 : adY + 58

        addPixelTitle(L10n.tr("dialog.out_of_moves.title", fallback: "OUT OF MOVES!"),
                      y: titleY,
                      color: UIColor(hex: "#FF3B30"))

        let msgLbl = SKLabelNode(fontNamed: "Courier")
        msgLbl.text = L10n.fmt("dialog.out_of_moves.message", moves, fallback: "Continue with +%d moves?")
        msgLbl.fontSize = 16
        msgLbl.fontColor = UIColor(hex: "#99BBCC")
        msgLbl.verticalAlignmentMode = .center
        msgLbl.position = CGPoint(x: 0, y: msgY)
        addChild(msgLbl)

        if let hintText = hintText, !hintText.isEmpty {
            let hintLbl = SKLabelNode(fontNamed: "Courier-Bold")
            hintLbl.text = hintText
            hintLbl.fontSize = 13
            hintLbl.fontColor = UIColor(hex: "#FFCC00")
            hintLbl.verticalAlignmentMode = .center
            hintLbl.horizontalAlignmentMode = .center
            hintLbl.numberOfLines = 2
            hintLbl.preferredMaxLayoutWidth = 250
            hintLbl.position = CGPoint(x: 0, y: hintY)
            addChild(hintLbl)
        }

        // Diamond icon + cost
        let diamonds = PlayerData.shared.diamonds
        let canAfford = diamonds >= cost
        let diamondTex = PixelArt.shared.softIconTexture(.diamond, size: 34)
        let dIcon = SKSpriteNode(texture: diamondTex, size: CGSize(width: 32, height: 32))
        dIcon.position = CGPoint(x: -25, y: diamondY)
        addChild(dIcon)

        let costLbl = SKLabelNode(fontNamed: "Courier-Bold")
        costLbl.text = "×\(cost)"
        costLbl.fontSize = 26
        costLbl.fontColor = canAfford ? UIColor(hex: "#AF52DE") : UIColor(hex: "#FF3B30")
        costLbl.verticalAlignmentMode = .center
        costLbl.position = CGPoint(x: 15, y: diamondY)
        addChild(costLbl)

        let haveLbl = SKLabelNode(fontNamed: "Courier")
        haveLbl.text = L10n.fmt("dialog.you_have_diamonds", diamonds, fallback: "You have: %d 💎")
        haveLbl.fontSize = 14
        haveLbl.fontColor = UIColor(hex: "#7799CC")
        haveLbl.verticalAlignmentMode = .center
        haveLbl.position = CGPoint(x: 0, y: haveY)
        addChild(haveLbl)

        let continueBtn = PixelButton(title: canAfford ? L10n.tr("dialog.continue", fallback: "CONTINUE!") : L10n.tr("dialog.get_diamonds", fallback: "GET DIAMONDS"),
                                      icon: .diamond,
                                      size: CGSize(width: 240, height: 52),
                                      style: .primary,
                                      color: canAfford ? UIColor(hex: "#AF52DE") : UIColor(hex: "#FF9500"))
        continueBtn.name = "outOfMoves.continue"
        continueBtn.position = CGPoint(x: 0, y: continueY)
        continueBtn.onTap = { [weak self] in self?.onContinue?() }
        addChild(continueBtn)

        // 看广告 +5 步：HKAdKit "extraMoves" placement 的承载按钮。仅非 VIP 显示。
        if !PlayerData.shared.noAds {
            let adBtn = PixelButton(title: L10n.tr("dialog.extra_moves_ad", fallback: "📹 WATCH AD: +5 MOVES"),
                                    icon: .video,
                                    size: CGSize(width: 260, height: 46),
                                    style: .secondary,
                                    color: UIColor(hex: "#34C759"),
                                    fontSize: 15)
            adBtn.name = "outOfMoves.ad"
            adBtn.position = CGPoint(x: 0, y: adY)
            adBtn.onTap = { [weak self] in self?.onWatchAd?() }
            addChild(adBtn)
        }

        let quitBtn = PixelButton(title: L10n.tr("dialog.no_thanks", fallback: "NO THANKS"), size: CGSize(width: 240, height: 44),
                                   style: .ghost, color: UIColor(hex: "#7799CC"))
        quitBtn.name = "outOfMoves.quit"
        quitBtn.position = CGPoint(x: 0, y: quitY)
        quitBtn.onTap = { [weak self] in self?.onQuit?() }
        addChild(quitBtn)
    }
}

// MARK: - No Lives Dialog

final class NoLivesDialog: DialogNode {

    var onRefillWithDiamonds: (() -> Void)?
    var onRefillWithAd: (() -> Void)?
    var onWaitForFree: (() -> Void)?
    var onClose: (() -> Void)?

    init(sceneSize: CGSize) {
        super.init(size: CGSize(width: 300, height: 360), sceneSize: sceneSize)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        addPixelTitle(L10n.tr("dialog.no_lives.title", fallback: "NO LIVES!"), y: 140, color: UIColor(hex: "#FF3B30"))

        // Broken hearts
        for i in 0..<5 {
            let tex = PixelArt.shared.heartBadgeTexture(filled: false, size: 30)
            let h = SKSpriteNode(texture: tex, size: CGSize(width: 28, height: 28))
            h.position = CGPoint(x: -56 + CGFloat(i) * 28, y: 95)
            h.alpha = 0.78
            addChild(h)
        }

        // Timer
        let nextLbl = SKLabelNode(fontNamed: "Courier-Bold")
        nextLbl.text = L10n.fmt("dialog.next_life", LivesManager.shared.timeUntilNextLifeString, fallback: "Next life in: %@")
        nextLbl.fontSize = 16
        nextLbl.fontColor = UIColor(hex: "#7799CC")
        nextLbl.verticalAlignmentMode = .center
        nextLbl.position = CGPoint(x: 0, y: 50)
        nextLbl.name = "timer"
        addChild(nextLbl)

        // Refill button
        let refillBtn = PixelButton(title: L10n.tr("dialog.refill", fallback: "REFILL (15 💎)"),
                                    icon: .diamond,
                                    size: CGSize(width: 240, height: 52),
                                    style: .primary,
                                    color: UIColor(hex: "#AF52DE"))
        refillBtn.position = CGPoint(x: 0, y: -20)
        refillBtn.onTap = { [weak self] in self?.onRefillWithDiamonds?() }
        addChild(refillBtn)

        // 看广告补一格生命：仅非 VIP 用户显示。
        var nextY: CGFloat = -80
        if !PlayerData.shared.noAds {
            let adBtn = PixelButton(title: L10n.tr("dialog.refill_ad", fallback: "📹 WATCH AD: +1 ❤"),
                                    icon: .video,
                                    size: CGSize(width: 240, height: 48),
                                    style: .secondary,
                                    color: UIColor(hex: "#34C759"))
            adBtn.position = CGPoint(x: 0, y: nextY)
            adBtn.onTap = { [weak self] in self?.onRefillWithAd?() }
            addChild(adBtn)
            nextY -= 60
        }

        let waitBtn = PixelButton(title: L10n.tr("dialog.wait_life", fallback: "WAIT FOR FREE LIFE"),
                                   icon: .heart,
                                   size: CGSize(width: 240, height: 48),
                                   style: .secondary)
        waitBtn.position = CGPoint(x: 0, y: nextY)
        waitBtn.onTap = { [weak self] in self?.onWaitForFree?() }
        addChild(waitBtn)
        nextY -= 60

        let closeBtn = PixelButton(title: L10n.tr("common.close", fallback: "CLOSE"), size: CGSize(width: 240, height: 44),
                                   style: .ghost, color: UIColor(hex: "#7799CC"))
        closeBtn.position = CGPoint(x: 0, y: nextY)
        closeBtn.onTap = { [weak self] in self?.onClose?() }
        addChild(closeBtn)
    }
}

// MARK: - Settings Dialog

final class SettingsDialog: DialogNode {

    var onClose: (() -> Void)?

    init(sceneSize: CGSize) {
        super.init(size: CGSize(width: 300, height: 370), sceneSize: sceneSize)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        addPixelTitle(L10n.tr("dialog.settings", fallback: "⚙ SETTINGS"), y: 130)

        func toggle(label: String, yPos: CGFloat, value: Bool, onToggle: @escaping (Bool) -> Void) {
            let lbl = SKLabelNode(fontNamed: "Courier-Bold")
            lbl.text = label
            lbl.fontSize = 16
            lbl.fontColor = .white
            lbl.verticalAlignmentMode = .center
            lbl.horizontalAlignmentMode = .left
            lbl.position = CGPoint(x: -120, y: yPos)
            addChild(lbl)

            var state = value
            let toggleBtn = PixelButton(title: state ? L10n.tr("common.on", fallback: "ON") : L10n.tr("common.off", fallback: "OFF"),
                                        size: CGSize(width: 70, height: 32),
                                        style: .primary,
                                        color: state ? UIColor(hex: "#34C759") : UIColor(hex: "#555"))
            toggleBtn.position = CGPoint(x: 90, y: yPos)
            toggleBtn.onTap = {
                state.toggle()
                onToggle(state)
                toggleBtn.setTitle(state ? L10n.tr("common.on", fallback: "ON") : L10n.tr("common.off", fallback: "OFF"))
                toggleBtn.setColor(state ? UIColor(hex: "#34C759") : UIColor(hex: "#555"))
            }
            addChild(toggleBtn)
        }

        toggle(label: L10n.tr("settings.sound", fallback: "🔊 Sound"), yPos: 65,
               value: PlayerData.shared.soundEnabled) { PlayerData.shared.soundEnabled = $0 }
        toggle(label: L10n.tr("settings.music", fallback: "🎵 Music"), yPos: 15,
               value: PlayerData.shared.musicEnabled) { enabled in
            PlayerData.shared.musicEnabled = enabled
            AudioManager.shared.setMusicEnabled(enabled)
        }
        toggle(label: L10n.tr("settings.vibrate", fallback: "📳 Vibrate"), yPos: -35,
               value: PlayerData.shared.vibrateEnabled) { PlayerData.shared.vibrateEnabled = $0 }
        toggle(label: L10n.tr("settings.reduce_motion", fallback: "◌ Comfort FX"), yPos: -85,
               value: PlayerData.shared.reduceMotionEnabled) { PlayerData.shared.reduceMotionEnabled = $0 }

        let closeBtn = PixelButton(title: L10n.tr("common.close", fallback: "CLOSE"),
                                   size: CGSize(width: 240, height: 48),
                                   style: .primary,
                                   color: UIColor(hex: "#007AFF"))
        closeBtn.position = CGPoint(x: 0, y: -145)
        closeBtn.onTap = { [weak self] in self?.onClose?() }
        addChild(closeBtn)
    }
}

// MARK: - Pre-Level Booster Dialog

final class PreLevelDialog: DialogNode {
    var onPlay: (([BoosterType]) -> Void)?
    var onClose: (() -> Void)?

    private var selectedBoosters: [BoosterType: Bool] = [:]

    init(level: Level, sceneSize: CGSize) {
        super.init(size: CGSize(width: 300, height: 420), sceneSize: sceneSize)
        buildUI(level: level)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(level: Level) {
        addPixelTitle(L10n.tr("dialog.power_up", fallback: "POWER UP!"), y: 182, color: UIColor(hex: "#FFCC00"))

        let subLbl = SKLabelNode(fontNamed: "Courier")
        subLbl.text = level.displayName
        subLbl.fontSize = 14
        subLbl.fontColor = UIColor(hex: level.world?.themeColorHex ?? "#FFFFFF")
        subLbl.verticalAlignmentMode = .center
        subLbl.position = CGPoint(x: 0, y: 150)
        addChild(subLbl)

        let descLbl = SKLabelNode(fontNamed: "Courier")
        descLbl.text = L10n.tr("dialog.select_boosters", fallback: "Select boosters before you play:")
        descLbl.fontSize = 13
        descLbl.fontColor = UIColor(hex: "#7799CC")
        descLbl.verticalAlignmentMode = .center
        descLbl.position = CGPoint(x: 0, y: 118)
        addChild(descLbl)

        // Booster selection grid
        let boosters = BoosterType.allCases

        var yPos: CGFloat = 60
        for (i, type) in boosters.enumerated() {
            let xPos: CGFloat = (i % 2 == 0 ? -70 : 70)
            if i % 2 == 0 && i > 0 { yPos -= 90 }

            let container = SKNode()
            container.position = CGPoint(x: xPos, y: yPos)

            let bg = SKShapeNode(rectOf: CGSize(width: 120, height: 76), cornerRadius: 10)
            bg.fillColor = UIColor(hex: "#0F1E33")
            bg.strokeColor = UIColor(hex: "#1C3A5C")
            bg.lineWidth = 2
            bg.name = "boosterbg_\(type.name)"
            container.addChild(bg)


            let iconNode = SKSpriteNode(texture: PixelArt.shared.softIconTexture(type.artIcon, size: 34),
                                        size: CGSize(width: 30, height: 30))
            iconNode.position = CGPoint(x: 0, y: 14)
            container.addChild(iconNode)

            let nameLbl = SKLabelNode(fontNamed: "Courier")
            nameLbl.text = type.name
            nameLbl.fontSize = 11
            nameLbl.fontColor = UIColor(hex: "#AABBCC")
            nameLbl.verticalAlignmentMode = .center
            nameLbl.position = CGPoint(x: 0, y: -8)
            container.addChild(nameLbl)

            let count = countForBooster(type)
            let countLbl = SKLabelNode(fontNamed: "Courier-Bold")
            countLbl.text = "×\(count)"
            countLbl.fontSize = 12
            countLbl.fontColor = count > 0 ? UIColor(hex: "#FFCC00") : UIColor(hex: "#FF3B30")
            countLbl.verticalAlignmentMode = .center
            countLbl.position = CGPoint(x: 0, y: -24)
            container.addChild(countLbl)

            addChild(container)
            container.isUserInteractionEnabled = false

            let btn = BoosterSelectButton(type: type, container: container)
            btn.position = CGPoint(x: xPos, y: yPos)
            btn.isEnabled = count > 0
            btn.onToggle = { [weak self] selected in
                self?.selectedBoosters[type] = selected
            }
            addChild(btn)
        }

        let playBtn = PixelButton(title: L10n.tr("map.play", fallback: "▶ PLAY!"),
                                   icon: .play,
                                   size: CGSize(width: 240, height: 52),
                                   style: .primary,
                                   color: UIColor(hex: "#34C759"),
                                   fontSize: 22)
        playBtn.position = CGPoint(x: 0, y: -148)
        playBtn.onTap = { [weak self] in
            guard let self = self else { return }
            let selected = self.selectedBoosters.compactMap { $0.value ? $0.key : nil }
            self.onPlay?(selected)
        }
        addChild(playBtn)

        let closeBtn = PixelButton(icon: .close,
                                   size: CGSize(width: 36, height: 36),
                                   bgColor: UIColor(hex: "#1C2E4A"))
        closeBtn.position = CGPoint(x: 128, y: 185)
        closeBtn.onTap = { [weak self] in self?.onClose?() }
        addChild(closeBtn)
    }

    private func countForBooster(_ type: BoosterType) -> Int {
        switch type {
        case .hammer: return PlayerData.shared.hammerCount
        case .shuffle: return PlayerData.shared.shuffleCount
        case .extraMoves: return PlayerData.shared.extraMovesCount
        case .colorBomb: return PlayerData.shared.colorBombCount
        }
    }
}

// Inline booster toggle button helper
private final class BoosterSelectButton: SKNode {
    var onToggle: ((Bool) -> Void)?
    var isEnabled: Bool = true
    private var isSelected = false
    private let type: BoosterType
    private weak var container: SKNode?
    private let hitSize = CGSize(width: 120, height: 76)

    init(type: BoosterType, container: SKNode) {
        self.type = type
        self.container = container
        super.init()
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func contains(_ p: CGPoint) -> Bool {
        abs(p.x) <= hitSize.width / 2 && abs(p.y) <= hitSize.height / 2
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled else { return }
        if let touch = touches.first, !contains(touch.location(in: self)) { return }
        isSelected = !isSelected
        onToggle?(isSelected)

        if let bg = container?.childNode(withName: "boosterbg_\(type.name)") as? SKShapeNode {
            bg.strokeColor = isSelected ? UIColor(hex: "#FFCC00") : UIColor(hex: "#1C3A5C")
            bg.fillColor = isSelected ? UIColor(hex: "#1A2A0A") : UIColor(hex: "#0F1E33")
        }
        AudioManager.shared.play(.buttonTap)
        HapticsManager.shared.tap()
    }
}
