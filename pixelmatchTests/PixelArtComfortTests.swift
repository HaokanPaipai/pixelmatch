import XCTest
import SpriteKit
@testable import pixelmatch

final class PixelArtComfortTests: XCTestCase {

    func testGemTexturesUseSoftAntialiasedRendering() {
        for color in GemColor.allCases {
            let texture = PixelArt.shared.gemTexture(color: color, special: .none)
            let stats = TextureStats(texture: texture)

            XCTAssertEqual(texture.filteringMode, .linear, "\(color) should avoid chunky nearest-neighbor scaling")
            XCTAssertGreaterThan(stats.semiTransparentPixels, 80, "\(color) should keep soft antialiased edges")
            XCTAssertGreaterThan(stats.uniqueOpaqueColorBuckets, 20, "\(color) should use gradient depth, not flat pixel blocks")
            XCTAssertLessThan(stats.brightWhiteOpaqueRatio, 0.12, "\(color) should not rely on large harsh white areas")
        }
    }

    func testSpecialGemOverlaysPreserveComfortLimits() {
        let specials: [TileSpecial] = [.stripedH, .stripedV, .wrapped, .colorBomb]

        for color in GemColor.allCases {
            for special in specials {
                let texture = PixelArt.shared.gemTexture(color: color, special: special)
                let stats = TextureStats(texture: texture)

                XCTAssertEqual(texture.filteringMode, .linear)
                XCTAssertGreaterThan(stats.semiTransparentPixels, 80, "\(color) \(special) should retain soft edges")
                XCTAssertLessThan(stats.brightWhiteOpaqueRatio, 0.16, "\(color) \(special) should avoid harsh white coverage")
            }
        }
    }

    func testObstacleTexturesKeepTransparentAndSolidMaterialSeparation() {
        let jelly = TextureStats(texture: PixelArt.shared.obstacleTexture(type: .jelly1))
        let ice = TextureStats(texture: PixelArt.shared.obstacleTexture(type: .ice))
        let chocolate = TextureStats(texture: PixelArt.shared.obstacleTexture(type: .chocolate))
        let stone = TextureStats(texture: PixelArt.shared.obstacleTexture(type: .stone))

        XCTAssertLessThan(jelly.averageVisibleAlpha, 180, "Jelly should read as a translucent overlay")
        XCTAssertLessThan(ice.averageVisibleAlpha, 205, "Ice should read as a translucent material")
        XCTAssertGreaterThan(chocolate.averageVisibleAlpha, 230, "Chocolate should read as a solid blocker")
        XCTAssertGreaterThan(stone.uniqueOpaqueColorBuckets, 12, "Stone should keep material depth on small screens")
    }

    func testParticleTextureUsesSmallSoftShape() {
        let texture = PixelArt.shared.particleTexture(color: GemColor.blue.primary, size: 4.5)
        let stats = TextureStats(texture: texture)

        XCTAssertEqual(texture.filteringMode, .linear)
        XCTAssertGreaterThan(stats.semiTransparentPixels, 4)
        XCTAssertLessThan(stats.brightWhiteOpaqueRatio, 0.20)
    }

    func testButtonIconsUsePixelArtSoftMaterials() {
        for icon in PixelArtIcon.allCases {
            let texture = PixelArt.shared.softIconTexture(icon, size: 40)
            let stats = TextureStats(texture: texture)

            XCTAssertEqual(texture.filteringMode, .linear, "\(icon) should scale smoothly in buttons")
            XCTAssertGreaterThan(stats.semiTransparentPixels, 12, "\(icon) should have soft antialiased edges")
            XCTAssertGreaterThan(stats.uniqueOpaqueColorBuckets, 8, "\(icon) should use material depth, not flat pixel blocks")
            XCTAssertLessThan(stats.brightWhiteOpaqueRatio, 0.30, "\(icon) should avoid harsh white coverage")
        }
    }

    func testCommonUiBadgesUseSoftReadableMaterials() {
        let samples: [(name: String, texture: SKTexture)] = [
            ("heart filled", PixelArt.shared.heartBadgeTexture(filled: true, size: 32)),
            ("heart empty", PixelArt.shared.heartBadgeTexture(filled: false, size: 32)),
            ("star lit", PixelArt.shared.starBadgeTexture(lit: true, size: 32)),
            ("star dim", PixelArt.shared.starBadgeTexture(lit: false, size: 32)),
            ("lock", PixelArt.shared.lockBadgeTexture(size: 32))
        ]

        for sample in samples {
            let stats = TextureStats(texture: sample.texture)

            XCTAssertEqual(sample.texture.filteringMode, .linear, "\(sample.name) should scale smoothly")
            XCTAssertGreaterThan(stats.semiTransparentPixels, 20, "\(sample.name) should have soft edges and glow")
            XCTAssertGreaterThan(stats.uniqueOpaqueColorBuckets, 8, "\(sample.name) should have material depth")
            XCTAssertLessThan(stats.brightWhiteOpaqueRatio, 0.22, "\(sample.name) should not become a hard white icon")
        }
    }
}

private struct TextureStats {
    let semiTransparentPixels: Int
    let uniqueOpaqueColorBuckets: Int
    let brightWhiteOpaqueRatio: CGFloat
    let averageVisibleAlpha: CGFloat

    init(texture: SKTexture) {
        let cgImage = texture.cgImage()
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = [UInt8](repeating: 0, count: height * bytesPerRow)

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
        let context = CGContext(data: &data,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: bitmapInfo)!
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var semiTransparent = 0
        var visibleAlphaTotal = 0
        var visibleCount = 0
        var opaqueCount = 0
        var brightWhiteOpaque = 0
        var buckets = Set<Int>()

        for offset in stride(from: 0, to: data.count, by: bytesPerPixel) {
            let r = Int(data[offset])
            let g = Int(data[offset + 1])
            let b = Int(data[offset + 2])
            let a = Int(data[offset + 3])

            if a > 0 && a < 245 {
                semiTransparent += 1
            }
            if a > 0 {
                visibleAlphaTotal += a
                visibleCount += 1
            }
            if a > 220 {
                opaqueCount += 1
                let bucket = (r / 12) << 16 | (g / 12) << 8 | (b / 12)
                buckets.insert(bucket)
                if r > 238 && g > 238 && b > 238 {
                    brightWhiteOpaque += 1
                }
            }
        }

        semiTransparentPixels = semiTransparent
        uniqueOpaqueColorBuckets = buckets.count
        brightWhiteOpaqueRatio = opaqueCount == 0 ? 0 : CGFloat(brightWhiteOpaque) / CGFloat(opaqueCount)
        averageVisibleAlpha = visibleCount == 0 ? 0 : CGFloat(visibleAlphaTotal) / CGFloat(visibleCount)
    }
}
