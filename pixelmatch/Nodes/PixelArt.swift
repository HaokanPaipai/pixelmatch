import UIKit
import SpriteKit

// MARK: - Pixel Icon Definitions (8×8 grid: 0=transparent 1=primary 2=light 3=dark 4=white)

struct PixelIcons {
    // Flame (red gem)
    static let flame: [[UInt8]] = [
        [0,0,0,0,1,0,0,0],
        [0,0,0,1,1,1,0,0],
        [0,0,1,1,2,1,1,0],
        [0,1,1,2,2,2,1,0],
        [0,1,2,2,1,2,1,0],
        [1,1,2,1,1,2,1,1],
        [1,1,1,1,1,1,1,0],
        [0,1,1,3,3,1,0,0],
    ]
    // Water drop (blue gem)
    static let drop: [[UInt8]] = [
        [0,0,0,2,0,0,0,0],
        [0,0,1,1,1,0,0,0],
        [0,1,1,2,1,1,0,0],
        [1,1,1,2,1,1,1,0],
        [1,1,1,1,1,1,1,0],
        [1,1,1,1,1,1,1,0],
        [0,1,1,1,1,1,0,0],
        [0,0,3,3,3,0,0,0],
    ]
    // Leaf (green gem)
    static let leaf: [[UInt8]] = [
        [0,0,1,1,1,1,0,0],
        [0,1,1,2,1,1,1,0],
        [1,1,2,2,1,1,1,0],
        [1,1,2,1,1,1,0,0],
        [0,1,1,1,1,0,0,0],
        [0,0,1,1,1,1,0,0],
        [0,0,0,3,1,1,0,0],
        [0,0,0,3,3,0,0,0],
    ]
    // Star (yellow gem)
    static let star: [[UInt8]] = [
        [0,0,0,2,2,0,0,0],
        [0,0,0,1,1,0,0,0],
        [1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,0],
        [0,0,1,1,1,1,0,0],
        [0,1,1,0,0,1,1,0],
        [0,1,0,0,0,0,1,0],
        [0,0,0,0,0,0,0,0],
    ]
    // Lightning bolt (purple gem)
    static let bolt: [[UInt8]] = [
        [0,0,0,2,2,2,0,0],
        [0,0,1,1,1,0,0,0],
        [0,1,1,1,0,0,0,0],
        [1,1,2,1,1,1,0,0],
        [0,0,1,1,1,1,1,0],
        [0,0,0,1,1,1,0,0],
        [0,0,0,0,1,1,0,0],
        [0,0,0,0,0,3,0,0],
    ]
    // Sun (orange gem)
    static let sun: [[UInt8]] = [
        [0,1,0,0,0,0,1,0],
        [0,0,1,2,2,1,0,0],
        [0,1,2,2,2,2,1,0],
        [1,1,2,2,2,2,1,1],
        [1,1,2,2,2,2,1,1],
        [0,1,2,2,2,2,1,0],
        [0,0,1,2,2,1,0,0],
        [0,1,0,0,0,0,1,0],
    ]

    // UI Icons
    static let hammer: [[UInt8]] = [
        [0,0,1,1,1,1,0,0],
        [0,1,1,1,1,1,1,0],
        [0,1,2,1,1,2,1,0],
        [0,0,1,1,1,1,0,0],
        [0,0,0,3,3,0,0,0],
        [0,0,0,3,3,0,0,0],
        [0,0,1,3,3,1,0,0],
        [0,0,1,1,1,1,0,0],
    ]
    static let shuffle: [[UInt8]] = [
        [1,1,0,0,0,0,1,1],
        [0,1,1,0,0,1,1,0],
        [0,0,1,1,1,1,0,0],
        [0,0,0,2,2,0,0,0],
        [0,0,0,2,2,0,0,0],
        [0,0,1,1,1,1,0,0],
        [0,1,1,0,0,1,1,0],
        [1,1,0,0,0,0,1,1],
    ]
    static let moves: [[UInt8]] = [
        [0,0,0,2,2,0,0,0],
        [0,0,2,2,2,2,0,0],
        [0,2,2,0,0,2,2,0],
        [2,2,0,0,0,0,2,2],
        [0,0,0,1,1,0,0,0],
        [0,0,0,1,1,0,0,0],
        [0,0,0,1,1,0,0,0],
        [0,0,1,1,1,1,0,0],
    ]
    static let bomb: [[UInt8]] = [
        [0,0,0,3,3,0,0,0],
        [0,0,3,2,2,3,0,0],
        [0,1,1,1,1,1,1,0],
        [1,1,2,1,1,2,1,1],
        [1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,0],
        [0,1,1,1,1,1,0,0],
        [0,0,1,1,1,0,0,0],
    ]

    // Obstacle Icons
    static let jelly: [[UInt8]] = [
        [0,0,1,1,1,1,0,0],
        [0,1,2,2,2,2,1,0],
        [1,1,2,1,1,2,1,1],
        [1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,0],
        [0,0,1,1,1,1,0,0],
        [0,0,0,3,3,0,0,0],
    ]
    static let ice: [[UInt8]] = [
        [0,0,4,0,0,4,0,0],
        [0,4,4,4,4,4,4,0],
        [4,4,2,4,4,2,4,4],
        [0,4,4,4,4,4,4,0],
        [0,4,4,4,4,4,4,0],
        [4,4,2,4,4,2,4,4],
        [0,4,4,4,4,4,4,0],
        [0,0,4,0,0,4,0,0],
    ]

    // Star icon
    static let starIcon: [[UInt8]] = [
        [0,0,0,1,1,0,0,0],
        [0,0,0,2,2,0,0,0],
        [1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,0],
        [0,0,1,2,2,1,0,0],
        [0,1,1,0,0,1,1,0],
        [0,1,0,0,0,0,1,0],
        [1,0,0,0,0,0,0,1],
    ]

    // Coin icon
    static let coin: [[UInt8]] = [
        [0,0,1,1,1,1,0,0],
        [0,1,1,2,2,1,1,0],
        [1,1,2,1,2,1,1,1],
        [1,1,1,3,1,2,1,1],
        [1,1,1,3,1,2,1,1],
        [1,1,2,1,2,1,1,1],
        [0,1,1,2,2,1,1,0],
        [0,0,1,1,1,1,0,0],
    ]

    // Diamond icon
    static let diamond: [[UInt8]] = [
        [0,0,0,2,2,0,0,0],
        [0,0,1,2,2,1,0,0],
        [0,1,1,2,2,1,1,0],
        [1,1,1,1,1,1,1,1],
        [1,1,1,1,1,1,1,0],
        [0,1,1,1,1,1,0,0],
        [0,0,1,1,1,0,0,0],
        [0,0,0,1,0,0,0,0],
    ]

    // Heart (lives)
    static let heart: [[UInt8]] = [
        [0,1,1,0,0,1,1,0],
        [1,1,1,1,1,1,1,1],
        [1,2,1,1,1,1,2,1],
        [1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,0],
        [0,0,1,1,1,1,0,0],
        [0,0,0,1,1,0,0,0],
        [0,0,0,0,0,0,0,0],
    ]

    // Striped H gem overlay
    static let stripeH: [[UInt8]] = [
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [4,4,4,4,4,4,4,4],
        [4,4,4,4,4,4,4,4],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0],
    ]
    // Striped V gem overlay
    static let stripeV: [[UInt8]] = [
        [0,0,0,4,4,0,0,0],
        [0,0,0,4,4,0,0,0],
        [0,0,0,4,4,0,0,0],
        [0,0,0,4,4,0,0,0],
        [0,0,0,4,4,0,0,0],
        [0,0,0,4,4,0,0,0],
        [0,0,0,4,4,0,0,0],
        [0,0,0,4,4,0,0,0],
    ]
    // Wrapped bomb overlay
    static let wrappedDots: [[UInt8]] = [
        [0,0,0,0,0,0,0,0],
        [0,4,0,0,0,0,4,0],
        [0,0,4,0,0,4,0,0],
        [0,0,0,4,4,0,0,0],
        [0,0,0,4,4,0,0,0],
        [0,0,4,0,0,4,0,0],
        [0,4,0,0,0,0,4,0],
        [0,0,0,0,0,0,0,0],
    ]
    // Color bomb - swirl
    static let swirl: [[UInt8]] = [
        [0,0,1,2,3,0,0,0],
        [0,1,1,2,3,3,0,0],
        [1,1,0,0,0,3,3,0],
        [1,0,0,0,0,0,3,0],
        [0,3,0,0,0,0,1,0],
        [0,3,3,0,0,1,1,0],
        [0,0,3,3,2,1,0,0],
        [0,0,0,3,2,0,0,0],
    ]
}

// MARK: - PixelArt Renderer

final class PixelArt {

    static let shared = PixelArt()
    private var cache: [String: SKTexture] = [:]
    private init() {}

    // MARK: - Gem Texture

    func gemTexture(color: GemColor, special: TileSpecial) -> SKTexture {
        let key = "gem_\(color.rawValue)_\(special.rawValue)"
        if let cached = cache[key] { return cached }

        let size = CGSize(width: 64, height: 64)
        let img = render(size: size) { ctx in
            drawGemBase(ctx, color: color, size: size)
            drawGemIcon(ctx, color: color, size: size)
            if special != .none {
                drawSpecialOverlay(ctx, special: special, size: size)
            }
        }
        let tex = SKTexture(image: img)
        cache[key] = tex
        return tex
    }

    // MARK: - Obstacle Overlay Texture

    func obstacleTexture(type: ObstacleType, size: CGFloat = 64) -> SKTexture {
        let key = "obs_\(type.rawValue)_\(Int(size))"
        if let cached = cache[key] { return cached }

        let sz = CGSize(width: size, height: size)
        let img = render(size: sz) { ctx in
            drawObstacle(ctx, type: type, size: sz)
        }
        let tex = SKTexture(image: img)
        cache[key] = tex
        return tex
    }

    // MARK: - Icon Texture

    func iconTexture(pixels: [[UInt8]],
                     primary: UIColor, light: UIColor, dark: UIColor,
                     size: CGFloat = 40) -> SKTexture {
        let sz = CGSize(width: size, height: size)
        let img = render(size: sz) { ctx in
            drawPixels(ctx, pixels: pixels, primary: primary, light: light,
                       dark: dark, white: .white, size: sz)
        }
        return SKTexture(image: img)
    }

    func cachedIcon(_ name: String, pixels: [[UInt8]],
                    primary: UIColor = .white, light: UIColor = .white,
                    dark: UIColor = .gray, size: CGFloat = 40) -> SKTexture {
        let key = "icon_\(name)_\(Int(size))"
        if let cached = cache[key] { return cached }
        let t = iconTexture(pixels: pixels, primary: primary, light: light, dark: dark, size: size)
        cache[key] = t
        return t
    }

    // MARK: - Board Cell Background

    func cellTexture(size: CGFloat = 64, isHole: Bool = false) -> SKTexture {
        let key = "cell_\(isHole ? "h" : "n")_\(Int(size))"
        if let cached = cache[key] { return cached }

        let sz = CGSize(width: size, height: size)
        let img = render(size: sz) { ctx in
            if !isHole {
                UIColor(hex: "#1C3A5C").withAlphaComponent(0.7).setFill()
                let inset = sz.width * 0.06
                let rect = CGRect(x: inset, y: inset, width: sz.width - inset*2, height: sz.height - inset*2)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 4)
                ctx.addPath(path.cgPath); ctx.fillPath()
            }
        }
        let tex = SKTexture(image: img)
        cache[key] = tex
        return tex
    }

    // MARK: - Particle Burst Texture

    func particleTexture(color: UIColor, size: CGFloat = 8) -> SKTexture {
        let key = "particle_\(Int(color.hsba.h * 360))_\(Int(size))"
        if let cached = cache[key] { return cached }

        let sz = CGSize(width: size, height: size)
        let img = render(size: sz) { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: sz))
        }
        let tex = SKTexture(image: img)
        cache[key] = tex
        return tex
    }

    // MARK: - Private Draw Helpers

    private func render(size: CGSize, draw: (CGContext) -> Void) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in draw(ctx.cgContext) }
    }

    private func drawGemBase(_ ctx: CGContext, color: GemColor, size: CGSize) {
        let w = size.width, h = size.height
        let inset: CGFloat = 2
        let cornerR: CGFloat = 8

        // Outer shadow/border
        color.dark.setFill()
        let outerRect = CGRect(x: inset, y: inset + 3, width: w - inset*2, height: h - inset*2 - 3)
        let outerPath = UIBezierPath(roundedRect: outerRect, cornerRadius: cornerR)
        ctx.addPath(outerPath.cgPath); ctx.fillPath()

        // Main gem body
        color.primary.setFill()
        let bodyRect = CGRect(x: inset, y: inset, width: w - inset*2, height: h - inset*2 - 3)
        let bodyPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: cornerR)
        ctx.addPath(bodyPath.cgPath); ctx.fillPath()

        // Top highlight (upper-left quadrant lighter)
        let hlColor = color.light.withAlphaComponent(0.55)
        hlColor.setFill()
        let hlRect = CGRect(x: inset + 4, y: inset + 3, width: (w - inset*2) * 0.45, height: (h - inset*2 - 3) * 0.40)
        let hlPath = UIBezierPath(roundedRect: hlRect, cornerRadius: 3)
        ctx.addPath(hlPath.cgPath); ctx.fillPath()

        // Pixel border lines (top)
        UIColor.white.withAlphaComponent(0.25).setFill()
        let topLine = CGRect(x: inset + cornerR/2, y: inset, width: w - inset*2 - cornerR, height: 2)
        ctx.fill(topLine)
    }

    private func drawGemIcon(_ ctx: CGContext, color: GemColor, size: CGSize) {
        let icon: [[UInt8]]
        switch color {
        case .red:    icon = PixelIcons.flame
        case .blue:   icon = PixelIcons.drop
        case .green:  icon = PixelIcons.leaf
        case .yellow: icon = PixelIcons.star
        case .purple: icon = PixelIcons.bolt
        case .orange: icon = PixelIcons.sun
        }
        let inset: CGFloat = 10
        let drawSize = CGSize(width: size.width - inset*2, height: size.height - inset*2)
        drawPixels(ctx, pixels: icon,
                   primary: color.dark,
                   light: UIColor.white.withAlphaComponent(0.85),
                   dark: color.dark.darker(by: 0.2),
                   white: UIColor.white,
                   size: drawSize,
                   offset: CGPoint(x: inset, y: inset))
    }

    private func drawSpecialOverlay(_ ctx: CGContext, special: TileSpecial, size: CGSize) {
        let overlayPixels: [[UInt8]]
        switch special {
        case .stripedH:   overlayPixels = PixelIcons.stripeH
        case .stripedV:   overlayPixels = PixelIcons.stripeV
        case .wrapped:    overlayPixels = PixelIcons.wrappedDots
        case .colorBomb:  overlayPixels = PixelIcons.swirl
        case .none:       return
        }

        let overlayColor: UIColor = special == .colorBomb ? .white : UIColor.white.withAlphaComponent(0.9)
        let inset: CGFloat = 4
        let ds = CGSize(width: size.width - inset*2, height: size.height - inset*2)

        // For color bomb, use rainbow coloring
        if special == .colorBomb {
            drawRainbowPixels(ctx, pixels: overlayPixels, size: ds, offset: CGPoint(x: inset, y: inset))
        } else {
            drawPixels(ctx, pixels: overlayPixels,
                       primary: overlayColor, light: overlayColor, dark: overlayColor, white: overlayColor,
                       size: ds, offset: CGPoint(x: inset, y: inset))
        }
    }

    private func drawObstacle(_ ctx: CGContext, type: ObstacleType, size: CGSize) {
        switch type {
        case .jelly1:
            UIColor(hex: "#FF69B4").withAlphaComponent(0.55).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            drawPixels(ctx, pixels: PixelIcons.jelly,
                       primary: UIColor(hex: "#FF1493"),
                       light: UIColor(hex: "#FFB6C1"),
                       dark: UIColor(hex: "#C71585"),
                       white: .white, size: size)
        case .jelly2:
            UIColor(hex: "#9400D3").withAlphaComponent(0.55).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            drawPixels(ctx, pixels: PixelIcons.jelly,
                       primary: UIColor(hex: "#8B008B"),
                       light: UIColor(hex: "#DA70D6"),
                       dark: UIColor(hex: "#4B0082"),
                       white: .white, size: size)
        case .ice:
            UIColor(hex: "#B0E2FF").withAlphaComponent(0.45).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            drawPixels(ctx, pixels: PixelIcons.ice,
                       primary: UIColor(hex: "#87CEEB"),
                       light: UIColor.white.withAlphaComponent(0.9),
                       dark: UIColor(hex: "#4682B4"),
                       white: .white, size: size)
        case .chocolate:
            UIColor(hex: "#8B4513").setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let border = UIColor(hex: "#4A2000")
            border.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: 3))
            ctx.fill(CGRect(x: 0, y: size.height - 3, width: size.width, height: 3))
        case .stone:
            UIColor(hex: "#808080").setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(hex: "#A0A0A0").setFill()
            ctx.fill(CGRect(x: 2, y: 2, width: size.width*0.4, height: size.height*0.3))
        default: break
        }
    }

    private func drawPixels(_ ctx: CGContext,
                             pixels: [[UInt8]],
                             primary: UIColor, light: UIColor, dark: UIColor, white: UIColor,
                             size: CGSize,
                             offset: CGPoint = .zero) {
        guard !pixels.isEmpty else { return }
        let rows = pixels.count
        let cols = pixels[0].count
        let px = size.width / CGFloat(cols)
        let py = size.height / CGFloat(rows)

        for r in 0..<rows {
            for c in 0..<cols {
                let v = pixels[r][c]
                guard v != 0 else { continue }
                let color: UIColor
                switch v {
                case 1: color = primary
                case 2: color = light
                case 3: color = dark
                case 4: color = white
                default: color = primary
                }
                color.setFill()
                let rect = CGRect(x: offset.x + CGFloat(c) * px,
                                  y: offset.y + CGFloat(r) * py,
                                  width: px, height: py)
                ctx.fill(rect)
            }
        }
    }

    private func drawRainbowPixels(_ ctx: CGContext, pixels: [[UInt8]], size: CGSize, offset: CGPoint) {
        guard !pixels.isEmpty else { return }
        let rows = pixels.count
        let cols = pixels[0].count
        let px = size.width / CGFloat(cols)
        let py = size.height / CGFloat(rows)

        let colors: [UIColor] = [
            UIColor(hex: "#FF3B30"), UIColor(hex: "#FF9500"),
            UIColor(hex: "#FFCC00"), UIColor(hex: "#34C759"),
            UIColor(hex: "#007AFF"), UIColor(hex: "#AF52DE")
        ]

        for r in 0..<rows {
            for c in 0..<cols {
                guard pixels[r][c] != 0 else { continue }
                let idx = (r * cols + c) % colors.count
                colors[idx].setFill()
                ctx.fill(CGRect(x: offset.x + CGFloat(c) * px,
                                y: offset.y + CGFloat(r) * py,
                                width: px, height: py))
            }
        }
    }

    // MARK: - Background Gradients

    func worldBgTexture(world: World, size: CGSize) -> SKTexture {
        let key = "wbg_\(world.id)_\(Int(size.width))"
        if let cached = cache[key] { return cached }

        let img = render(size: size) { ctx in
            let topColor = UIColor(hex: world.bgColorHex)
            let midColor = topColor.darker(by: 0.08)
            let botColor = topColor.darker(by: 0.2)

            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [topColor.cgColor, midColor.cgColor, botColor.cgColor] as CFArray,
                locations: [0, 0.5, 1])!
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: 0, y: size.height),
                                   options: [])

            // World-specific pixel decorations
            let themeColor = UIColor(hex: world.themeColorHex).withAlphaComponent(0.06)
            themeColor.setFill()

            let tileW: CGFloat = 32
            let cols = Int(size.width / tileW) + 1
            let rows = Int(size.height / tileW) + 1

            // Pixel grid dots
            for r in 0..<rows {
                for c in 0..<cols {
                    if (r + c) % 3 == 0 {
                        ctx.fill(CGRect(x: CGFloat(c) * tileW + tileW/2 - 1,
                                        y: CGFloat(r) * tileW + tileW/2 - 1,
                                        width: 2, height: 2))
                    }
                }
            }

            // World-specific accent lines
            let accentColor = UIColor(hex: world.themeColorHex).withAlphaComponent(0.04)
            accentColor.setFill()
            for i in stride(from: 0, to: size.width, by: 64) {
                ctx.fill(CGRect(x: i, y: 0, width: 1, height: size.height))
            }
            for i in stride(from: 0, to: size.height, by: 64) {
                ctx.fill(CGRect(x: 0, y: i, width: size.width, height: 1))
            }
        }
        let tex = SKTexture(image: img)
        cache[key] = tex
        return tex
    }

    // MARK: - Pixel Font Style Label Texture (for large numbers)

    func numberTexture(_ number: Int, color: UIColor, size: CGFloat = 32) -> SKTexture {
        let text = "\(number)"
        let sz = CGSize(width: size * CGFloat(text.count) * 0.7, height: size)
        let img = render(size: sz) { ctx in
            let attr: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Courier-Bold", size: size * 0.85) ?? UIFont.boldSystemFont(ofSize: size * 0.85),
                .foregroundColor: color,
            ]
            text.draw(at: .zero, withAttributes: attr)
        }
        return SKTexture(image: img)
    }

    func clearCache() { cache.removeAll() }
}

// MARK: - UIColor HSBA Helper

extension UIColor {
    var hsba: (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b, a)
    }
}
