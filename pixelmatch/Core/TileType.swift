import UIKit

enum GemColor: Int, CaseIterable, Codable, Equatable {
    case red = 0, blue, green, yellow, purple, orange

    var primary: UIColor {
        switch self {
        case .red:    return UIColor(hex: "#FF3B30")
        case .blue:   return UIColor(hex: "#007AFF")
        case .green:  return UIColor(hex: "#34C759")
        case .yellow: return UIColor(hex: "#FFCC00")
        case .purple: return UIColor(hex: "#AF52DE")
        case .orange: return UIColor(hex: "#FF9500")
        }
    }

    var dark: UIColor {
        switch self {
        case .red:    return UIColor(hex: "#99110A")
        case .blue:   return UIColor(hex: "#004499")
        case .green:  return UIColor(hex: "#117733")
        case .yellow: return UIColor(hex: "#997700")
        case .purple: return UIColor(hex: "#661188")
        case .orange: return UIColor(hex: "#994400")
        }
    }

    var light: UIColor {
        switch self {
        case .red:    return UIColor(hex: "#FF9999")
        case .blue:   return UIColor(hex: "#99CCFF")
        case .green:  return UIColor(hex: "#99FFBB")
        case .yellow: return UIColor(hex: "#FFEE88")
        case .purple: return UIColor(hex: "#DDA0FF")
        case .orange: return UIColor(hex: "#FFCC88")
        }
    }

    var name: String {
        switch self {
        case .red: return "Flame"
        case .blue: return "Drop"
        case .green: return "Leaf"
        case .yellow: return "Star"
        case .purple: return "Crystal"
        case .orange: return "Sun"
        }
    }

    var emoji: String {
        switch self {
        case .red: return "🔥"
        case .blue: return "💧"
        case .green: return "🍀"
        case .yellow: return "⭐"
        case .purple: return "💎"
        case .orange: return "☀️"
        }
    }
}

enum TileSpecial: Int, Codable, Equatable {
    case none = 0
    case stripedH = 1   // 4 in a row → horizontal rocket
    case stripedV = 2   // 4 in a column → vertical rocket
    case wrapped = 3    // L/T shape → bomb (3×3)
    case colorBomb = 4  // 5 in a row → rainbow ball
}

enum ObstacleType: Int, Codable, Equatable {
    case none = 0
    case jelly1 = 1   // single jelly layer
    case jelly2 = 2   // double jelly layer
    case ice = 3      // frozen (needs adjacent match to break)
    case chocolate = 4 // grows each turn; clear with adjacent match
    case stone = 5    // immovable blocker (never removed)
    case cage = 6     // caged tile (needs key item)
}

struct GameConstants {
    static let tileSize: CGFloat = 46
    static let tileGap: CGFloat = 2
    static let tileStep: CGFloat = tileSize + tileGap

    static let scorePerTile: Int = 30
    static let scorePerSpecial: Int = 200
    static let scoreCascadeMultiplier: Double = 1.5

    static let maxLives: Int = 5
    static let lifeRefillMinutes: Int = 30

    static let startingCoins: Int = 500
    static let startingDiamonds: Int = 10
}
