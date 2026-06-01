import SpriteKit

final class TileNode: SKNode {

    var tile: Tile
    private let gemSprite: SKSpriteNode
    private var obstacleNode: SKSpriteNode?
    private var isSelected = false
    private var glowNode: SKEffectNode?

    static let size: CGFloat = GameConstants.tileSize
    static let gemSize: CGFloat = GameConstants.tileSize - 4

    init(tile: Tile) {
        self.tile = tile

        let tex = PixelArt.shared.gemTexture(color: tile.gemColor, special: tile.special)
        gemSprite = SKSpriteNode(texture: tex, size: CGSize(width: TileNode.gemSize, height: TileNode.gemSize))

        super.init()
        addChild(gemSprite)

        if tile.isHole { isHidden = true; return }
        updateObstacleOverlay()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Update

    func refresh() {
        if tile.isHole { isHidden = true; return }
        isHidden = false
        alpha = 1
        setScale(1)
        gemSprite.removeAllActions()
        gemSprite.alpha = 1
        gemSprite.setScale(1)

        let tex = PixelArt.shared.gemTexture(color: tile.gemColor, special: tile.special)
        gemSprite.texture = tex
        gemSprite.size = CGSize(width: TileNode.gemSize, height: TileNode.gemSize)
        updateObstacleOverlay()
    }

    private func updateObstacleOverlay() {
        obstacleNode?.removeFromParent()
        obstacleNode = nil

        guard tile.obstacle != .none else { return }
        let tex = PixelArt.shared.obstacleTexture(type: tile.obstacle)
        let node = SKSpriteNode(texture: tex,
                                size: CGSize(width: TileNode.size, height: TileNode.size))
        node.alpha = obstacleAlpha(tile.obstacle)
        node.zPosition = 5
        addChild(node)
        obstacleNode = node
    }

    private func obstacleAlpha(_ obstacle: ObstacleType) -> CGFloat {
        switch obstacle {
        case .jelly1: return 0.62
        case .jelly2: return 0.70
        case .ice: return 0.72
        case .cage: return 0.86
        case .key: return 0.96
        case .chest1, .chest2, .lock, .stone, .chocolate: return 0.92
        case .none: return 1
        }
    }

    // MARK: - Selection

    func setSelected(_ selected: Bool) {
        guard isSelected != selected else { return }
        isSelected = selected

        if selected {
            let targetScale: CGFloat = VisualComfort.isReducedMotionEnabled ? 1.02 : 1.06
            gemSprite.run(.scale(to: targetScale, duration: 0.08))
            addGlow()
        } else {
            gemSprite.run(.scale(to: 1.0, duration: 0.1))
            removeGlow()
        }
    }

    private func addGlow() {
        removeGlow()
        let glow = SKEffectNode()
        glow.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 3])
        glow.shouldEnableEffects = true
        glow.zPosition = -1

        let copy = SKSpriteNode(texture: gemSprite.texture,
                                size: CGSize(width: TileNode.gemSize + 6, height: TileNode.gemSize + 6))
        copy.colorBlendFactor = 1
        copy.color = tile.gemColor.light.withAlphaComponent(0.34)
        glow.addChild(copy)
        addChild(glow)
        glowNode = glow
    }

    private func removeGlow() {
        glowNode?.removeFromParent()
        glowNode = nil
    }

    // MARK: - Animations

    func animateFall(fromY: CGFloat, toY: CGFloat, delay: TimeInterval, completion: (() -> Void)? = nil) {
        position.y = fromY
        let dist = abs(fromY - toY)
        let duration = min(0.35, max(0.12, dist / 500))
        let bounce: SKAction = VisualComfort.isReducedMotionEnabled
            ? .moveTo(y: toY, duration: duration * 0.72)
            : .sequence([
                .moveTo(y: toY - 5, duration: duration * 0.85),
                .moveTo(y: toY + 3, duration: 0.06),
                .moveTo(y: toY, duration: 0.04)
            ])

        run(.sequence([.wait(forDuration: delay), bounce])) {
            completion?()
        }
    }

    func animateMatch(completion: @escaping () -> Void) {
        gemSprite.run(.sequence([
            .group([
                .scale(to: 1.12, duration: 0.07),
                .fadeAlpha(to: 0.88, duration: 0.07)
            ]),
            .group([
                .scale(to: 0.0, duration: 0.13),
                .fadeOut(withDuration: 0.13)
            ]),
        ])) { completion() }
    }

    func animateSpawn(delay: TimeInterval = 0) {
        gemSprite.setScale(0)
        run(.wait(forDuration: delay)) { [weak self] in
            guard let self = self else { return }
            if VisualComfort.isReducedMotionEnabled {
                self.gemSprite.alpha = 0
                self.gemSprite.setScale(1)
                self.gemSprite.run(.fadeIn(withDuration: 0.12))
            } else {
                self.gemSprite.run(.sequence([
                    .scale(to: 1.08, duration: 0.11),
                    .scale(to: 1.0, duration: 0.09)
                ]))
            }
        }
    }

    func animateHint() {
        if VisualComfort.isReducedMotionEnabled {
            gemSprite.run(.fadeAlpha(to: 0.88, duration: 0.18), withKey: "hint")
            return
        }

        gemSprite.run(.repeatForever(.sequence([
            .group([
                .scale(to: 1.06, duration: 0.42),
                .fadeAlpha(to: 0.86, duration: 0.42)
            ]),
            .group([
                .scale(to: 0.98, duration: 0.42),
                .fadeAlpha(to: 1.0, duration: 0.42)
            ]),
            .scale(to: 1.0, duration: 0.12)
        ])), withKey: "hint")
    }

    func stopHint() {
        gemSprite.removeAction(forKey: "hint")
        gemSprite.run(.group([
            .scale(to: 1.0, duration: 0.1),
            .fadeAlpha(to: 1.0, duration: 0.1)
        ]))
    }

    func animateSpecialActivate() {
        let reducedMotion = VisualComfort.isReducedMotionEnabled
        let flash = SKShapeNode(circleOfRadius: TileNode.size * 0.62)
        flash.fillColor = tile.gemColor.light.withAlphaComponent(reducedMotion ? 0.14 : 0.24)
        flash.strokeColor = UIColor.white.withAlphaComponent(reducedMotion ? 0.28 : 0.42)
        flash.lineWidth = reducedMotion ? 1.5 : 2
        flash.zPosition = 10
        flash.setScale(reducedMotion ? 0.70 : 0.35)
        addChild(flash)
        flash.run(.sequence([
            .group([
                .scale(to: reducedMotion ? 1.04 : 1.45, duration: reducedMotion ? 0.12 : 0.18),
                .fadeOut(withDuration: reducedMotion ? 0.12 : 0.18)
            ]),
            .removeFromParent()
        ]))

        gemSprite.run(reducedMotion
            ? .fadeOut(withDuration: 0.14)
            : .sequence([
                .scale(to: 1.16, duration: 0.09),
                .scale(to: 0.0, duration: 0.16)
            ]))
    }

    func wiggle() {
        gemSprite.run(.sequence([
            .rotate(byAngle: 0.15, duration: 0.06),
            .rotate(byAngle: -0.3, duration: 0.08),
            .rotate(byAngle: 0.15, duration: 0.06)
        ]))
    }

    // MARK: - Particle Burst

    func burstParticles(in scene: SKScene, count: Int = 8) {
        let color = tile.gemColor.primary
        let reducedMotion = VisualComfort.isReducedMotionEnabled
        let particleSize: CGFloat = reducedMotion ? 3.5 : 4.5
        let tex = PixelArt.shared.particleTexture(color: color, size: particleSize)
        let particleCount = reducedMotion ? max(2, min(count, 3)) : count

        for i in 0..<particleCount {
            let particle = SKSpriteNode(texture: tex, size: CGSize(width: particleSize, height: particleSize))
            particle.position = scene.convert(position, from: parent ?? scene)
            particle.zPosition = 20
            scene.addChild(particle)

            let angle = (CGFloat(i) / CGFloat(particleCount)) * .pi * 2
            let dist = CGFloat.random(in: reducedMotion ? 10...22 : 20...46)
            let dx = cos(angle) * dist
            let dy = sin(angle) * dist
            let duration = reducedMotion ? 0.20 : 0.32

            particle.run(.sequence([
                .group([
                    .moveBy(x: dx, y: dy, duration: duration),
                    .scale(to: reducedMotion ? 0.68 : 0.55, duration: duration),
                    .sequence([.fadeAlpha(to: reducedMotion ? 0.52 : 0.78, duration: 0.04),
                               .fadeOut(withDuration: max(0.12, duration - 0.04))])
                ]),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Layout

    static func boardPosition(row: Int, col: Int, boardRows: Int, boardCols: Int) -> CGPoint {
        let step = GameConstants.tileStep
        let boardW = CGFloat(boardCols) * step - GameConstants.tileGap
        let boardH = CGFloat(boardRows) * step - GameConstants.tileGap
        let x = CGFloat(col) * step - boardW / 2 + TileNode.size / 2
        let y = -(CGFloat(row) * step - boardH / 2 + TileNode.size / 2)
        return CGPoint(x: x, y: y)
    }
}
