import SpriteKit

// MARK: - Base Dialog

class DialogNode: SKNode {

    let panel: SKShapeNode
    let sceneSize: CGSize

    init(size: CGSize, sceneSize: CGSize) {
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
        addPixelTitle("⏸ PAUSED", y: 140)

        // Pixel decoration
        for i in 0...5 {
            let sq = SKShapeNode(rectOf: CGSize(width: 8, height: 8))
            sq.fillColor = GemColor(rawValue: i)!.primary
            sq.strokeColor = .clear
            sq.position = CGPoint(x: -100 + CGFloat(i) * 40, y: 110)
            addChild(sq)
        }

        let resumeBtn = PixelButton(title: "▶ RESUME", size: CGSize(width: 220, height: 48),
                                    style: .primary, color: UIColor(hex: "#34C759"))
        resumeBtn.position = CGPoint(x: 0, y: 55)
        resumeBtn.onTap = { [weak self] in self?.onResume?() }
        addChild(resumeBtn)

        let restartBtn = PixelButton(title: "↺ RESTART", size: CGSize(width: 220, height: 48),
                                     style: .primary, color: UIColor(hex: "#FF9500"))
        restartBtn.position = CGPoint(x: 0, y: -5)
        restartBtn.onTap = { [weak self] in self?.onRestart?() }
        addChild(restartBtn)

        let settingsBtn = PixelButton(title: "⚙ SETTINGS", size: CGSize(width: 220, height: 48),
                                      style: .secondary)
        settingsBtn.position = CGPoint(x: 0, y: -65)
        settingsBtn.onTap = { [weak self] in self?.onSettings?() }
        addChild(settingsBtn)

        let quitBtn = PixelButton(title: "✕ QUIT", size: CGSize(width: 220, height: 48),
                                   style: .danger)
        quitBtn.position = CGPoint(x: 0, y: -125)
        quitBtn.onTap = { [weak self] in self?.onQuit?() }
        addChild(quitBtn)
    }
}

// MARK: - Out of Moves Dialog

final class OutOfMovesDialog: DialogNode {

    var onContinue: (() -> Void)?  // spend diamonds
    var onQuit: (() -> Void)?

    init(sceneSize: CGSize, movesCount: Int = 5, diamondCost: Int = 10) {
        super.init(size: CGSize(width: 300, height: 340), sceneSize: sceneSize)
        buildUI(moves: movesCount, cost: diamondCost)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(moves: Int, cost: Int) {
        addPixelTitle("OUT OF MOVES!", y: 130, color: UIColor(hex: "#FF3B30"))

        let msgLbl = SKLabelNode(fontNamed: "Courier")
        msgLbl.text = "Continue with +\(moves) moves?"
        msgLbl.fontSize = 16
        msgLbl.fontColor = UIColor(hex: "#99BBCC")
        msgLbl.verticalAlignmentMode = .center
        msgLbl.position = CGPoint(x: 0, y: 75)
        addChild(msgLbl)

        // Diamond icon + cost
        let diamonds = PlayerData.shared.diamonds
        let canAfford = diamonds >= cost
        let diamondTex = PixelArt.shared.iconTexture(pixels: PixelIcons.diamond,
                                                     primary: UIColor(hex: "#AF52DE"),
                                                     light: UIColor(hex: "#DDA0FF"),
                                                     dark: UIColor(hex: "#7711CC"),
                                                     size: 32)
        let dIcon = SKSpriteNode(texture: diamondTex, size: CGSize(width: 32, height: 32))
        dIcon.position = CGPoint(x: -25, y: 20)
        addChild(dIcon)

        let costLbl = SKLabelNode(fontNamed: "Courier-Bold")
        costLbl.text = "×\(cost)"
        costLbl.fontSize = 26
        costLbl.fontColor = canAfford ? UIColor(hex: "#AF52DE") : UIColor(hex: "#FF3B30")
        costLbl.verticalAlignmentMode = .center
        costLbl.position = CGPoint(x: 15, y: 20)
        addChild(costLbl)

        let haveLbl = SKLabelNode(fontNamed: "Courier")
        haveLbl.text = "You have: \(diamonds) 💎"
        haveLbl.fontSize = 14
        haveLbl.fontColor = UIColor(hex: "#7799CC")
        haveLbl.verticalAlignmentMode = .center
        haveLbl.position = CGPoint(x: 0, y: -20)
        addChild(haveLbl)

        let continueBtn = PixelButton(title: canAfford ? "CONTINUE!" : "GET DIAMONDS",
                                      size: CGSize(width: 240, height: 52),
                                      style: .primary,
                                      color: canAfford ? UIColor(hex: "#AF52DE") : UIColor(hex: "#FF9500"))
        continueBtn.position = CGPoint(x: 0, y: -75)
        continueBtn.onTap = { [weak self] in self?.onContinue?() }
        addChild(continueBtn)

        let quitBtn = PixelButton(title: "NO THANKS", size: CGSize(width: 240, height: 44),
                                   style: .ghost, color: UIColor(hex: "#7799CC"))
        quitBtn.position = CGPoint(x: 0, y: -135)
        quitBtn.onTap = { [weak self] in self?.onQuit?() }
        addChild(quitBtn)
    }
}

// MARK: - No Lives Dialog

final class NoLivesDialog: DialogNode {

    var onRefillWithDiamonds: (() -> Void)?
    var onWaitForFree: (() -> Void)?
    var onClose: (() -> Void)?

    init(sceneSize: CGSize) {
        super.init(size: CGSize(width: 300, height: 360), sceneSize: sceneSize)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        addPixelTitle("NO LIVES!", y: 140, color: UIColor(hex: "#FF3B30"))

        // Broken hearts
        for i in 0..<5 {
            let tex = PixelArt.shared.iconTexture(pixels: PixelIcons.heart,
                                                  primary: UIColor(hex: "#CC1111"),
                                                  light: UIColor(hex: "#FF6666"),
                                                  dark: UIColor(hex: "#880000"),
                                                  size: 28)
            let h = SKSpriteNode(texture: tex, size: CGSize(width: 28, height: 28))
            h.position = CGPoint(x: -56 + CGFloat(i) * 28, y: 95)
            h.alpha = 0.3
            addChild(h)
        }

        // Timer
        let nextLbl = SKLabelNode(fontNamed: "Courier-Bold")
        nextLbl.text = "Next life in: \(LivesManager.shared.timeUntilNextLifeString)"
        nextLbl.fontSize = 16
        nextLbl.fontColor = UIColor(hex: "#7799CC")
        nextLbl.verticalAlignmentMode = .center
        nextLbl.position = CGPoint(x: 0, y: 50)
        nextLbl.name = "timer"
        addChild(nextLbl)

        // Refill button
        let refillBtn = PixelButton(title: "REFILL (15 💎)",
                                    size: CGSize(width: 240, height: 52),
                                    style: .primary,
                                    color: UIColor(hex: "#AF52DE"))
        refillBtn.position = CGPoint(x: 0, y: -20)
        refillBtn.onTap = { [weak self] in self?.onRefillWithDiamonds?() }
        addChild(refillBtn)

        let waitBtn = PixelButton(title: "WAIT FOR FREE LIFE",
                                   size: CGSize(width: 240, height: 48),
                                   style: .secondary)
        waitBtn.position = CGPoint(x: 0, y: -80)
        waitBtn.onTap = { [weak self] in self?.onWaitForFree?() }
        addChild(waitBtn)

        let closeBtn = PixelButton(title: "CLOSE", size: CGSize(width: 240, height: 44),
                                   style: .ghost, color: UIColor(hex: "#7799CC"))
        closeBtn.position = CGPoint(x: 0, y: -140)
        closeBtn.onTap = { [weak self] in self?.onClose?() }
        addChild(closeBtn)
    }
}

// MARK: - Settings Dialog

final class SettingsDialog: DialogNode {

    var onClose: (() -> Void)?

    init(sceneSize: CGSize) {
        super.init(size: CGSize(width: 300, height: 320), sceneSize: sceneSize)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        addPixelTitle("⚙ SETTINGS", y: 130)

        func toggle(label: String, yPos: CGFloat, value: Bool, onToggle: @escaping (Bool) -> Void) {
            let lbl = SKLabelNode(fontNamed: "Courier-Bold")
            lbl.text = label
            lbl.fontSize = 16
            lbl.fontColor = .white
            lbl.verticalAlignmentMode = .center
            lbl.horizontalAlignmentMode = .left
            lbl.position = CGPoint(x: -120, y: yPos)
            addChild(lbl)

            let state = value
            let toggleBtn = PixelButton(title: state ? "ON" : "OFF",
                                        size: CGSize(width: 70, height: 32),
                                        style: .primary,
                                        color: state ? UIColor(hex: "#34C759") : UIColor(hex: "#555"))
            toggleBtn.position = CGPoint(x: 90, y: yPos)
            toggleBtn.onTap = {
                let newState = !state
                onToggle(newState)
                toggleBtn.setTitle(newState ? "ON" : "OFF")
            }
            addChild(toggleBtn)
        }

        toggle(label: "🔊 Sound", yPos: 65,
               value: PlayerData.shared.soundEnabled) { PlayerData.shared.soundEnabled = $0 }
        toggle(label: "🎵 Music", yPos: 15,
               value: PlayerData.shared.musicEnabled) { enabled in
            PlayerData.shared.musicEnabled = enabled
            AudioManager.shared.setMusicEnabled(enabled)
        }
        toggle(label: "📳 Vibrate", yPos: -35,
               value: PlayerData.shared.vibrateEnabled) { PlayerData.shared.vibrateEnabled = $0 }

        let closeBtn = PixelButton(title: "CLOSE",
                                   size: CGSize(width: 240, height: 48),
                                   style: .primary,
                                   color: UIColor(hex: "#007AFF"))
        closeBtn.position = CGPoint(x: 0, y: -120)
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
        addPixelTitle("POWER UP!", y: 182, color: UIColor(hex: "#FFCC00"))

        let subLbl = SKLabelNode(fontNamed: "Courier")
        subLbl.text = level.displayName
        subLbl.fontSize = 14
        subLbl.fontColor = UIColor(hex: level.world?.themeColorHex ?? "#FFFFFF")
        subLbl.verticalAlignmentMode = .center
        subLbl.position = CGPoint(x: 0, y: 150)
        addChild(subLbl)

        let descLbl = SKLabelNode(fontNamed: "Courier")
        descLbl.text = "Select boosters before you play:"
        descLbl.fontSize = 13
        descLbl.fontColor = UIColor(hex: "#7799CC")
        descLbl.verticalAlignmentMode = .center
        descLbl.position = CGPoint(x: 0, y: 118)
        addChild(descLbl)

        // Booster selection grid
        let boosters: [(BoosterType, String)] = [
            (.hammer, "🔨"),
            (.shuffle, "🔀"),
            (.extraMoves, "+5"),
            (.colorBomb, "💥")
        ]

        var yPos: CGFloat = 60
        for (i, (type, icon)) in boosters.enumerated() {
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


            let iconLbl = SKLabelNode(fontNamed: "Courier-Bold")
            iconLbl.text = icon
            iconLbl.fontSize = 24
            iconLbl.verticalAlignmentMode = .center
            iconLbl.position = CGPoint(x: 0, y: 12)
            container.addChild(iconLbl)

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

        let playBtn = PixelButton(title: "▶ PLAY!",
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

        let closeBtn = PixelButton(title: "✕", size: CGSize(width: 36, height: 36),
                                    style: .ghost, color: UIColor(hex: "#7799CC"), fontSize: 16)
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
