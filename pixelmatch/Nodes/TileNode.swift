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
        startIdleShimmer()
    }

    /// 待机微动效：随机间隔在宝石高光位闪一颗星光点，让满屏宝石"活"起来。
    /// 每块宝石 8-20s 才闪一次（错峰随机），同屏动画量极小；reducedMotion 不启用。
    private func startIdleShimmer() {
        guard !VisualComfort.isReducedMotionEnabled else { return }
        let glint = SKSpriteNode(texture: PixelArt.shared.particleTexture(color: .white, size: 5),
                                 size: CGSize(width: 5, height: 5))
        glint.alpha = 0
        // 落在宝石左上高光区，与绘制的 gloss 椭圆呼应
        glint.position = CGPoint(x: -TileNode.gemSize * 0.22, y: TileNode.gemSize * 0.24)
        glint.zPosition = 3
        glint.blendMode = .add
        gemSprite.addChild(glint)

        let twinkle = SKAction.sequence([
            .wait(forDuration: Double.random(in: 2...18)),
            .group([
                .sequence([.fadeAlpha(to: 0.85, duration: 0.16),
                           .fadeOut(withDuration: 0.30)]),
                .sequence([.scale(to: 1.6, duration: 0.16),
                           .scale(to: 0.8, duration: 0.30)]),
                .rotate(byAngle: .pi / 2, duration: 0.46)
            ]),
            .wait(forDuration: Double.random(in: 8...20))
        ])
        glint.run(.repeatForever(twinkle), withKey: "shimmer")
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

    /// 场景级粒子预算：大连锁瞬时可达数百粒，超出后按比例缩量防掉帧。
    private static let particleBudget = 150
    private static func liveParticleCount(in scene: SKScene) -> Int {
        scene.children.reduce(0) { $0 + ($1.name == "burstParticle" ? 1 : 0) }
    }

    /// intensity：0=3 消（直线小爆），1=4 消（抛物线+闪环），2=5 消/特效（更密+中心闪光）
    func burstParticles(in scene: SKScene, count: Int = 8, intensity: Int = 0) {
        let color = tile.gemColor.primary
        let reducedMotion = VisualComfort.isReducedMotionEnabled
        let origin = scene.convert(position, from: parent ?? scene)

        if reducedMotion {
            // 降级：维持原有 2-3 个直线粒子
            emitLinearParticles(in: scene, at: origin, color: color,
                                count: max(2, min(count, 3)), size: 3.5, duration: 0.20)
            return
        }

        // 粒子预算：超限按比例缩量
        let live = TileNode.liveParticleCount(in: scene)
        let allowance = max(0, TileNode.particleBudget - live)
        let particleCount = min(count, max(3, allowance / 4))
        guard particleCount > 0 else { return }

        for _ in 0..<particleCount {
            // 尺寸两档 + 角度/速度全随机；抛物线轨迹（初速上抛 + 重力下坠）更有"碎裂感"
            let particleSize: CGFloat = Bool.random() ? 3.0 : 5.0
            let tex = PixelArt.shared.particleTexture(color: color, size: particleSize)
            let particle = SKSpriteNode(texture: tex, size: CGSize(width: particleSize, height: particleSize))
            particle.position = origin
            particle.zPosition = 20
            particle.name = "burstParticle"
            scene.addChild(particle)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 40...110)
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed + 30   // 整体略向上抛
            let duration: TimeInterval = 0.38
            let gravity: CGFloat = -260

            let follow = SKAction.customAction(withDuration: duration) { node, t in
                let dt = CGFloat(t)
                node.position = CGPoint(x: origin.x + vx * dt,
                                        y: origin.y + vy * dt + 0.5 * gravity * dt * dt)
            }
            particle.run(.sequence([
                .group([
                    follow,
                    .scale(to: 0.4, duration: duration),
                    .sequence([.fadeAlpha(to: 0.9, duration: 0.05),
                               .fadeOut(withDuration: duration - 0.05)])
                ]),
                .removeFromParent()
            ]))
        }

        // 强度 1+：白色冲击闪环
        if intensity >= 1 {
            let ring = SKShapeNode(circleOfRadius: TileNode.size * 0.4)
            ring.strokeColor = UIColor.white.withAlphaComponent(0.85)
            ring.fillColor = .clear
            ring.lineWidth = 2.5
            ring.position = origin
            ring.zPosition = 21
            ring.setScale(0.3)
            scene.addChild(ring)
            ring.run(.sequence([
                .group([.scale(to: intensity >= 2 ? 2.2 : 1.5, duration: 0.22),
                        .fadeOut(withDuration: 0.22)]),
                .removeFromParent()
            ]))
        }

        // 强度 2：中心闪光帧
        if intensity >= 2 {
            let flash = SKSpriteNode(texture: PixelArt.shared.particleTexture(color: .white, size: 8),
                                     size: CGSize(width: TileNode.size * 1.1, height: TileNode.size * 1.1))
            flash.position = origin
            flash.zPosition = 22
            flash.alpha = 0
            scene.addChild(flash)
            flash.run(.sequence([
                .fadeAlpha(to: 0.55, duration: 0.05),
                .fadeOut(withDuration: 0.14),
                .removeFromParent()
            ]))
        }
    }

    private func emitLinearParticles(in scene: SKScene, at origin: CGPoint, color: UIColor,
                                     count: Int, size: CGFloat, duration: TimeInterval) {
        let tex = PixelArt.shared.particleTexture(color: color, size: size)
        for i in 0..<count {
            let particle = SKSpriteNode(texture: tex, size: CGSize(width: size, height: size))
            particle.position = origin
            particle.zPosition = 20
            particle.name = "burstParticle"
            scene.addChild(particle)
            let angle = (CGFloat(i) / CGFloat(count)) * .pi * 2
            let dist = CGFloat.random(in: 10...22)
            particle.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * dist, y: sin(angle) * dist, duration: duration),
                    .scale(to: 0.68, duration: duration),
                    .sequence([.fadeAlpha(to: 0.52, duration: 0.04),
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
