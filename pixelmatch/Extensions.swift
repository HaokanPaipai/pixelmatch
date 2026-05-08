import UIKit
import SpriteKit

extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        var val: UInt64 = 0
        Scanner(string: h).scanHexInt64(&val)
        let r = CGFloat((val >> 16) & 0xFF) / 255
        let g = CGFloat((val >> 8) & 0xFF) / 255
        let b = CGFloat(val & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }

    func lighter(by f: CGFloat = 0.25) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &br, alpha: &a)
        return UIColor(hue: h, saturation: max(0, s - f * 0.3), brightness: min(1, br + f), alpha: a)
    }

    func darker(by f: CGFloat = 0.25) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &br, alpha: &a)
        return UIColor(hue: h, saturation: min(1, s + f * 0.2), brightness: max(0, br - f), alpha: a)
    }

    var skColor: SKColor { self as SKColor }
}

// Note: SKColor == UIColor on iOS, so no separate SKColor extension needed.

extension SKNode {
    func shake(duration: TimeInterval = 0.4, intensity: CGFloat = 6) {
        let count = 8
        let d = duration / Double(count)
        var actions: [SKAction] = []
        for i in 0..<count {
            let amp = intensity * (1 - CGFloat(i) / CGFloat(count))
            let dx = (i % 2 == 0 ? 1 : -1) * amp
            actions.append(.moveBy(x: dx, y: 0, duration: d))
        }
        actions.append(.moveBy(x: 0, y: 0, duration: 0))
        run(.sequence(actions))
    }

    func pulse(scale: CGFloat = 1.15, duration: TimeInterval = 0.15) {
        run(.sequence([
            .scale(to: scale, duration: duration),
            .scale(to: 1.0, duration: duration)
        ]))
    }

    func popIn(from scale: CGFloat = 0.1) {
        self.setScale(scale)
        run(.sequence([
            .scale(to: 1.15, duration: 0.15),
            .scale(to: 0.95, duration: 0.08),
            .scale(to: 1.0, duration: 0.07)
        ]))
    }
}

extension CGFloat {
    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        return a + (b - a) * t
    }
}

extension Int {
    var scoreFormatted: String {
        if self >= 1_000_000 { return String(format: "%.1fM", Double(self) / 1_000_000) }
        if self >= 10_000    { return String(format: "%.1fK", Double(self) / 1_000) }
        return "\(self)"
    }
}
