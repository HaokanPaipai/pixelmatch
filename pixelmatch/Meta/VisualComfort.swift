import UIKit

enum VisualComfort {
    static var isReducedMotionEnabled: Bool {
        PlayerData.shared.reduceMotionEnabled || UIAccessibility.isReduceMotionEnabled
    }

    static var particleMultiplier: CGFloat {
        isReducedMotionEnabled ? 0.55 : 1.0
    }

    static var flashAlpha: CGFloat {
        isReducedMotionEnabled ? 0.18 : 0.32
    }
}
