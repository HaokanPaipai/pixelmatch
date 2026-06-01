import SpriteKit

final class TutorialScene: SKScene {

    private var step = 0
    private var boardNode: BoardNode!
    private var board: Board!
    private var tutorialState: GameState = .idle
    private var selectedPos: (row: Int, col: Int)?
    private var touchStartPos: CGPoint?
    private var touchStartBoardPos: (row: Int, col: Int)?

    private let steps: [(title: String, message: String)] = [
        (L10n.tr("tutorial.welcome.title", fallback: "WELCOME!"), L10n.tr("tutorial.welcome.message", fallback: "Swap adjacent gems. Match 3 to clear space and build score.")),
        (L10n.tr("tutorial.make4.title", fallback: "MAKE 4"), L10n.tr("tutorial.make4.message", fallback: "Match 4 to create a striped gem. Match it again to clear a full line.")),
        (L10n.tr("tutorial.make5.title", fallback: "MAKE 5"), L10n.tr("tutorial.make5.message", fallback: "Match 5 to create a color bomb. Swap it with a color to clear that color.")),
        (L10n.tr("tutorial.combos.title", fallback: "COMBOS"), L10n.tr("tutorial.combos.message", fallback: "Swap two special gems together for a bigger board-clearing effect.")),
        (L10n.tr("tutorial.objectives.title", fallback: "OBJECTIVES"), L10n.tr("tutorial.objectives.message", fallback: "Every level has a goal. Spend each move toward that goal."))
    ]

    private var overlayNode: SKNode!
    private var messagePanel: SKNode!
    private var msgLabel: SKLabelNode!
    private var titleLabel: SKLabelNode!
    private var nextBtn: PixelButton!
    private var skipBtn: PixelButton!
    private var highlightRing: SKShapeNode!
    private var handNode: SKNode!
    private var safeAreaInsets: UIEdgeInsets = .zero
    private var safeTopY: CGFloat { size.height / 2 - safeAreaInsets.top }
    private var safeBottomY: CGFloat { -size.height / 2 + safeAreaInsets.bottom }

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        size = view.bounds.size
        safeAreaInsets = view.safeAreaInsets
        backgroundColor = UIColor(hex: "#0A1628")
        setupBackground()
        setupTutorialBoard()
        setupUI()
        showStep(0)
    }

    private func setupBackground() {
        let world = GameWorlds[0]
        let bgTex = PixelArt.shared.worldBgTexture(world: world, size: size)
        let bg = SKSpriteNode(texture: bgTex, size: size)
        bg.zPosition = -10
        addChild(bg)

        let gridSize: CGFloat = 40
        let cols = Int(size.width / gridSize) + 1
        let rows = Int(size.height / gridSize) + 1
        let gridNode = SKNode()
        gridNode.zPosition = -9
        for r in 0..<rows {
            let line = SKShapeNode(rectOf: CGSize(width: size.width, height: 1))
            line.fillColor = UIColor.white.withAlphaComponent(0.025)
            line.strokeColor = .clear
            line.position = CGPoint(x: 0, y: -size.height/2 + CGFloat(r) * gridSize)
            gridNode.addChild(line)
        }
        for c in 0..<cols {
            let line = SKShapeNode(rectOf: CGSize(width: 1, height: size.height))
            line.fillColor = UIColor.white.withAlphaComponent(0.025)
            line.strokeColor = .clear
            line.position = CGPoint(x: -size.width/2 + CGFloat(c) * gridSize, y: 0)
            gridNode.addChild(line)
        }
        addChild(gridNode)
    }

    private func setupTutorialBoard() {
        let level = LevelData.all[0]
        board = Board(rows: 5, cols: 5, availableColors: [.red, .blue, .green, .yellow, .purple])
        board.setup(from: level)

        boardNode = BoardNode(board: board, world: level.world)
        let panelTop = safeBottomY + 222
        let playableTop = safeTopY - 24
        boardNode.position = CGPoint(x: 0, y: (playableTop + panelTop) / 2)
        boardNode.zPosition = 1
        addChild(boardNode)

        boardNode.alpha = 0
        boardNode.run(.fadeIn(withDuration: 0.5))
    }

    private func setupUI() {
        // Dark overlay for message panel
        overlayNode = SKNode()
        overlayNode.zPosition = 20
        addChild(overlayNode)

        // Semi-transparent bottom panel
        messagePanel = SKNode()
        messagePanel.zPosition = 25
        addChild(messagePanel)

        let panelHeight: CGFloat = 210
        let panelBottom = safeBottomY + 12
        let panelTop = panelBottom + panelHeight
        let panelCenterY = panelBottom + panelHeight / 2
        let panelWidth = size.width - safeAreaInsets.left - safeAreaInsets.right - 24
        let panelBg = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 16)
        panelBg.fillColor = UIColor(hex: "#0A1628").withAlphaComponent(0.96)
        panelBg.strokeColor = UIColor(hex: "#334466")
        panelBg.lineWidth = 2
        panelBg.position = CGPoint(x: 0, y: panelCenterY)
        messagePanel.addChild(panelBg)

        // Pixel art mascot (colored pixel face)
        let mascot = buildMascotNode()
        mascot.position = CGPoint(x: -size.width/2 + safeAreaInsets.left + 70, y: panelBottom + 52)
        mascot.zPosition = 26
        addChild(mascot)

        titleLabel = SKLabelNode(fontNamed: "Courier-Bold")
        titleLabel.fontSize = 18
        titleLabel.fontColor = UIColor(hex: "#FFCC00")
        titleLabel.verticalAlignmentMode = .top
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 20, y: panelTop - 15)
        titleLabel.zPosition = 26
        addChild(titleLabel)

        msgLabel = SKLabelNode(fontNamed: "Courier")
        msgLabel.fontSize = 14
        msgLabel.fontColor = UIColor(hex: "#AABBCC")
        msgLabel.verticalAlignmentMode = .top
        msgLabel.horizontalAlignmentMode = .center
        msgLabel.numberOfLines = 4
        msgLabel.preferredMaxLayoutWidth = panelWidth - 56
        msgLabel.position = CGPoint(x: 20, y: panelTop - 40)
        msgLabel.zPosition = 26
        addChild(msgLabel)

        nextBtn = PixelButton(title: L10n.tr("tutorial.next", fallback: "NEXT ▶"),
                              icon: .play,
                              size: CGSize(width: 160, height: 44),
                              style: .primary,
                              color: UIColor(hex: "#34C759"))
        nextBtn.position = CGPoint(x: 60, y: panelBottom + 38)
        nextBtn.zPosition = 26
        nextBtn.onTap = { [weak self] in self?.advance() }
        addChild(nextBtn)

        skipBtn = PixelButton(title: L10n.tr("tutorial.skip", fallback: "SKIP"),
                              size: CGSize(width: 100, height: 36),
                              style: .ghost,
                              color: UIColor(hex: "#7799CC"),
                              fontSize: 14)
        skipBtn.position = CGPoint(x: -size.width/2 + safeAreaInsets.left + 64, y: panelBottom + 38)
        skipBtn.zPosition = 26
        skipBtn.onTap = { [weak self] in self?.finishTutorial() }
        addChild(skipBtn)

        // Hand pointer for interactive demonstrations
        handNode = buildHandNode()
        handNode.zPosition = 30
        handNode.alpha = 0
        addChild(handNode)

        // Highlight ring for tile focus
        highlightRing = SKShapeNode(circleOfRadius: 30)
        highlightRing.strokeColor = UIColor(hex: "#FFCC00")
        highlightRing.fillColor = UIColor(hex: "#FFCC00").withAlphaComponent(0.15)
        highlightRing.lineWidth = 3
        highlightRing.zPosition = 15
        highlightRing.alpha = 0
        addChild(highlightRing)
    }

    private func buildMascotNode() -> SKNode {
        let container = SKNode()
        let pixels: [[UInt8]] = [
            [0,1,1,1,1,1,1,0],
            [1,1,1,1,1,1,1,1],
            [1,0,1,1,1,1,0,1],
            [1,0,1,1,1,1,0,1],
            [1,1,1,0,0,1,1,1],
            [1,1,0,1,1,0,1,1],
            [1,1,1,1,1,1,1,1],
            [0,1,1,1,1,1,1,0]
        ]
        let tex = PixelArt.shared.iconTexture(pixels: pixels,
                                               primary: UIColor(hex: "#FFCC00"),
                                               light: UIColor(hex: "#FFE066"),
                                               dark: UIColor(hex: "#CC9900"),
                                               size: 48)
        let sprite = SKSpriteNode(texture: tex, size: CGSize(width: 48, height: 48))
        container.addChild(sprite)
        container.run(.repeatForever(.sequence([
            .scale(to: 1.05, duration: 0.6),
            .scale(to: 1.0, duration: 0.6)
        ])))
        return container
    }

    private func buildHandNode() -> SKNode {
        let hand = SKNode()
        let pixels: [[UInt8]] = [
            [0,0,0,1,1,0,0,0],
            [0,0,1,1,1,1,0,0],
            [0,0,1,1,1,1,0,0],
            [0,0,1,1,1,1,0,0],
            [1,1,1,1,1,1,1,0],
            [1,1,1,1,1,1,1,1],
            [0,1,1,1,1,1,1,1],
            [0,0,1,1,1,1,1,0]
        ]
        let tex = PixelArt.shared.iconTexture(pixels: pixels,
                                               primary: .white,
                                               light: UIColor(hex: "#DDDDFF"),
                                               dark: UIColor(hex: "#999999"),
                                               size: 40)
        let sprite = SKSpriteNode(texture: tex, size: CGSize(width: 40, height: 40))
        hand.addChild(sprite)
        return hand
    }

    private func showStep(_ index: Int) {
        guard index < steps.count else { finishTutorial(); return }
        step = index

        let info = steps[index]
        titleLabel.text = info.title
        msgLabel.text = info.message

        let isLast = index == steps.count - 1
        nextBtn.setTitle(isLast ? L10n.tr("tutorial.play", fallback: "PLAY!") : L10n.tr("tutorial.next", fallback: "NEXT ▶"))

        // Animate panel pop-in
        messagePanel.setScale(0.95)
        messagePanel.run(.scale(to: 1.0, duration: 0.15))

        // Demonstrate based on step
        highlightRing.alpha = 0
        handNode.alpha = 0
        handNode.removeAllActions()

        switch index {
        case 0: demonstrateSwap()
        case 1: highlightSpecialRow()
        case 2: highlightCenter()
        default: break
        }
    }

    private func demonstrateSwap() {
        // Animate hand showing a swap gesture
        let startTilePos = boardNode.tilePos(row: 2, col: 1)
        let endTilePos   = boardNode.tilePos(row: 2, col: 2)
        let startScene   = convert(startTilePos, from: boardNode)
        let endScene     = convert(endTilePos, from: boardNode)

        handNode.position = CGPoint(x: startScene.x - 10, y: startScene.y - 20)
        handNode.alpha = 1

        highlightRing.position = startScene
        highlightRing.alpha = 1

        handNode.run(.repeatForever(.sequence([
            .move(to: CGPoint(x: startScene.x - 10, y: startScene.y - 20), duration: 0),
            .wait(forDuration: 0.4),
            .move(to: CGPoint(x: endScene.x - 10, y: endScene.y - 20), duration: 0.5),
            .wait(forDuration: 0.6),
            .fadeOut(withDuration: 0.15),
            .wait(forDuration: 0.3),
            .fadeIn(withDuration: 0.15)
        ])))

        highlightRing.run(.repeatForever(.sequence([
            .move(to: startScene, duration: 0),
            .wait(forDuration: 0.4),
            .move(to: endScene, duration: 0.5),
            .wait(forDuration: 0.6),
            .move(to: startScene, duration: 0)
        ])))
    }

    private func highlightSpecialRow() {
        let rowMid = boardNode.tilePos(row: 1, col: 2)
        let pos = convert(rowMid, from: boardNode)

        let ring = SKShapeNode(rectOf: CGSize(width: boardNode.boardSize.width + 10, height: 54), cornerRadius: 8)
        ring.strokeColor = UIColor(hex: "#FF9500")
        ring.fillColor = UIColor(hex: "#FF9500").withAlphaComponent(0.1)
        ring.lineWidth = 3
        ring.position = pos
        ring.zPosition = 15
        ring.name = "stepHighlight"
        addChild(ring)

        ring.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.4, duration: 0.5),
            .fadeAlpha(to: 1.0, duration: 0.5)
        ])))
    }

    private func highlightCenter() {
        let center = boardNode.tilePos(row: 2, col: 2)
        let pos = convert(center, from: boardNode)
        highlightRing.position = pos
        highlightRing.setScale(1.5)
        highlightRing.alpha = 1
        highlightRing.run(.repeatForever(.sequence([
            .scale(to: 1.8, duration: 0.6),
            .scale(to: 1.5, duration: 0.6)
        ])))
    }

    private func advance() {
        AudioManager.shared.play(.buttonTap)
        HapticsManager.shared.tap()
        childNode(withName: "stepHighlight")?.removeFromParent()
        showStep(step + 1)
    }

    private func finishTutorial() {
        AudioManager.shared.play(.buttonTap)
        PlayerData.shared.setTutorialComplete()

        guard let view = view else { return }
        let scene = MapScene(size: size)
        scene.scaleMode = .aspectFill
        view.presentScene(scene, transition: .fade(withDuration: 0.5))
    }
}
