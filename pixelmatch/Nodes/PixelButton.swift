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
    private let buttonSize: CGSize
    private let stripsLegacyIconText: Bool

    init(title: String,
         icon: PixelArtIcon? = nil,
         size: CGSize = CGSize(width: 180, height: 50),
         style: Style = .primary,
         color: UIColor = UIColor(hex: "#007AFF"),
         fontSize: CGFloat = 20) {
        self.style = style
        self.buttonSize = size
        self.stripsLegacyIconText = icon != nil

        bg = PixelButton.makeBg(size, style: style, color: color)

        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = icon == nil ? title : PixelButton.cleanLegacyIconText(title)
        lbl.fontSize = fontSize
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .center
        lbl.zPosition = 2
        lbl.fontColor = style == .ghost ? color : .white
        label = lbl

        if let icon {
            let iconSize = min(size.height * 0.46, 28)
            let tex = PixelArt.shared.softIconTexture(icon, size: iconSize * 1.35)
            let sprite = SKSpriteNode(texture: tex,
                                      size: CGSize(width: iconSize, height: iconSize))
            sprite.zPosition = 2
            iconSprite = sprite
        } else {
            iconSprite = nil
        }

        super.init()
        addChild(bg)
        if let iconSprite {
            addChild(iconSprite)
        }
        addChild(lbl)
        fitTitleIfNeeded()
        layoutContent()
        isUserInteractionEnabled = true
    }

    init(icon: PixelArtIcon,
         size: CGSize = CGSize(width: 50, height: 50),
         bgColor: UIColor = UIColor(hex: "#334466"),
         badge: String? = nil) {
        self.style = .icon
        self.buttonSize = size
        self.stripsLegacyIconText = false

        bg = PixelButton.makeBg(size, style: .icon, color: bgColor)

        let iconSize = size.width * 0.6
        let tex = PixelArt.shared.softIconTexture(icon, size: iconSize * 1.35)
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

    override func contains(_ p: CGPoint) -> Bool {
        isPointInsideButton(p, padding: 4)
    }

    private static func makeBg(_ size: CGSize, style: Style, color: UIColor) -> SKShapeNode {
        let rect = CGRect(origin: CGPoint(x: -size.width/2, y: -size.height/2), size: size)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8).cgPath
        let node = SKShapeNode(path: path)
        node.zPosition = 1
        node.lineWidth = style == .ghost ? 2 : 0
        var surfaceColor = color

        switch style {
        case .primary:
            node.fillColor = color
            node.strokeColor = .clear

        case .secondary:
            surfaceColor = color
            node.fillColor = UIColor(hex: "#1C2E4A")
            node.strokeColor = color.withAlphaComponent(0.48)
            node.lineWidth = 2

        case .danger:
            surfaceColor = UIColor(hex: "#FF3B30")
            node.fillColor = UIColor(hex: "#FF3B30")
            node.strokeColor = .clear

        case .ghost:
            surfaceColor = color
            node.fillColor = UIColor.white.withAlphaComponent(0.08)
            node.strokeColor = color

        case .icon:
            surfaceColor = color
            node.fillColor = color
            node.strokeColor = color.darker(by: 0.2)
            node.lineWidth = 2
        }

        addSurfaceDetails(to: node, size: size, color: surfaceColor, style: style)
        return node
    }

    private static func addSurfaceDetails(to node: SKShapeNode,
                                          size: CGSize,
                                          color: UIColor,
                                          style: Style) {
        guard style != .ghost else { return }

        let bottomRect = CGRect(x: -size.width / 2 + 3,
                                y: -size.height / 2 - 3,
                                width: size.width - 6,
                                height: 5)
        let shadow = SKShapeNode(path: UIBezierPath(roundedRect: bottomRect,
                                                    cornerRadius: 4).cgPath)
        shadow.name = "button.shadow"
        shadow.fillColor = color.darker(by: style == .secondary ? 0.18 : 0.32)
        shadow.strokeColor = .clear
        shadow.alpha = style == .icon ? 0.65 : 0.82
        shadow.zPosition = -1
//        node.addChild(shadow)

        let glossRect = CGRect(x: -size.width / 2 + 7,
                               y: size.height * 0.04,
                               width: size.width - 14,
                               height: max(8, size.height * 0.28))
        let gloss = SKShapeNode(path: UIBezierPath(roundedRect: glossRect,
                                                   cornerRadius: min(7, glossRect.height / 2)).cgPath)
        gloss.name = "button.gloss"
        gloss.fillColor = UIColor.white.withAlphaComponent(style == .secondary ? 0.07 : 0.13)
        gloss.strokeColor = .clear
        gloss.zPosition = 1
//        node.addChild(gloss)

        let lowerRim = SKShapeNode(path: UIBezierPath(roundedRect:
            CGRect(x: -size.width / 2 + 5,
                   y: -size.height / 2 + 3,
                   width: size.width - 10,
                   height: 3),
            cornerRadius: 2).cgPath)
        lowerRim.name = "button.lowerRim"
        lowerRim.fillColor = color.darker(by: 0.25).withAlphaComponent(style == .secondary ? 0.36 : 0.52)
        lowerRim.strokeColor = .clear
        lowerRim.zPosition = 1
//        node.addChild(lowerRim)
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              isPointInsideButton(touch.location(in: self), padding: 6) else { return }
        run(.scale(to: 0.93, duration: 0.06))
        bg.run(.fadeAlpha(to: 0.85, duration: 0.06))
        AudioManager.shared.play(.buttonTap)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 1.0, duration: 0.08))
        bg.run(.fadeAlpha(to: 1.0, duration: 0.08))
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        if isPointInsideButton(loc, padding: 8) {
            onTap?()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 1.0, duration: 0.08))
        bg.run(.fadeAlpha(to: 1.0, duration: 0.08))
    }

    // MARK: - Update

    func setTitle(_ title: String) {
        label?.text = stripsLegacyIconText ? PixelButton.cleanLegacyIconText(title) : title
        fitTitleIfNeeded()
        layoutContent()
    }

    func setColor(_ color: UIColor) {
        bg.fillColor = color
        bg.strokeColor = style == .ghost ? color : .clear
        for child in bg.children {
            guard let shape = child as? SKShapeNode else { continue }
            switch shape.name {
            case "button.shadow":
                shape.fillColor = color.darker(by: 0.32)
            case "button.lowerRim":
                shape.fillColor = color.darker(by: 0.25).withAlphaComponent(0.52)
            default:
                break
            }
        }
    }

    func setEnabled(_ enabled: Bool) { alpha = enabled ? 1.0 : 0.4; isUserInteractionEnabled = enabled }

    private func isPointInsideButton(_ point: CGPoint, padding: CGFloat) -> Bool {
        abs(point.x) <= buttonSize.width / 2 + padding
            && abs(point.y) <= buttonSize.height / 2 + padding
    }

    private func fitTitleIfNeeded() {
        guard let label = label else { return }

        // 文本按钮只允许在自己的可见区域内响应，长文案也要收进按钮宽度。
        label.setScale(1)
        let iconAllowance = iconSprite == nil ? 0 : (iconSprite?.size.width ?? 0) + 10
        let maxWidth = max(24, buttonSize.width - 18 - iconAllowance)
        guard label.frame.width > maxWidth else { return }

        let scale = max(0.72, maxWidth / max(label.frame.width, 1))
        label.setScale(scale)
    }

    private func layoutContent() {
        guard let label else { return }
        guard let iconSprite else {
            label.position = .zero
            return
        }

        let gap: CGFloat = 7
        let textWidth = max(1, label.frame.width)
        let combined = iconSprite.size.width + gap + textWidth
        let startX = -combined / 2
        iconSprite.position = CGPoint(x: startX + iconSprite.size.width / 2, y: 0)
        label.position = CGPoint(x: startX + iconSprite.size.width + gap + textWidth / 2, y: 0)
    }

    private static func cleanLegacyIconText(_ title: String) -> String {
        let symbols = ["▶", "◀", "↺", "✕", "⏸", "⚙", "📹", "🎁", "✅", "📋", "⭐", "🪙", "💎", "❤", "♥", "◌"]
        var text = title
        for symbol in symbols {
            text = text.replacingOccurrences(of: symbol, with: "")
        }
        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum CurrencyKind {
    case coins
    case diamonds

    var icon: PixelArtIcon {
        switch self {
        case .coins: return .coin
        case .diamonds: return .diamond
        }
    }

    var color: UIColor {
        switch self {
        case .coins: return UIColor(hex: "#FFCC00")
        case .diamonds: return UIColor(hex: "#AF52DE")
        }
    }
}

struct CurrencyAmountItem {
    let kind: CurrencyKind
    let amount: Int

    init(_ kind: CurrencyKind, _ amount: Int) {
        self.kind = kind
        self.amount = amount
    }
}

enum CurrencyText {
    static func surroundingAmount(in text: String, amount: Int) -> (leading: String, trailing: String) {
        let amountText = "\(amount)"
        guard let range = text.range(of: amountText) else {
            return (text, "")
        }
        let leading = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let trailing = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (leading, trailing)
    }
}

final class CurrencyAmountNode: SKNode {
    enum Alignment {
        case leading
        case center
    }

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    private let alignment: Alignment
    private let gap: CGFloat
    private let iconNode: SKSpriteNode
    private let amountLabel: SKLabelNode
    private let leadingLabel: SKLabelNode?
    private let trailingLabel: SKLabelNode?

    private(set) var contentWidth: CGFloat = 0

    init(kind: CurrencyKind,
         amount: Int,
         amountPrefix: String = "",
         leadingText: String? = nil,
         trailingText: String? = nil,
         fontSize: CGFloat = 16,
         iconSize: CGFloat? = nil,
         fontColor: UIColor? = nil,
         alignment: Alignment = .center,
         gap: CGFloat = 5) {
        self.alignment = alignment
        self.gap = gap

        let resolvedIconSize = iconSize ?? max(16, fontSize * 1.25)
        iconNode = SKSpriteNode(texture: PixelArt.shared.softIconTexture(kind.icon, size: resolvedIconSize * 1.35),
                                size: CGSize(width: resolvedIconSize, height: resolvedIconSize))

        let textColor = fontColor ?? kind.color
        amountLabel = CurrencyAmountNode.makeLabel(
            "\(amountPrefix)\(CurrencyAmountNode.format(amount))",
            fontSize: fontSize,
            color: textColor
        )

        if let leadingText, !leadingText.isEmpty {
            leadingLabel = CurrencyAmountNode.makeLabel(leadingText, fontSize: fontSize, color: textColor)
        } else {
            leadingLabel = nil
        }

        if let trailingText, !trailingText.isEmpty {
            trailingLabel = CurrencyAmountNode.makeLabel(trailingText, fontSize: fontSize, color: textColor)
        } else {
            trailingLabel = nil
        }

        super.init()
        if let leadingLabel { addChild(leadingLabel) }
        addChild(iconNode)
        addChild(amountLabel)
        if let trailingLabel { addChild(trailingLabel) }
        layoutContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    private static func makeLabel(_ text: String, fontSize: CGFloat, color: UIColor) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Courier-Bold")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .left
        return label
    }

    private static func format(_ amount: Int) -> String {
        formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    private func layoutContent() {
        let optionalNodes: [SKNode?] = [
            leadingLabel,
            iconNode,
            amountLabel,
            trailingLabel
        ]
        let nodes = optionalNodes.compactMap { $0 }
        var widths: [CGFloat] = []
        for node in nodes {
            if let sprite = node as? SKSpriteNode {
                widths.append(sprite.size.width)
            } else {
                widths.append(max(1, node.frame.width))
            }
        }

        contentWidth = widths.reduce(0, +) + gap * CGFloat(max(0, nodes.count - 1))
        var x = alignment == .center ? -contentWidth / 2 : 0

        for (index, node) in nodes.enumerated() {
            let width = widths[index]
            if node is SKLabelNode {
                node.position = CGPoint(x: x, y: 0)
            } else {
                node.position = CGPoint(x: x + width / 2, y: 0)
            }
            x += width + gap
        }
    }
}

final class CurrencyAmountsNode: SKNode {
    private(set) var contentWidth: CGFloat = 0

    init(items: [CurrencyAmountItem],
         amountPrefix: String = "",
         fontSize: CGFloat = 16,
         iconSize: CGFloat? = nil,
         spacing: CGFloat = 14,
         alignment: CurrencyAmountNode.Alignment = .center) {
        super.init()

        let amountNodes = items
            .filter { $0.amount > 0 }
            .map {
                CurrencyAmountNode(kind: $0.kind,
                                   amount: $0.amount,
                                   amountPrefix: amountPrefix,
                                   fontSize: fontSize,
                                   iconSize: iconSize,
                                   alignment: .leading)
            }

        contentWidth = amountNodes.reduce(0) { $0 + $1.contentWidth }
            + spacing * CGFloat(max(0, amountNodes.count - 1))
        var x = alignment == .center ? -contentWidth / 2 : 0

        for node in amountNodes {
            node.position = CGPoint(x: x, y: 0)
            addChild(node)
            x += node.contentWidth + spacing
        }
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - HUD Coin/Diamond Counter

final class CurrencyNode: SKNode {
    private let icon: SKSpriteNode
    private let countLabel: SKLabelNode
    private var value: Int

    init(isDiamond: Bool, initialValue: Int) {
        self.value = initialValue
        icon = SKSpriteNode(texture: PixelArt.shared.softIconTexture(isDiamond ? .diamond : .coin, size: 28),
                            size: CGSize(width: 24, height: 24))
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
