import SpriteKit

final class LoadingScene: SKScene {

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        size = view.bounds.size
        backgroundColor = UIColor(hex: "#050D1A")
        setupUI()
        animateAndTransition()
    }

    private func setupUI() {
        // Background pixel grid
        let gridAlpha: CGFloat = 0.04
        let gridSpacing: CGFloat = 30
        let cols = Int(size.width / gridSpacing) + 1
        let rows = Int(size.height / gridSpacing) + 1

        for r in 0..<rows {
            let line = SKShapeNode(rectOf: CGSize(width: size.width, height: 1))
            line.fillColor = UIColor.white.withAlphaComponent(gridAlpha)
            line.strokeColor = .clear
            line.position = CGPoint(x: 0, y: -size.height/2 + CGFloat(r) * gridSpacing)
            line.zPosition = -1
            addChild(line)
        }
        for c in 0..<cols {
            let line = SKShapeNode(rectOf: CGSize(width: 1, height: size.height))
            line.fillColor = UIColor.white.withAlphaComponent(gridAlpha)
            line.strokeColor = .clear
            line.position = CGPoint(x: -size.width/2 + CGFloat(c) * gridSpacing, y: 0)
            line.zPosition = -1
            addChild(line)
        }

        // Pixel MATCH logo in center
        let titleLbl = SKLabelNode(fontNamed: "Courier-Bold")
        titleLbl.text = "PIXEL MATCH"
        titleLbl.fontSize = 44
        titleLbl.fontColor = UIColor(hex: "#FFCC00")
        titleLbl.verticalAlignmentMode = .center
        titleLbl.position = CGPoint(x: 0, y: 40)
        titleLbl.zPosition = 5
        titleLbl.alpha = 0
        titleLbl.name = "title"
        addChild(titleLbl)

        // Gem row
        let gems = GemColor.allCases
        let spacing: CGFloat = size.width / CGFloat(gems.count + 1)
        for (i, color) in gems.enumerated() {
            let tex = PixelArt.shared.gemTexture(color: color, special: .none)
            let gem = SKSpriteNode(texture: tex, size: CGSize(width: 40, height: 40))
            gem.position = CGPoint(x: -size.width/2 + spacing * CGFloat(i + 1), y: -20)
            gem.zPosition = 5
            gem.alpha = 0
            gem.name = "gem_\(i)"
            addChild(gem)
        }

        // Loading bar
        let barBg = SKShapeNode(rectOf: CGSize(width: size.width * 0.7, height: 8), cornerRadius: 4)
        barBg.fillColor = UIColor(hex: "#1C3A5C")
        barBg.strokeColor = UIColor(hex: "#2255AA")
        barBg.lineWidth = 1.5
        barBg.position = CGPoint(x: 0, y: -90)
        barBg.zPosition = 5
        barBg.name = "barBg"
        addChild(barBg)

        let barFill = SKShapeNode(rectOf: CGSize(width: 2, height: 6), cornerRadius: 3)
        barFill.fillColor = UIColor(hex: "#FFCC00")
        barFill.strokeColor = .clear
        barFill.position = CGPoint(x: -size.width * 0.35 + 1, y: -90)
        barFill.zPosition = 6
        barFill.name = "barFill"
        addChild(barFill)

        let loadLbl = SKLabelNode(fontNamed: "Courier")
        loadLbl.text = "Loading pixels..."
        loadLbl.fontSize = 14
        loadLbl.fontColor = UIColor(hex: "#7799CC")
        loadLbl.verticalAlignmentMode = .center
        loadLbl.position = CGPoint(x: 0, y: -115)
        loadLbl.zPosition = 5
        addChild(loadLbl)

        // Version
        let versionLbl = SKLabelNode(fontNamed: "Courier")
        versionLbl.text = "v1.0.0"
        versionLbl.fontSize = 11
        versionLbl.fontColor = UIColor(hex: "#334466")
        versionLbl.verticalAlignmentMode = .center
        versionLbl.position = CGPoint(x: 0, y: -size.height/2 + 30)
        versionLbl.zPosition = 5
        addChild(versionLbl)
    }

    private func animateAndTransition() {
        // Title fade in
        childNode(withName: "title")?.run(.sequence([
            .wait(forDuration: 0.3),
            .fadeIn(withDuration: 0.4)
        ]))
        (childNode(withName: "title") as? SKLabelNode)?.run(.sequence([
            .wait(forDuration: 0.7),
            .scale(to: 1.05, duration: 0.15),
            .scale(to: 1.0, duration: 0.1)
        ]))

        // Gems pop in sequentially
        for i in 0..<6 {
            let gem = childNode(withName: "gem_\(i)")
            gem?.run(.sequence([
                .wait(forDuration: 0.5 + Double(i) * 0.1),
                .group([
                    .fadeIn(withDuration: 0.2),
                    .sequence([.scale(to: 1.3, duration: 0.1), .scale(to: 1.0, duration: 0.1)])
                ])
            ]))
        }

        // Loading bar fill
        let maxWidth = size.width * 0.7 - 2
        let barFill = childNode(withName: "barFill") as? SKShapeNode
        barFill?.run(.sequence([
            .wait(forDuration: 0.6),
            .customAction(withDuration: 1.2) { node, elapsed in
                let progress = elapsed / 1.2
                let w = max(2, progress * maxWidth)
                if let shape = node as? SKShapeNode {
                    shape.path = UIBezierPath(roundedRect:
                        CGRect(x: 0, y: -3, width: w, height: 6), cornerRadius: 3).cgPath
                    shape.position = CGPoint(x: -maxWidth/2, y: -90)
                }
            }
        ]))

        // Pre-warm pixel art cache
        preWarmAssets()

        // Transition to home
        run(.sequence([
            .wait(forDuration: 2.2),
            .run { [weak self] in self?.transitionToHome() }
        ]))
    }

    private func preWarmAssets() {
        // Pre-generate all gem textures in background
        DispatchQueue.global(qos: .background).async {
            for color in GemColor.allCases {
                for special in [TileSpecial.none, .stripedH, .stripedV, .wrapped, .colorBomb] {
                    _ = PixelArt.shared.gemTexture(color: color, special: special)
                }
            }
            for obs in [ObstacleType.jelly1, .jelly2, .ice, .chocolate, .stone] {
                _ = PixelArt.shared.obstacleTexture(type: obs)
            }
        }
    }

    private func transitionToHome() {
        guard let view = view else { return }
        PlayerData.shared.completeFirstLaunch()

        if !PlayerData.shared.tutorialComplete {
            let scene = TutorialScene(size: size)
            scene.scaleMode = .aspectFill
            view.presentScene(scene, transition: .fade(with: UIColor(hex: "#050D1A"), duration: 0.5))
        } else {
            let scene = HomeScene(size: size)
            scene.scaleMode = .aspectFill
            view.presentScene(scene, transition: .fade(with: UIColor(hex: "#050D1A"), duration: 0.5))
        }
    }
}
