import SpriteKit

final class GameHUD: SKNode {
    static let contentHeight: CGFloat = 140
    static let boosterReservedHeight: CGFloat = 112

    // Callbacks
    var onPause: (() -> Void)?
    var onBoosterTap: ((BoosterType) -> Void)?

    private var movesLabel: SKLabelNode!
    private var scoreLabel: SKLabelNode!
    private var scoreValueLabel: SKLabelNode!
    private var movesValueLabel: SKLabelNode!
    private var progressBar: SKShapeNode!
    private var progressFill: SKShapeNode!
    private var objectiveNodes: [ObjectiveDisplayNode] = []
    private var boosterNodes: [BoosterButtonNode] = []
    private var pauseBtn: PixelButton!

    private var currentScore: Int = 0
    private var targetScore: Int = 1000
    private var currentMoves: Int = 0
    private var scoreValueMaxWidth: CGFloat = 90
    private var movesValueMaxWidth: CGFloat = 58

    init(level: Level, sceneSize: CGSize, safeAreaInsets: UIEdgeInsets, hudWorldY: CGFloat) {
        super.init()
        setupBackground(sceneSize: sceneSize, safeAreaInsets: safeAreaInsets)
        setupPauseButton(sceneSize: sceneSize, safeAreaInsets: safeAreaInsets)
        setupMovesDisplay(sceneSize: sceneSize)
        setupScoreDisplay(sceneSize: sceneSize, safeAreaInsets: safeAreaInsets)
        setupObjectives(level: level, sceneSize: sceneSize, safeAreaInsets: safeAreaInsets)
        setupBoosters(sceneSize: sceneSize, safeAreaInsets: safeAreaInsets, hudWorldY: hudWorldY)

        currentMoves = level.moves
        updateMovesDisplay()

        if case .score(let t) = level.objectives.first?.kind {
            targetScore = t
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupBackground(sceneSize: CGSize, safeAreaInsets: UIEdgeInsets) {
        let bgHeight = Self.contentHeight + safeAreaInsets.top
        let bg = SKShapeNode(rectOf: CGSize(width: sceneSize.width, height: bgHeight))
        bg.fillColor = UIColor(hex: "#0A1628").withAlphaComponent(0.95)
        bg.strokeColor = UIColor(hex: "#1C3A5C")
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: 0, y: safeAreaInsets.top / 2)
        bg.zPosition = -1
        addChild(bg)

        // Pixel top border decoration
        let border = SKSpriteNode(color: UIColor(hex: "#2255AA"), size: CGSize(width: sceneSize.width, height: 3))
        border.position = CGPoint(x: 0, y: -Self.contentHeight / 2)
        border.zPosition = 1
        addChild(border)
    }

    private func setupPauseButton(sceneSize: CGSize, safeAreaInsets: UIEdgeInsets) {
        let btn = PixelButton(icon: [[UInt8]]([
            [0,0,1,1,0,1,1,0],
            [0,0,1,1,0,1,1,0],
            [0,0,1,1,0,1,1,0],
            [0,0,1,1,0,1,1,0],
            [0,0,1,1,0,1,1,0],
            [0,0,1,1,0,1,1,0],
            [0,0,1,1,0,1,1,0],
            [0,0,0,0,0,0,0,0],
        ]), iconColor: .white, size: CGSize(width: 40, height: 40),
            bgColor: UIColor(hex: "#1C2E4A"))
        btn.position = CGPoint(x: -sceneSize.width/2 + safeAreaInsets.left + 32, y: 25)
        btn.zPosition = 10
        btn.onTap = { [weak self] in self?.onPause?() }
        addChild(btn)
        pauseBtn = btn
    }

    private func setupMovesDisplay(sceneSize: CGSize) {
        // Moves container
        let box = SKShapeNode(rectOf: CGSize(width: 70, height: 60), cornerRadius: 8)
        box.fillColor = UIColor(hex: "#1C2E4A")
        box.strokeColor = UIColor(hex: "#2255AA")
        box.lineWidth = 2
        box.position = CGPoint(x: 0, y: 20)
        addChild(box)

        let titleLbl = SKLabelNode(fontNamed: "Courier-Bold")
        titleLbl.text = "MOVES"
        titleLbl.fontSize = 10
        titleLbl.fontColor = UIColor(hex: "#7799CC")
        titleLbl.verticalAlignmentMode = .center
        titleLbl.position = CGPoint(x: 0, y: 35)
        addChild(titleLbl)

        let valLbl = SKLabelNode(fontNamed: "Courier-Bold")
        valLbl.text = "0"
        valLbl.fontSize = 32
        valLbl.fontColor = .white
        valLbl.verticalAlignmentMode = .center
        valLbl.position = CGPoint(x: 0, y: 20)
        addChild(valLbl)
        movesValueLabel = valLbl
    }

    private func setupScoreDisplay(sceneSize: CGSize, safeAreaInsets: UIEdgeInsets) {
        let movesRightEdge: CGFloat = 35
        let scoreLeftPadding: CGFloat = 14
        let scoreRightPadding: CGFloat = 16
        let scoreRightEdge = sceneSize.width / 2 - safeAreaInsets.right - scoreRightPadding
        let maxBarW = sceneSize.width * 0.34
        let availableBarW = scoreRightEdge - movesRightEdge - scoreLeftPadding
        let barW = max(72, min(maxBarW, availableBarW))
        let scoreX = scoreRightEdge - barW / 2
        scoreValueMaxWidth = barW

        let scoreLbl = SKLabelNode(fontNamed: "Courier-Bold")
        scoreLbl.text = "SCORE"
        scoreLbl.fontSize = 11
        scoreLbl.fontColor = UIColor(hex: "#7799CC")
        scoreLbl.verticalAlignmentMode = .center
        scoreLbl.position = CGPoint(x: scoreX, y: 40)
        addChild(scoreLbl)

        let valLbl = SKLabelNode(fontNamed: "Courier-Bold")
        valLbl.text = "0"
        valLbl.fontSize = 28
        valLbl.fontColor = UIColor(hex: "#FFCC00")
        valLbl.verticalAlignmentMode = .center
        valLbl.position = CGPoint(x: scoreX, y: 18)
        addChild(valLbl)
        scoreValueLabel = valLbl

        // Progress bar
        let barBg = SKShapeNode(rectOf: CGSize(width: barW, height: 10), cornerRadius: 5)
        barBg.fillColor = UIColor(hex: "#0A1628")
        barBg.strokeColor = UIColor(hex: "#2255AA")
        barBg.lineWidth = 1.5
        barBg.position = CGPoint(x: scoreX, y: -5)
        addChild(barBg)

        progressBar = barBg

        progressFill = SKShapeNode(rectOf: CGSize(width: 2, height: 8), cornerRadius: 4)
        progressFill.fillColor = UIColor(hex: "#FFCC00")
        progressFill.strokeColor = .clear
        progressFill.position = CGPoint(x: scoreX - barW/2 + 1, y: -5)
        addChild(progressFill)

        // Stars row
        for i in 0..<3 {
            let star = StarIconNode(size: 24)
            star.position = CGPoint(x: scoreX - 24 + CGFloat(i) * 24, y: -28)
            star.zPosition = 2
            star.name = "star_\(i)"
            addChild(star)
        }
    }

    private func setupObjectives(level: Level, sceneSize: CGSize, safeAreaInsets: UIEdgeInsets) {
        let itemWidth: CGFloat = 100
        let itemGap: CGFloat = 10
        let count = max(level.objectives.count, 1)
        let totalWidth = CGFloat(count) * itemWidth + CGFloat(max(count - 1, 0)) * itemGap
        let availableWidth = max(1, sceneSize.width - safeAreaInsets.left - safeAreaInsets.right - 20)
        let scale = min(1, availableWidth / totalWidth)
        let startX = -totalWidth * scale / 2 + itemWidth * scale / 2
        let y: CGFloat = -50

        for (idx, obj) in level.objectives.enumerated() {
            let node = ObjectiveDisplayNode(objective: obj)
            node.setScale(scale)
            node.position = CGPoint(x: startX + CGFloat(idx) * (itemWidth + itemGap) * scale, y: y)
            addChild(node)
            objectiveNodes.append(node)
        }
    }

    private func setupBoosters(sceneSize: CGSize, safeAreaInsets: UIEdgeInsets, hudWorldY: CGFloat) {
        let types = BoosterType.allCases
        let availableWidth = max(1, sceneSize.width - safeAreaInsets.left - safeAreaInsets.right - 40)
        let spacing = min(60, max(48, availableWidth / CGFloat(types.count)))
        let startX = -CGFloat(types.count - 1) * spacing / 2
        let boosterWorldY = -sceneSize.height / 2 + safeAreaInsets.bottom + 68
        let boosterLocalY = boosterWorldY - hudWorldY
        let scale = min(1, availableWidth / 240)

        for (i, type) in types.enumerated() {
            let node = BoosterButtonNode(type: type)
            node.position = CGPoint(x: startX + CGFloat(i) * spacing, y: boosterLocalY)
            node.setScale(scale)
            node.onTap = { [weak self] in self?.onBoosterTap?(type) }
            addChild(node)
            boosterNodes.append(node)
        }
    }

    // MARK: - Updates

    func updateScore(_ score: Int) {
        currentScore = score
        scoreValueLabel.text = score.scoreFormatted
        let fittedScale = fitLabel(scoreValueLabel, maxWidth: scoreValueMaxWidth, minScale: 0.58)
        scoreValueLabel.run(.sequence([
            .scale(to: min(1.0, fittedScale * 1.15), duration: 0.07),
            .scale(to: fittedScale, duration: 0.07)
        ]))
        updateScoreProgress()
    }

    func updateMoves(_ moves: Int) {
        currentMoves = moves
        updateMovesDisplay()
    }

    private func updateMovesDisplay() {
        movesValueLabel.text = "\(currentMoves)"
        let fittedScale = fitLabel(movesValueLabel, maxWidth: movesValueMaxWidth, minScale: 0.72)
        if currentMoves <= 3 {
            movesValueLabel.fontColor = UIColor(hex: "#FF3B30")
            movesValueLabel.run(.repeatForever(.sequence([
                .scale(to: min(1.0, fittedScale * 1.1), duration: 0.4),
                .scale(to: fittedScale, duration: 0.4)
            ])), withKey: "pulse")
        } else {
            movesValueLabel.fontColor = .white
            movesValueLabel.removeAction(forKey: "pulse")
        }
    }

    private var progressBarMaxWidth: CGFloat = 0

    private func updateScoreProgress() {
        if progressBarMaxWidth == 0 {
            guard let barRect = progressBar.path?.boundingBox else { return }
            progressBarMaxWidth = barRect.width - 2
        }
        let maxW = progressBarMaxWidth
        let progress = min(1.0, CGFloat(currentScore) / CGFloat(targetScore))
        let fillW = max(2, progress * maxW)

        let newPath = UIBezierPath(roundedRect:
            CGRect(x: 0, y: -4, width: fillW, height: 8), cornerRadius: 4).cgPath
        progressFill.path = newPath

        // Color transition
        if progress >= 1.0 {
            progressFill.fillColor = UIColor(hex: "#34C759")
            progressFill.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.6, duration: 0.3),
                .fadeAlpha(to: 1.0, duration: 0.3)
            ])), withKey: "glow")
        } else if progress >= 0.6 {
            progressFill.fillColor = UIColor(hex: "#FF9500")
        } else {
            progressFill.fillColor = UIColor(hex: "#FFCC00")
        }

        // Update stars
        let s1 = progress >= 0.5, s2 = progress >= 0.75
        let starStates = [true, s1, s2]
        for (i, lit) in starStates.enumerated() {
            (childNode(withName: "star_\(i)") as? StarIconNode)?.setLit(lit)
        }
    }

    func updateObjective(_ index: Int, progress: Int) {
        guard index < objectiveNodes.count else { return }
        objectiveNodes[index].update(progress: progress)
    }

    func updateBoosterCounts() {
        boosterNodes.forEach { $0.refreshCount() }
    }

    func animateScoreAdd(_ amount: Int, at worldPos: CGPoint) {
        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = "+\(amount)"
        lbl.fontSize = 22
        lbl.fontColor = UIColor(hex: "#FFCC00")
        lbl.verticalAlignmentMode = .center
        lbl.position = worldPos
        lbl.zPosition = 50
        parent?.addChild(lbl)

        lbl.run(.sequence([
            .group([
                .moveBy(x: CGFloat.random(in: -20...20), y: 50, duration: 0.6),
                .sequence([.fadeAlpha(to: 1, duration: 0.1), .fadeOut(withDuration: 0.5)])
            ]),
            .removeFromParent()
        ]))
    }

    @discardableResult
    private func fitLabel(_ label: SKLabelNode, maxWidth: CGFloat, minScale: CGFloat) -> CGFloat {
        // HUD 数值会持续变化，先收进指定宽度再做动画，防止步数和分数互相压住。
        label.removeAction(forKey: "pulse")
        label.setScale(1)
        let width = max(label.frame.width, 1)
        let scale = width > maxWidth ? max(minScale, maxWidth / width) : 1
        label.setScale(scale)
        return scale
    }
}

// MARK: - Sub-nodes

final class StarIconNode: SKNode {
    private let filled: SKSpriteNode
    private let empty: SKSpriteNode
    private var isLit = false

    init(size: CGFloat) {
        let fillTex = PixelArt.shared.iconTexture(pixels: PixelIcons.starIcon,
                                                   primary: UIColor(hex: "#FFCC00"),
                                                   light: UIColor.white,
                                                   dark: UIColor(hex: "#CC8800"),
                                                   size: size)
        let emptyTex = PixelArt.shared.iconTexture(pixels: PixelIcons.starIcon,
                                                    primary: UIColor(hex: "#334466"),
                                                    light: UIColor(hex: "#445577"),
                                                    dark: UIColor(hex: "#223355"),
                                                    size: size)
        filled = SKSpriteNode(texture: fillTex, size: CGSize(width: size, height: size))
        empty  = SKSpriteNode(texture: emptyTex, size: CGSize(width: size, height: size))
        super.init()
        addChild(empty)
        addChild(filled)
        filled.alpha = 0
    }
    required init?(coder: NSCoder) { fatalError() }

    func setLit(_ lit: Bool, animated: Bool = true) {
        guard isLit != lit else { return }
        isLit = lit
        if lit {
            filled.run(.sequence([
                .fadeIn(withDuration: 0.15),
                .scale(to: 1.3, duration: 0.1),
                .scale(to: 1.0, duration: 0.1)
            ]))
            AudioManager.shared.play(.starEarn)
        } else {
            filled.alpha = 0
        }
    }
}

final class ObjectiveDisplayNode: SKNode {
    private let iconNode: SKSpriteNode
    private let progressLabel: SKLabelNode
    private var obj: LevelObjective

    init(objective: LevelObjective) {
        self.obj = objective

        let color: UIColor
        var iconPixels = PixelIcons.starIcon
        switch objective.kind {
        case .score:
            color = UIColor(hex: "#FFCC00"); iconPixels = PixelIcons.starIcon
        case .collect(let c, _):
            color = c.primary; iconPixels = gemIconPixels(for: c)
        case .clearAllJelly:
            color = UIColor(hex: "#FF69B4"); iconPixels = PixelIcons.jelly
        case .breakIce:
            color = UIColor(hex: "#87CEEB"); iconPixels = PixelIcons.ice
        case .eliminateChocolate:
            color = UIColor(hex: "#8B4513"); iconPixels = PixelIcons.hammer
        }

        iconNode = SKSpriteNode(texture: PixelArt.shared.iconTexture(pixels: iconPixels,
                                                                      primary: color,
                                                                      light: color.lighter(),
                                                                      dark: color.darker(),
                                                                      size: 28),
                                size: CGSize(width: 28, height: 28))
        iconNode.position = CGPoint(x: 0, y: 10)

        progressLabel = SKLabelNode(fontNamed: "Courier-Bold")
        progressLabel.fontSize = 13
        progressLabel.fontColor = .white
        progressLabel.verticalAlignmentMode = .center
        progressLabel.text = objective.displayText

        super.init()
        let bg = SKShapeNode(rectOf: CGSize(width: 100, height: 55), cornerRadius: 6)
        bg.fillColor = UIColor(hex: "#0F1E33")
        bg.strokeColor = UIColor(hex: "#1C3A5C")
        bg.lineWidth = 1.5
        addChild(bg)
        addChild(iconNode)
        progressLabel.position = CGPoint(x: 0, y: -12)
        addChild(progressLabel)
        fitProgressText()
    }
    required init?(coder: NSCoder) { fatalError() }

    func update(progress: Int) {
        var updated = obj
        updated.progress = progress
        obj = updated
        progressLabel.text = updated.displayText
        fitProgressText()
        if updated.isComplete {
            iconNode.run(.repeatForever(.sequence([
                .scale(to: 1.2, duration: 0.4),
                .scale(to: 1.0, duration: 0.4)
            ])), withKey: "complete")
            progressLabel.fontColor = UIColor(hex: "#34C759")
        }
    }

    private func fitProgressText() {
        // 目标数字会变长，限制在目标卡片内部，避免压到相邻目标。
        progressLabel.setScale(1)
        let maxWidth: CGFloat = 84
        let width = max(progressLabel.frame.width, 1)
        if width > maxWidth {
            progressLabel.setScale(max(0.68, maxWidth / width))
        }
    }
}

private func gemIconPixels(for color: GemColor) -> [[UInt8]] {
    switch color {
    case .red: return PixelIcons.flame
    case .blue: return PixelIcons.drop
    case .green: return PixelIcons.leaf
    case .yellow: return PixelIcons.star
    case .purple: return PixelIcons.bolt
    case .orange: return PixelIcons.sun
    }
}

final class BoosterButtonNode: SKNode {
    var onTap: (() -> Void)?
    private let type: BoosterType
    private let countLabel: SKLabelNode
    private let btn: PixelButton

    init(type: BoosterType) {
        self.type = type

        btn = PixelButton(icon: type.iconPixels,
                          iconColor: .white,
                          size: CGSize(width: 52, height: 52),
                          bgColor: UIColor(hex: "#1C2E4A"))

        countLabel = SKLabelNode(fontNamed: "Courier-Bold")
        countLabel.fontSize = 13
        countLabel.fontColor = UIColor(hex: "#FFCC00")
        countLabel.verticalAlignmentMode = .center
        countLabel.position = CGPoint(x: 0, y: -35)

        super.init()
        addChild(btn)
        addChild(countLabel)

        btn.onTap = { [weak self] in self?.onTap?() }
        isUserInteractionEnabled = true

        let nameLbl = SKLabelNode(fontNamed: "Courier")
        nameLbl.text = type.name
        nameLbl.fontSize = 9
        nameLbl.fontColor = UIColor(hex: "#7799CC")
        nameLbl.verticalAlignmentMode = .center
        nameLbl.position = CGPoint(x: 0, y: -46)
        addChild(nameLbl)

        refreshCount()
    }
    required init?(coder: NSCoder) { fatalError() }

    func refreshCount() {
        let count: Int
        switch type {
        case .hammer: count = PlayerData.shared.hammerCount
        case .shuffle: count = PlayerData.shared.shuffleCount
        case .extraMoves: count = PlayerData.shared.extraMovesCount
        case .colorBomb: count = PlayerData.shared.colorBombCount
        }
        countLabel.text = "×\(count)"
        alpha = count > 0 ? 1.0 : 0.4
    }
}
