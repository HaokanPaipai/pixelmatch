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
    static let chest: [[UInt8]] = [
        [0,0,3,3,3,3,0,0],
        [0,3,1,1,1,1,3,0],
        [3,1,2,2,2,2,1,3],
        [3,1,1,1,1,1,1,3],
        [3,1,1,4,4,1,1,3],
        [3,1,1,4,4,1,1,3],
        [0,3,1,1,1,1,3,0],
        [0,0,3,3,3,3,0,0],
    ]
    static let key: [[UInt8]] = [
        [0,0,2,2,2,0,0,0],
        [0,2,1,1,1,2,0,0],
        [0,2,1,0,1,2,0,0],
        [0,0,2,1,2,0,0,0],
        [0,0,0,1,1,1,1,0],
        [0,0,0,1,0,0,1,0],
        [0,0,0,1,1,0,1,0],
        [0,0,0,0,1,1,0,0],
    ]
    static let lock: [[UInt8]] = [
        [0,0,2,2,2,2,0,0],
        [0,2,1,1,1,1,2,0],
        [0,2,1,0,0,1,2,0],
        [1,1,1,1,1,1,1,1],
        [1,2,2,4,4,2,2,1],
        [1,2,2,4,4,2,2,1],
        [1,1,2,2,2,2,1,1],
        [0,1,1,1,1,1,1,0],
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
        let key = "gem_soft_1_\(color.rawValue)_\(special.rawValue)"
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
        tex.filteringMode = .linear
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
        tex.filteringMode = .linear
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
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        return tex
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

    func cellTexture(size: CGFloat = 64, isHole: Bool = false, world: World? = nil, variant: Int = 0) -> SKTexture {
        let key = "cell_soft_1_\(isHole ? "h" : "n")_\(world?.id ?? 0)_\(variant)_\(Int(size))"
        if let cached = cache[key] { return cached }

        let sz = CGSize(width: size, height: size)
        let img = render(size: sz) { ctx in
            if !isHole {
                drawWorldCell(ctx, size: sz, world: world, variant: variant)
            }
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        cache[key] = tex
        return tex
    }

    // MARK: - Particle Burst Texture

    func particleTexture(color: UIColor, size: CGFloat = 8) -> SKTexture {
        let key = "particle_soft_1_\(Int(color.hsba.h * 360))_\(Int(size * 10))"
        if let cached = cache[key] { return cached }

        let sz = CGSize(width: size, height: size)
        let img = render(size: sz) { ctx in
            let rect = CGRect(origin: .zero, size: sz).insetBy(dx: size * 0.08, dy: size * 0.08)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: size * 0.24)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 0.6),
                          blur: 1.1,
                          color: color.withAlphaComponent(0.30).cgColor)
            color.withAlphaComponent(0.82).setFill()
            ctx.addPath(path.cgPath)
            ctx.fillPath()
            ctx.restoreGState()

            UIColor.white.withAlphaComponent(0.32).setFill()
            ctx.fillEllipse(in: CGRect(x: rect.minX + rect.width * 0.18,
                                       y: rect.minY + rect.height * 0.16,
                                       width: rect.width * 0.34,
                                       height: rect.height * 0.28))
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        cache[key] = tex
        return tex
    }

    // MARK: - Private Draw Helpers

    private func render(size: CGSize, draw: (CGContext) -> Void) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            ctx.cgContext.setAllowsAntialiasing(true)
            ctx.cgContext.setShouldAntialias(true)
            ctx.cgContext.interpolationQuality = .high
            draw(ctx.cgContext)
        }
    }

    private func drawGemBase(_ ctx: CGContext, color: GemColor, size: CGSize) {
        let w = size.width, h = size.height
        let inset: CGFloat = 4
        let cornerR: CGFloat = 13

        let shadowRect = CGRect(x: inset + 1, y: inset + 5, width: w - inset * 2 - 2, height: h - inset * 2 - 6)
        let shadowPath = UIBezierPath(roundedRect: shadowRect, cornerRadius: cornerR)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.28).cgColor)
        color.dark.withAlphaComponent(0.72).setFill()
        ctx.addPath(shadowPath.cgPath); ctx.fillPath()
        ctx.restoreGState()

        let bodyRect = CGRect(x: inset, y: inset + 1, width: w - inset * 2, height: h - inset * 2 - 5)
        let bodyPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: cornerR)
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [
                                    color.light.withAlphaComponent(0.96).cgColor,
                                    color.primary.cgColor,
                                    color.dark.cgColor
                                  ] as CFArray,
                                  locations: [0.0, 0.55, 1.0])!

        ctx.saveGState()
        ctx.addPath(bodyPath.cgPath)
        ctx.clip()
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: bodyRect.midX, y: bodyRect.minY),
                               end: CGPoint(x: bodyRect.midX, y: bodyRect.maxY),
                               options: [])

        let glossRect = CGRect(x: bodyRect.minX + 6,
                               y: bodyRect.minY + 5,
                               width: bodyRect.width * 0.58,
                               height: bodyRect.height * 0.38)
        let gloss = UIBezierPath(ovalIn: glossRect)
        UIColor.white.withAlphaComponent(0.22).setFill()
        ctx.addPath(gloss.cgPath); ctx.fillPath()

        drawMicroPixelAccents(ctx, rect: bodyRect, color: color)
        ctx.restoreGState()

        UIColor.white.withAlphaComponent(0.34).setStroke()
        bodyPath.lineWidth = 1.4
        bodyPath.stroke()

        color.dark.withAlphaComponent(0.55).setStroke()
        let lowerRim = UIBezierPath()
        lowerRim.move(to: CGPoint(x: bodyRect.minX + cornerR * 0.5, y: bodyRect.maxY - 1))
        lowerRim.addLine(to: CGPoint(x: bodyRect.maxX - cornerR * 0.5, y: bodyRect.maxY - 1))
        lowerRim.lineWidth = 2
        lowerRim.stroke()
    }

    private func drawMicroPixelAccents(_ ctx: CGContext, rect: CGRect, color: GemColor) {
        let accents: [(CGFloat, CGFloat, CGFloat, UIColor)] = [
            (0.23, 0.23, 3.0, UIColor.white.withAlphaComponent(0.34)),
            (0.72, 0.28, 2.2, color.light.withAlphaComponent(0.24)),
            (0.28, 0.68, 2.4, UIColor.white.withAlphaComponent(0.16)),
            (0.76, 0.72, 3.0, color.dark.withAlphaComponent(0.20)),
        ]

        for accent in accents {
            let size = accent.2
            let point = CGPoint(x: rect.minX + rect.width * accent.0,
                                y: rect.minY + rect.height * accent.1)
            let pixel = CGRect(x: point.x - size / 2,
                               y: point.y - size / 2,
                               width: size,
                               height: size)
            accent.3.setFill()
            ctx.addPath(UIBezierPath(roundedRect: pixel, cornerRadius: 0.8).cgPath)
            ctx.fillPath()
        }
    }

    private func drawGemIcon(_ ctx: CGContext, color: GemColor, size: CGSize) {
        let rect = CGRect(x: size.width * 0.26,
                          y: size.height * 0.24,
                          width: size.width * 0.48,
                          height: size.height * 0.50)
        drawGemSymbol(ctx, color: color, rect: rect)
    }

    private func drawGemSymbol(_ ctx: CGContext, color: GemColor, rect: CGRect) {
        let fill = color.dark.withAlphaComponent(0.82)
        switch color {
        case .red:
            drawSymbolPath(flamePath(in: rect), fill: fill, in: ctx)
            drawInnerDrop(ctx, in: rect.insetBy(dx: rect.width * 0.32, dy: rect.height * 0.30),
                          color: UIColor.white.withAlphaComponent(0.36))
        case .blue:
            drawSymbolPath(dropPath(in: rect), fill: fill, in: ctx)
            drawInnerDrop(ctx, in: rect.insetBy(dx: rect.width * 0.36, dy: rect.height * 0.28),
                          color: UIColor.white.withAlphaComponent(0.36))
        case .green:
            drawSymbolPath(leafPath(in: rect), fill: fill, in: ctx)
            drawSymbolLine(ctx,
                           from: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY - rect.height * 0.18),
                           to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.26),
                           color: UIColor.white.withAlphaComponent(0.34),
                           width: 1.7)
        case .yellow:
            drawSymbolPath(starPath(center: CGPoint(x: rect.midX, y: rect.midY),
                                    outerRadius: rect.width * 0.48,
                                    innerRadius: rect.width * 0.22,
                                    points: 5),
                           fill: fill,
                           in: ctx)
        case .purple:
            drawSymbolPath(boltPath(in: rect), fill: fill, in: ctx)
        case .orange:
            drawSunSymbol(ctx, color: fill, rect: rect)
        }
    }

    private func drawSymbolPath(_ path: UIBezierPath, fill: UIColor, in ctx: CGContext) {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 1.4),
                      blur: 2,
                      color: UIColor.black.withAlphaComponent(0.22).cgColor)
        fill.setFill()
        path.fill()
        ctx.restoreGState()

        UIColor.white.withAlphaComponent(0.42).setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    private func drawSymbolLine(_ ctx: CGContext,
                                from: CGPoint,
                                to: CGPoint,
                                color: UIColor,
                                width: CGFloat) {
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineWidth(width)
        ctx.setStrokeColor(color.cgColor)
        ctx.move(to: from)
        ctx.addLine(to: to)
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawInnerDrop(_ ctx: CGContext, in rect: CGRect, color: UIColor) {
        color.setFill()
        ctx.addPath(UIBezierPath(ovalIn: rect).cgPath)
        ctx.fillPath()
    }

    private func flamePath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.midY + rect.height * 0.12),
                      controlPoint1: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY - rect.height * 0.04),
                      controlPoint2: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.28))
        path.addCurve(to: CGPoint(x: rect.midX - rect.width * 0.04, y: rect.minY + rect.height * 0.12),
                      controlPoint1: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.42),
                      controlPoint2: CGPoint(x: rect.midX - rect.width * 0.26, y: rect.minY + rect.height * 0.28))
        path.addCurve(to: CGPoint(x: rect.midX + rect.width * 0.24, y: rect.minY),
                      controlPoint1: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.minY + rect.height * 0.18),
                      controlPoint2: CGPoint(x: rect.midX + rect.width * 0.08, y: rect.minY + rect.height * 0.02))
        path.addCurve(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.midY + rect.height * 0.14),
                      controlPoint1: CGPoint(x: rect.midX + rect.width * 0.26, y: rect.minY + rect.height * 0.28),
                      controlPoint2: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.34))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                      controlPoint1: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.18),
                      controlPoint2: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.maxY))
        path.close()
        return path
    }

    private func dropPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY + rect.height * 0.20),
                      controlPoint1: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.22),
                      controlPoint2: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.38))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                      controlPoint1: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.10),
                      controlPoint2: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.20),
                      controlPoint1: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY),
                      controlPoint2: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.10))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                      controlPoint1: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.38),
                      controlPoint2: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.22))
        path.close()
        return path
    }

    private func leafPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.maxY - rect.height * 0.30))
        path.addCurve(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY + rect.height * 0.08),
                      controlPoint1: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.08),
                      controlPoint2: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.minY - rect.height * 0.02))
        path.addCurve(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.maxY - rect.height * 0.30),
                      controlPoint1: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.56),
                      controlPoint2: CGPoint(x: rect.midX, y: rect.maxY))
        path.close()
        return path
    }

    private func boltPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.56, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.midY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.34, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.midY - rect.height * 0.10))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.06, y: rect.midY - rect.height * 0.10))
        path.close()
        return path
    }

    private func starPath(center: CGPoint,
                          outerRadius: CGFloat,
                          innerRadius: CGFloat,
                          points: Int) -> UIBezierPath {
        let path = UIBezierPath()
        let total = points * 2
        for i in 0..<total {
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = -.pi / 2 + CGFloat(i) * .pi / CGFloat(points)
            let point = CGPoint(x: center.x + cos(angle) * radius,
                                y: center.y + sin(angle) * radius)
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.close()
        return path
    }

    private func drawSunSymbol(_ ctx: CGContext, color: UIColor, rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let inner = min(rect.width, rect.height) * 0.30
        let outer = min(rect.width, rect.height) * 0.48

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 1.4),
                      blur: 2,
                      color: UIColor.black.withAlphaComponent(0.22).cgColor)
        ctx.setLineCap(.round)
        ctx.setLineWidth(3)
        ctx.setStrokeColor(color.cgColor)
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            ctx.move(to: CGPoint(x: center.x + cos(angle) * (inner + 2),
                                 y: center.y + sin(angle) * (inner + 2)))
            ctx.addLine(to: CGPoint(x: center.x + cos(angle) * outer,
                                    y: center.y + sin(angle) * outer))
            ctx.strokePath()
        }
        color.setFill()
        ctx.addPath(UIBezierPath(ovalIn: CGRect(x: center.x - inner,
                                                y: center.y - inner,
                                                width: inner * 2,
                                                height: inner * 2)).cgPath)
        ctx.fillPath()
        ctx.restoreGState()

        UIColor.white.withAlphaComponent(0.42).setStroke()
        let circle = UIBezierPath(ovalIn: CGRect(x: center.x - inner,
                                                y: center.y - inner,
                                                width: inner * 2,
                                                height: inner * 2))
        circle.lineWidth = 1.5
        circle.stroke()
    }

    private func drawSpecialOverlay(_ ctx: CGContext, special: TileSpecial, size: CGSize) {
        switch special {
        case .stripedH:
            drawStripedOverlay(ctx, size: size, horizontal: true)
        case .stripedV:
            drawStripedOverlay(ctx, size: size, horizontal: false)
        case .wrapped:
            drawWrappedOverlay(ctx, size: size)
        case .colorBomb:
            drawColorBombOverlay(ctx, size: size)
        case .none:
            return
        }
    }

    private func drawObstacle(_ ctx: CGContext, type: ObstacleType, size: CGSize) {
        switch type {
        case .jelly1:
            drawJellyObstacle(ctx, size: size, layers: 1)
        case .jelly2:
            drawJellyObstacle(ctx, size: size, layers: 2)
        case .ice:
            drawIceObstacle(ctx, size: size)
        case .chocolate:
            drawChocolateObstacle(ctx, size: size)
        case .stone:
            drawStoneObstacle(ctx, size: size)
        case .cage:
            drawCageObstacle(ctx, size: size)
        case .chest1, .chest2:
            drawChestObstacle(ctx, size: size, reinforced: type == .chest2)
        case .key:
            drawKeyObstacle(ctx, size: size)
        case .lock:
            drawLockObstacle(ctx, size: size)
        default: break
        }
    }

    private func drawWorldCell(_ ctx: CGContext, size: CGSize, world: World?, variant: Int) {
        let inset = size.width * 0.06
        let rect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 7)
        let bg = world?.bgColor ?? UIColor(hex: "#1C3A5C")
        let theme = world?.themeColor ?? UIColor(hex: "#66D9FF")
        let lift = variant.isMultiple(of: 2) ? 0.08 : 0.02
        let top = bg.lighter(by: lift).withAlphaComponent(0.78)
        let bottom = bg.darker(by: 0.08).withAlphaComponent(0.82)
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [top.cgColor, bottom.cgColor] as CFArray,
                                  locations: [0, 1])!

        ctx.saveGState()
        ctx.addPath(path.cgPath)
        ctx.clip()
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: rect.midX, y: rect.minY),
                               end: CGPoint(x: rect.midX, y: rect.maxY),
                               options: [])
        drawWorldCellMotif(ctx, rect: rect, world: world, theme: theme)
        ctx.restoreGState()

        theme.withAlphaComponent(variant.isMultiple(of: 2) ? 0.24 : 0.16).setStroke()
        path.lineWidth = 1.2
        path.stroke()

        UIColor.white.withAlphaComponent(0.08).setFill()
        ctx.fill(CGRect(x: rect.minX + 5, y: rect.minY + 4, width: rect.width * 0.36, height: 1.5))
    }

    private func drawWorldCellMotif(_ ctx: CGContext, rect: CGRect, world: World?, theme: UIColor) {
        guard let world else {
            theme.withAlphaComponent(0.08).setFill()
            ctx.fill(CGRect(x: rect.midX - 1, y: rect.midY - 1, width: 2, height: 2))
            return
        }

        switch world.id {
        case 1:
            theme.withAlphaComponent(0.12).setFill()
            ctx.addPath(leafPath(in: rect.insetBy(dx: rect.width * 0.34, dy: rect.height * 0.34)).cgPath)
            ctx.fillPath()
        case 2:
            drawSymbolLine(ctx,
                           from: CGPoint(x: rect.minX + 6, y: rect.midY + 3),
                           to: CGPoint(x: rect.maxX - 6, y: rect.midY - 4),
                           color: theme.withAlphaComponent(0.12),
                           width: 2)
        case 3:
            drawSparkle(ctx,
                        center: CGPoint(x: rect.maxX - 11, y: rect.minY + 11),
                        radius: 3,
                        color: theme.withAlphaComponent(0.16))
        case 4:
            drawCrack(ctx,
                      points: [
                        CGPoint(x: rect.minX + 9, y: rect.maxY - 11),
                        CGPoint(x: rect.midX - 1, y: rect.midY),
                        CGPoint(x: rect.maxX - 10, y: rect.minY + 12),
                      ],
                      color: theme.withAlphaComponent(0.14),
                      width: 1.8)
        case 5:
            drawCrack(ctx,
                      points: [
                        CGPoint(x: rect.minX + 10, y: rect.minY + 12),
                        CGPoint(x: rect.midX, y: rect.midY),
                        CGPoint(x: rect.maxX - 12, y: rect.maxY - 10),
                      ],
                      color: UIColor.white.withAlphaComponent(0.16),
                      width: 1.6)
        case 6:
            drawSymbolLine(ctx,
                           from: CGPoint(x: rect.minX + 7, y: rect.maxY - 9),
                           to: CGPoint(x: rect.maxX - 7, y: rect.minY + 9),
                           color: theme.withAlphaComponent(0.18),
                           width: 1.6)
        case 7:
            for offset in stride(from: rect.minX + 8, to: rect.maxX - 8, by: 7) {
                UIColor(hex: "#FFCC00").withAlphaComponent(0.10).setFill()
                ctx.fill(CGRect(x: offset, y: rect.minY + 8, width: 2, height: rect.height - 16))
            }
        case 8:
            for point in [
                CGPoint(x: rect.minX + 12, y: rect.minY + 13),
                CGPoint(x: rect.maxX - 12, y: rect.maxY - 13),
            ] {
                drawSparkle(ctx, center: point, radius: 2.6, color: UIColor.white.withAlphaComponent(0.14))
            }
        case 9:
            drawCrack(ctx,
                      points: [
                        CGPoint(x: rect.minX + 8, y: rect.maxY - 8),
                        CGPoint(x: rect.midX, y: rect.minY + 12),
                        CGPoint(x: rect.maxX - 8, y: rect.maxY - 8),
                      ],
                      color: theme.withAlphaComponent(0.12),
                      width: 1.8)
        default:
            drawColorRing(ctx, rect: rect.insetBy(dx: rect.width * 0.30, dy: rect.height * 0.30), color: theme.withAlphaComponent(0.14))
        }
    }

    private func drawColorRing(_ ctx: CGContext, rect: CGRect, color: UIColor) {
        color.setStroke()
        let ring = UIBezierPath(ovalIn: rect)
        ring.lineWidth = 1.8
        ring.stroke()
    }

    private func drawStripedOverlay(_ ctx: CGContext, size: CGSize, horizontal: Bool) {
        let bandRect: CGRect
        if horizontal {
            bandRect = CGRect(x: size.width * 0.12,
                              y: size.height * 0.43,
                              width: size.width * 0.76,
                              height: size.height * 0.14)
        } else {
            bandRect = CGRect(x: size.width * 0.43,
                              y: size.height * 0.12,
                              width: size.width * 0.14,
                              height: size.height * 0.76)
        }

        let shadow = UIBezierPath(roundedRect: bandRect.insetBy(dx: -2, dy: -2), cornerRadius: 6)
        UIColor.black.withAlphaComponent(0.18).setFill()
        ctx.addPath(shadow.cgPath); ctx.fillPath()

        let band = UIBezierPath(roundedRect: bandRect, cornerRadius: 5)
        UIColor.white.withAlphaComponent(0.82).setFill()
        ctx.addPath(band.cgPath); ctx.fillPath()

        let lightRect = horizontal
            ? CGRect(x: bandRect.minX + 3, y: bandRect.minY + 2, width: bandRect.width - 6, height: 2)
            : CGRect(x: bandRect.minX + 2, y: bandRect.minY + 3, width: 2, height: bandRect.height - 6)
        UIColor(hex: "#FFF6B8").withAlphaComponent(0.82).setFill()
        ctx.addPath(UIBezierPath(roundedRect: lightRect, cornerRadius: 1).cgPath)
        ctx.fillPath()

        let sparklePositions: [CGPoint] = horizontal
            ? [CGPoint(x: size.width * 0.20, y: size.height * 0.30),
               CGPoint(x: size.width * 0.80, y: size.height * 0.70)]
            : [CGPoint(x: size.width * 0.30, y: size.height * 0.20),
               CGPoint(x: size.width * 0.70, y: size.height * 0.80)]
        for point in sparklePositions {
            drawSparkle(ctx, center: point, radius: 4, color: UIColor.white.withAlphaComponent(0.76))
        }
    }

    private func drawWrappedOverlay(_ ctx: CGContext, size: CGSize) {
        let rect = CGRect(x: size.width * 0.16,
                          y: size.height * 0.16,
                          width: size.width * 0.68,
                          height: size.height * 0.68)
        let ring = UIBezierPath(roundedRect: rect, cornerRadius: 15)
        ctx.saveGState()
        ctx.setLineDash(phase: 0, lengths: [8, 6])
        UIColor.white.withAlphaComponent(0.78).setStroke()
        ring.lineWidth = 3
        ring.stroke()
        ctx.restoreGState()

        UIColor(hex: "#FFE066").withAlphaComponent(0.34).setStroke()
        let inner = UIBezierPath(roundedRect: rect.insetBy(dx: 5, dy: 5), cornerRadius: 10)
        inner.lineWidth = 2
        inner.stroke()

        for point in [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
        ] {
            drawSparkle(ctx, center: point, radius: 4.2, color: UIColor.white.withAlphaComponent(0.78))
        }
    }

    private func drawColorBombOverlay(_ ctx: CGContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = size.width * 0.24
        let outerRect = CGRect(x: center.x - radius,
                               y: center.y - radius,
                               width: radius * 2,
                               height: radius * 2)
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [
                                    UIColor.white.cgColor,
                                    UIColor(hex: "#101018").cgColor,
                                    UIColor(hex: "#000000").cgColor
                                  ] as CFArray,
                                  locations: [0.0, 0.58, 1.0])!

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.32).cgColor)
        ctx.addEllipse(in: outerRect)
        ctx.clip()
        ctx.drawRadialGradient(gradient,
                               startCenter: CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.35),
                               startRadius: 1,
                               endCenter: center,
                               endRadius: radius,
                               options: [])
        ctx.restoreGState()

        let colors = [
            UIColor(hex: "#FF3B30"),
            UIColor(hex: "#FF9500"),
            UIColor(hex: "#FFCC00"),
            UIColor(hex: "#34C759"),
            UIColor(hex: "#007AFF"),
            UIColor(hex: "#AF52DE"),
        ]
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineWidth(4)
        for (index, color) in colors.enumerated() {
            let start = CGFloat(index) * 2 * .pi / CGFloat(colors.count) - .pi / 2
            let end = start + 2 * .pi / CGFloat(colors.count) * 0.72
            ctx.setStrokeColor(color.withAlphaComponent(0.92).cgColor)
            ctx.addArc(center: center, radius: radius + 5, startAngle: start, endAngle: end, clockwise: false)
            ctx.strokePath()
        }
        ctx.restoreGState()

        drawSparkle(ctx,
                    center: CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.42),
                    radius: 4.5,
                    color: UIColor.white.withAlphaComponent(0.84))
    }

    private func drawJellyObstacle(_ ctx: CGContext, size: CGSize, layers: Int) {
        let baseRect = CGRect(x: size.width * 0.06,
                              y: size.height * 0.08,
                              width: size.width * 0.88,
                              height: size.height * 0.82)
        let baseColor = layers == 1 ? UIColor(hex: "#FF66CC") : UIColor(hex: "#A968FF")
        let edgeColor = layers == 1 ? UIColor(hex: "#D61B8C") : UIColor(hex: "#6C34C8")

        let path = UIBezierPath(roundedRect: baseRect, cornerRadius: 14)
        baseColor.withAlphaComponent(layers == 1 ? 0.36 : 0.48).setFill()
        ctx.addPath(path.cgPath); ctx.fillPath()

        edgeColor.withAlphaComponent(0.56).setStroke()
        path.lineWidth = layers == 1 ? 2 : 3
        path.stroke()

        UIColor.white.withAlphaComponent(0.40).setFill()
        let gloss = CGRect(x: baseRect.minX + 8,
                           y: baseRect.minY + 7,
                           width: baseRect.width * 0.48,
                           height: baseRect.height * 0.22)
        ctx.addPath(UIBezierPath(roundedRect: gloss, cornerRadius: 6).cgPath)
        ctx.fillPath()

        if layers == 2 {
            edgeColor.withAlphaComponent(0.36).setStroke()
            let inner = UIBezierPath(roundedRect: baseRect.insetBy(dx: 6, dy: 6), cornerRadius: 10)
            inner.lineWidth = 2
            inner.stroke()
        }
    }

    private func drawIceObstacle(_ ctx: CGContext, size: CGSize) {
        let rect = CGRect(x: size.width * 0.06,
                          y: size.height * 0.06,
                          width: size.width * 0.88,
                          height: size.height * 0.88)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 11)
        UIColor(hex: "#D8F5FF").withAlphaComponent(0.42).setFill()
        ctx.addPath(path.cgPath); ctx.fillPath()

        UIColor.white.withAlphaComponent(0.55).setFill()
        ctx.addPath(UIBezierPath(roundedRect: CGRect(x: rect.minX + 6,
                                                     y: rect.minY + 6,
                                                     width: rect.width * 0.36,
                                                     height: rect.height * 0.20),
                                  cornerRadius: 5).cgPath)
        ctx.fillPath()

        UIColor(hex: "#70C8FF").withAlphaComponent(0.64).setStroke()
        path.lineWidth = 2
        path.stroke()

        drawCrack(ctx,
                  points: [
                    CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.24),
                    CGPoint(x: rect.midX, y: rect.midY),
                    CGPoint(x: rect.maxX - rect.width * 0.24, y: rect.maxY - rect.height * 0.28),
                  ],
                  color: UIColor.white.withAlphaComponent(0.72),
                  width: 2)
        drawCrack(ctx,
                  points: [
                    CGPoint(x: rect.midX, y: rect.midY),
                    CGPoint(x: rect.minX + rect.width * 0.32, y: rect.maxY - rect.height * 0.20),
                  ],
                  color: UIColor(hex: "#6BBCEB").withAlphaComponent(0.56),
                  width: 1.4)
    }

    private func drawChocolateObstacle(_ ctx: CGContext, size: CGSize) {
        let rect = CGRect(x: size.width * 0.07,
                          y: size.height * 0.08,
                          width: size.width * 0.86,
                          height: size.height * 0.84)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        UIColor(hex: "#5B2D12").setFill()
        ctx.addPath(path.cgPath); ctx.fillPath()

        let tileInset: CGFloat = 4
        let tileW = (rect.width - tileInset * 3) / 2
        let tileH = (rect.height - tileInset * 3) / 2
        for row in 0..<2 {
            for col in 0..<2 {
                let tile = CGRect(x: rect.minX + tileInset + CGFloat(col) * (tileW + tileInset),
                                  y: rect.minY + tileInset + CGFloat(row) * (tileH + tileInset),
                                  width: tileW,
                                  height: tileH)
                let cell = UIBezierPath(roundedRect: tile, cornerRadius: 5)
                UIColor(hex: "#7A421E").setFill()
                ctx.addPath(cell.cgPath); ctx.fillPath()

                UIColor(hex: "#B06A33").withAlphaComponent(0.42).setFill()
                ctx.fill(CGRect(x: tile.minX + 3, y: tile.minY + 3, width: tile.width * 0.42, height: 2))
            }
        }

        UIColor(hex: "#2F1609").withAlphaComponent(0.78).setStroke()
        path.lineWidth = 2
        path.stroke()
    }

    private func drawStoneObstacle(_ ctx: CGContext, size: CGSize) {
        let rect = CGRect(x: size.width * 0.07,
                          y: size.height * 0.08,
                          width: size.width * 0.86,
                          height: size.height * 0.84)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [
                                    UIColor(hex: "#B7BEC8").cgColor,
                                    UIColor(hex: "#6F7782").cgColor,
                                    UIColor(hex: "#434A54").cgColor
                                  ] as CFArray,
                                  locations: [0.0, 0.58, 1.0])!
        ctx.saveGState()
        ctx.addPath(path.cgPath)
        ctx.clip()
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: rect.midX, y: rect.minY),
                               end: CGPoint(x: rect.midX, y: rect.maxY),
                               options: [])
        ctx.restoreGState()

        UIColor.white.withAlphaComponent(0.18).setFill()
        ctx.addPath(UIBezierPath(roundedRect: CGRect(x: rect.minX + 7,
                                                     y: rect.minY + 7,
                                                     width: rect.width * 0.36,
                                                     height: rect.height * 0.22),
                                  cornerRadius: 4).cgPath)
        ctx.fillPath()

        drawCrack(ctx,
                  points: [
                    CGPoint(x: rect.minX + rect.width * 0.24, y: rect.midY),
                    CGPoint(x: rect.midX, y: rect.midY + 4),
                    CGPoint(x: rect.maxX - rect.width * 0.26, y: rect.maxY - 9),
                  ],
                  color: UIColor(hex: "#2E343C").withAlphaComponent(0.58),
                  width: 1.8)
    }

    private func drawCageObstacle(_ ctx: CGContext, size: CGSize) {
        let bounds = CGRect(x: size.width * 0.09,
                            y: size.height * 0.08,
                            width: size.width * 0.82,
                            height: size.height * 0.84)
        UIColor(hex: "#0B1420").withAlphaComponent(0.18).setFill()
        ctx.addPath(UIBezierPath(roundedRect: bounds, cornerRadius: 8).cgPath)
        ctx.fillPath()

        for x in [bounds.minX + bounds.width * 0.24, bounds.midX, bounds.maxX - bounds.width * 0.24] {
            drawMetalLine(ctx,
                          from: CGPoint(x: x, y: bounds.minY + 2),
                          to: CGPoint(x: x, y: bounds.maxY - 2),
                          width: 4)
        }
        for y in [bounds.minY + bounds.height * 0.28, bounds.maxY - bounds.height * 0.28] {
            drawMetalLine(ctx,
                          from: CGPoint(x: bounds.minX + 2, y: y),
                          to: CGPoint(x: bounds.maxX - 2, y: y),
                          width: 4)
        }
    }

    private func drawChestObstacle(_ ctx: CGContext, size: CGSize, reinforced: Bool) {
        let rect = CGRect(x: size.width * 0.08,
                          y: size.height * 0.15,
                          width: size.width * 0.84,
                          height: size.height * 0.66)
        let body = UIBezierPath(roundedRect: rect, cornerRadius: 9)
        UIColor(hex: "#4B2A0A").withAlphaComponent(0.86).setFill()
        ctx.addPath(body.cgPath); ctx.fillPath()

        let lidRect = CGRect(x: rect.minX,
                             y: rect.minY,
                             width: rect.width,
                             height: rect.height * 0.43)
        UIColor(hex: reinforced ? "#B96A24" : "#D9952F").setFill()
        ctx.addPath(UIBezierPath(roundedRect: lidRect, cornerRadius: 9).cgPath)
        ctx.fillPath()

        UIColor(hex: reinforced ? "#C9842D" : "#F0B74B").setFill()
        ctx.addPath(UIBezierPath(roundedRect: CGRect(x: rect.minX + 4,
                                                     y: rect.minY + rect.height * 0.42,
                                                     width: rect.width - 8,
                                                     height: rect.height * 0.52),
                                  cornerRadius: 7).cgPath)
        ctx.fillPath()

        UIColor(hex: "#FFE082").setFill()
        let lock = CGRect(x: rect.midX - 5, y: rect.midY - 3, width: 10, height: 12)
        ctx.addPath(UIBezierPath(roundedRect: lock, cornerRadius: 3).cgPath)
        ctx.fillPath()

        UIColor(hex: "#5B3510").withAlphaComponent(0.9).setStroke()
        body.lineWidth = 2
        body.stroke()

        if reinforced {
            UIColor(hex: "#5B3510").withAlphaComponent(0.78).setStroke()
            drawSymbolLine(ctx,
                           from: CGPoint(x: rect.minX + 5, y: rect.minY + rect.height * 0.33),
                           to: CGPoint(x: rect.maxX - 5, y: rect.minY + rect.height * 0.33),
                           color: UIColor(hex: "#5B3510").withAlphaComponent(0.78),
                           width: 2.5)
            drawSymbolLine(ctx,
                           from: CGPoint(x: rect.minX + 5, y: rect.minY + rect.height * 0.70),
                           to: CGPoint(x: rect.maxX - 5, y: rect.minY + rect.height * 0.70),
                           color: UIColor(hex: "#5B3510").withAlphaComponent(0.78),
                           width: 2.5)
        }
    }

    private func drawKeyObstacle(_ ctx: CGContext, size: CGSize) {
        let glowRect = CGRect(x: size.width * 0.18,
                              y: size.height * 0.18,
                              width: size.width * 0.64,
                              height: size.height * 0.64)
        UIColor(hex: "#FFCC00").withAlphaComponent(0.18).setFill()
        ctx.addPath(UIBezierPath(ovalIn: glowRect).cgPath)
        ctx.fillPath()
        drawPixels(ctx, pixels: PixelIcons.key,
                   primary: UIColor(hex: "#FFCC00"),
                   light: UIColor(hex: "#FFF6A6"),
                   dark: UIColor(hex: "#B57400"),
                   white: .white,
                   size: CGSize(width: size.width * 0.78, height: size.height * 0.78),
                   offset: CGPoint(x: size.width * 0.11, y: size.height * 0.11))
    }

    private func drawLockObstacle(_ ctx: CGContext, size: CGSize) {
        let rect = CGRect(x: size.width * 0.10,
                          y: size.height * 0.16,
                          width: size.width * 0.80,
                          height: size.height * 0.68)
        UIColor(hex: "#102A44").withAlphaComponent(0.88).setFill()
        ctx.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 9).cgPath)
        ctx.fillPath()

        drawPixels(ctx, pixels: PixelIcons.lock,
                   primary: UIColor(hex: "#4A90E2"),
                   light: UIColor(hex: "#A8D8FF"),
                   dark: UIColor(hex: "#102A44"),
                   white: UIColor(hex: "#FFFFFF"),
                   size: CGSize(width: size.width * 0.78, height: size.height * 0.78),
                   offset: CGPoint(x: size.width * 0.11, y: size.height * 0.11))

        UIColor(hex: "#A8D8FF").withAlphaComponent(0.46).setStroke()
        let ring = UIBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: 7)
        ring.lineWidth = 2
        ring.stroke()
    }

    private func drawSparkle(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color: UIColor) {
        drawSymbolLine(ctx,
                       from: CGPoint(x: center.x - radius, y: center.y),
                       to: CGPoint(x: center.x + radius, y: center.y),
                       color: color,
                       width: 1.4)
        drawSymbolLine(ctx,
                       from: CGPoint(x: center.x, y: center.y - radius),
                       to: CGPoint(x: center.x, y: center.y + radius),
                       color: color,
                       width: 1.4)
    }

    private func drawCrack(_ ctx: CGContext,
                           points: [CGPoint],
                           color: UIColor,
                           width: CGFloat) {
        guard let first = points.first else { return }
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.move(to: first)
        for point in points.dropFirst() {
            ctx.addLine(to: point)
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawMetalLine(_ ctx: CGContext, from: CGPoint, to: CGPoint, width: CGFloat) {
        drawSymbolLine(ctx,
                       from: CGPoint(x: from.x + 1, y: from.y + 1),
                       to: CGPoint(x: to.x + 1, y: to.y + 1),
                       color: UIColor(hex: "#263241").withAlphaComponent(0.62),
                       width: width + 1)
        drawSymbolLine(ctx,
                       from: from,
                       to: to,
                       color: UIColor(hex: "#D6DEE8").withAlphaComponent(0.84),
                       width: width)
        drawSymbolLine(ctx,
                       from: from,
                       to: CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2),
                       color: UIColor.white.withAlphaComponent(0.46),
                       width: max(1, width * 0.35))
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
                let gap = max(0.35, min(px, py) * 0.08)
                let rect = CGRect(x: offset.x + CGFloat(c) * px,
                                  y: offset.y + CGFloat(r) * py,
                                  width: px, height: py).insetBy(dx: gap, dy: gap)
                let corner = min(rect.width, rect.height) * 0.18
                ctx.addPath(UIBezierPath(roundedRect: rect, cornerRadius: corner).cgPath)
                ctx.fillPath()
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
                let gap = max(0.35, min(px, py) * 0.08)
                let rect = CGRect(x: offset.x + CGFloat(c) * px,
                                  y: offset.y + CGFloat(r) * py,
                                  width: px, height: py).insetBy(dx: gap, dy: gap)
                let corner = min(rect.width, rect.height) * 0.18
                ctx.addPath(UIBezierPath(roundedRect: rect, cornerRadius: corner).cgPath)
                ctx.fillPath()
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
        tex.filteringMode = .linear
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
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        return tex
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
