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
        node.alpha = 0.85
        node.zPosition = 5
        addChild(node)
        obstacleNode = node
    }

    // MARK: - Selection

    func setSelected(_ selected: Bool) {
        guard isSelected != selected else { return }
        isSelected = selected

        if selected {
            gemSprite.run(.sequence([
                .scale(to: 1.18, duration: 0.08),
                .scale(to: 1.12, duration: 0.06)
            ]))
            addGlow()
        } else {
            gemSprite.run(.scale(to: 1.0, duration: 0.1))
            removeGlow()
        }
    }

    private func addGlow() {
        removeGlow()
        let glow = SKEffectNode()
        glow.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 4])
        glow.shouldEnableEffects = true
        glow.zPosition = -1

        let copy = SKSpriteNode(texture: gemSprite.texture,
                                size: CGSize(width: TileNode.gemSize + 8, height: TileNode.gemSize + 8))
        copy.colorBlendFactor = 1
        copy.color = UIColor.white.withAlphaComponent(0.6)
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
        let bounce = SKAction.sequence([
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
            .scale(to: 1.3, duration: 0.08),
            .scale(to: 0.0, duration: 0.12),
        ])) { completion() }
    }

    func animateSpawn(delay: TimeInterval = 0) {
        gemSprite.setScale(0)
        run(.wait(forDuration: delay)) { [weak self] in
            self?.gemSprite.run(.sequence([
                .scale(to: 1.2, duration: 0.1),
                .scale(to: 1.0, duration: 0.08)
            ]))
        }
    }

    func animateHint() {
        gemSprite.run(.repeatForever(.sequence([
            .scale(to: 1.15, duration: 0.3),
            .scale(to: 0.95, duration: 0.3),
            .scale(to: 1.0, duration: 0.1)
        ])), withKey: "hint")
    }

    func stopHint() {
        gemSprite.removeAction(forKey: "hint")
        gemSprite.run(.scale(to: 1.0, duration: 0.1))
    }

    func animateSpecialActivate() {
        let flash = SKSpriteNode(color: .white,
                                 size: CGSize(width: TileNode.size * 2, height: TileNode.size * 2))
        flash.zPosition = 10
        addChild(flash)
        flash.run(.sequence([
            .fadeAlpha(to: 0.8, duration: 0.05),
            .fadeOut(withDuration: 0.15),
            .removeFromParent()
        ]))

        gemSprite.run(.sequence([
            .scale(to: 1.4, duration: 0.1),
            .scale(to: 0.0, duration: 0.15)
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
        let tex = PixelArt.shared.particleTexture(color: color, size: 6)

        for i in 0..<count {
            let particle = SKSpriteNode(texture: tex, size: CGSize(width: 6, height: 6))
            particle.position = scene.convert(position, from: parent ?? scene)
            particle.zPosition = 20
            scene.addChild(particle)

            let angle = (CGFloat(i) / CGFloat(count)) * .pi * 2
            let dist = CGFloat.random(in: 30...70)
            let dx = cos(angle) * dist
            let dy = sin(angle) * dist

            particle.run(.sequence([
                .group([
                    .moveBy(x: dx, y: dy, duration: 0.4),
                    .sequence([.fadeAlpha(to: 1, duration: 0.05),
                               .fadeOut(withDuration: 0.35)])
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
