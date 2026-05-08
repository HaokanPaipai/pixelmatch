import SpriteKit

final class PixelButton: SKNode {

    enum Style {
        case primary    // bright color action button
        case secondary  // dark background
        case danger     // red
        case ghost      // outline only
        case icon       // square icon button
    }

    var onTap: (() -> Void)?

    private let bg: SKShapeNode
    private let label: SKLabelNode?
    private let iconSprite: SKSpriteNode?
    private let style: Style

    init(title: String,
         size: CGSize = CGSize(width: 180, height: 50),
         style: Style = .primary,
         color: UIColor = UIColor(hex: "#007AFF"),
         fontSize: CGFloat = 20) {
        self.style = style

        bg = PixelButton.makeBg(size, style: style, color: color)

        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = title
        lbl.fontSize = fontSize
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.zPosition = 2
        lbl.fontColor = style == .ghost ? color : .white
        label = lbl
        iconSprite = nil

        super.init()
        addChild(bg)
        addChild(lbl)
        isUserInteractionEnabled = true
    }

    init(icon pixels: [[UInt8]],
         iconColor: UIColor = .white,
         size: CGSize = CGSize(width: 50, height: 50),
         bgColor: UIColor = UIColor(hex: "#334466"),
         badge: String? = nil) {
        self.style = .icon

        bg = PixelButton.makeBg(size, style: .icon, color: bgColor)

        let iconSize = size.width * 0.6
        let tex = PixelArt.shared.iconTexture(pixels: pixels,
                                              primary: iconColor,
                                              light: iconColor.lighter(),
                                              dark: iconColor.darker())
        let sprite = SKSpriteNode(texture: tex,
                                  size: CGSize(width: iconSize, height: iconSize))
        sprite.zPosition = 2
        iconSprite = sprite
        label = nil

        super.init()
        addChild(bg)
        addChild(sprite)

        if let badgeText = badge {
            let badgeBg = SKShapeNode(circleOfRadius: 9)
            badgeBg.fillColor = UIColor(hex: "#FF3B30")
            badgeBg.strokeColor = .clear
            badgeBg.position = CGPoint(x: size.width * 0.35, y: size.height * 0.35)
            badgeBg.zPosition = 5
            let badgeLbl = SKLabelNode(fontNamed: "Courier-Bold")
            badgeLbl.text = badgeText
            badgeLbl.fontSize = 10
            badgeLbl.verticalAlignmentMode = .center
            badgeLbl.horizontalAlignmentMode = .center
            badgeLbl.fontColor = .white
            badgeBg.addChild(badgeLbl)
            addChild(badgeBg)
        }

        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError() }

    private static func makeBg(_ size: CGSize, style: Style, color: UIColor) -> SKShapeNode {
        let rect = CGRect(origin: CGPoint(x: -size.width/2, y: -size.height/2), size: size)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8).cgPath
        let node = SKShapeNode(path: path)
        node.zPosition = 1
        node.lineWidth = style == .ghost ? 2 : 0

        switch style {
        case .primary:
            node.fillColor = color
            node.strokeColor = .clear
            // Bottom shadow
            let shadow = SKShapeNode(path: UIBezierPath(roundedRect:
                CGRect(x: -size.width/2 + 2, y: -size.height/2 - 3, width: size.width - 4, height: 4),
                cornerRadius: 4).cgPath)
            shadow.fillColor = color.darker(by: 0.3)
            shadow.strokeColor = .clear
            shadow.zPosition = 0
            node.addChild(shadow)

        case .secondary:
            node.fillColor = UIColor(hex: "#1C2E4A")
            node.strokeColor = UIColor(hex: "#334466")
            node.lineWidth = 2

        case .danger:
            node.fillColor = UIColor(hex: "#FF3B30")
            node.strokeColor = .clear

        case .ghost:
            node.fillColor = UIColor.white.withAlphaComponent(0.08)
            node.strokeColor = color

        case .icon:
            node.fillColor = color
            node.strokeColor = color.darker(by: 0.2)
            node.lineWidth = 2
        }

        return node
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 0.93, duration: 0.06))
        bg.run(.fadeAlpha(to: 0.85, duration: 0.06))
        AudioManager.shared.play(.buttonTap)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 1.0, duration: 0.08))
        bg.run(.fadeAlpha(to: 1.0, duration: 0.08))
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        if abs(loc.x) < 200 && abs(loc.y) < 100 {
            onTap?()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 1.0, duration: 0.08))
        bg.run(.fadeAlpha(to: 1.0, duration: 0.08))
    }

    // MARK: - Update

    func setTitle(_ title: String) { label?.text = title }
    func setEnabled(_ enabled: Bool) { alpha = enabled ? 1.0 : 0.4; isUserInteractionEnabled = enabled }
}

// MARK: - HUD Coin/Diamond Counter

final class CurrencyNode: SKNode {
    private let icon: SKSpriteNode
    private let countLabel: SKLabelNode
    private var value: Int

    init(isDiamond: Bool, initialValue: Int) {
        self.value = initialValue
        let px = isDiamond ? PixelIcons.diamond : PixelIcons.coin
        let color: UIColor = isDiamond ? UIColor(hex: "#AF52DE") : UIColor(hex: "#FFCC00")
        icon = SKSpriteNode(texture: PixelArt.shared.iconTexture(pixels: px, primary: color, light: color.lighter(), dark: color.darker()), size: CGSize(width: 24, height: 24))
        icon.position = CGPoint(x: -50, y: 0)

        countLabel = SKLabelNode(fontNamed: "Courier-Bold")
        countLabel.fontSize = 18
        countLabel.fontColor = .white
        countLabel.verticalAlignmentMode = .center
        countLabel.horizontalAlignmentMode = .left
        countLabel.text = "\(initialValue)"
        countLabel.position = CGPoint(x: -35, y: 0)

        super.init()
        let bg = SKShapeNode(rectOf: CGSize(width: 110, height: 30), cornerRadius: 15)
        bg.fillColor = UIColor(hex: "#0A1628").withAlphaComponent(0.8)
        bg.strokeColor = UIColor(hex: "#334466")
        bg.lineWidth = 1.5
        addChild(bg)
        addChild(icon)
        addChild(countLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(to newValue: Int, animate: Bool = true) {
        let old = value
        value = newValue
        countLabel.text = "\(newValue)"
        if animate && newValue > old {
            countLabel.run(.sequence([
                .scale(to: 1.3, duration: 0.1),
                .scale(to: 1.0, duration: 0.1)
            ]))
        }
    }
}
