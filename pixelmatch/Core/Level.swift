import Foundation
import UIKit

// MARK: - Obstacle Placement

struct BoardObstacle {
    let position: (row: Int, col: Int)
    let type: ObstacleType
}

struct PortalLink {
    let entrance: (row: Int, col: Int)
    let exit: (row: Int, col: Int)
}

// MARK: - Objectives

enum ObjectiveKind: Equatable {
    case score(target: Int)
    case collect(color: GemColor, count: Int)
    case clearAllJelly
    case breakIce(count: Int)
    case eliminateChocolate
    case openChests(count: Int)
    case collectKeys(count: Int)
}

struct LevelObjective {
    let kind: ObjectiveKind
    var progress: Int = 0

    var target: Int {
        switch kind {
        case .score(let t): return t
        case .collect(_, let c): return c
        case .clearAllJelly: return 0
        case .breakIce(let c): return c
        case .eliminateChocolate: return 0
        case .openChests(let c): return c
        case .collectKeys(let c): return c
        }
    }

    var isComplete: Bool {
        switch kind {
        case .score(let t): return progress >= t
        case .collect(_, let c): return progress >= c
        case .clearAllJelly: return progress <= 0
        case .breakIce: return progress <= 0
        case .eliminateChocolate: return progress <= 0
        case .openChests: return progress <= 0
        case .collectKeys(let c): return progress >= c
        }
    }

    var displayText: String {
        switch kind {
        case .score(let t): return "\(progress.scoreFormatted)/\(t.scoreFormatted)"
        case .collect(let color, let c): return "\(color.name): \(progress)/\(c)"
        case .clearAllJelly: return L10n.fmt("objective.progress.jelly", progress, fallback: "Jelly ×%d")
        case .breakIce(let c): return L10n.fmt("objective.progress.ice", progress, c, fallback: "Ice: %d/%d")
        case .eliminateChocolate: return L10n.fmt("objective.progress.chocolate", progress, fallback: "Choco ×%d")
        case .openChests: return L10n.fmt("objective.progress.chests", progress, fallback: "Chest ×%d")
        case .collectKeys(let c): return L10n.fmt("objective.progress.keys", progress, c, fallback: "Key: %d/%d")
        }
    }
}

// MARK: - World

struct World {
    let id: Int
    let name: String
    let themeColorHex: String
    let bgColorHex: String
    let levelRange: ClosedRange<Int>

    var themeColor: UIColor { UIColor(hex: themeColorHex) }
    var bgColor: UIColor { UIColor(hex: bgColorHex) }
    var localizedName: String { L10n.tr("world.\(id)", fallback: name) }
}

let GameWorlds: [World] = [
    World(id: 1, name: "Pixel Forest",   themeColorHex: "#34C759", bgColorHex: "#1a3a1a", levelRange: 1...20),
    World(id: 2, name: "Crystal Ocean",  themeColorHex: "#007AFF", bgColorHex: "#0a1a3a", levelRange: 21...40),
    World(id: 3, name: "Sky Kingdom",    themeColorHex: "#99CCFF", bgColorHex: "#1a2a4a", levelRange: 41...60),
    World(id: 4, name: "Lava Desert",    themeColorHex: "#FF9500", bgColorHex: "#3a1a00", levelRange: 61...80),
    World(id: 5, name: "Frozen Tundra",  themeColorHex: "#CCEEFF", bgColorHex: "#0a1a2a", levelRange: 81...100),
    World(id: 6, name: "Neon City",      themeColorHex: "#AF52DE", bgColorHex: "#1a0a2a", levelRange: 101...120),
    World(id: 7, name: "Rainbow Valley", themeColorHex: "#FFCC00", bgColorHex: "#2a2a0a", levelRange: 121...140),
    World(id: 8, name: "Deep Space",     themeColorHex: "#FF3B30", bgColorHex: "#0a0a1a", levelRange: 141...160),
    World(id: 9, name: "Pixel Peak",     themeColorHex: "#FF2D55", bgColorHex: "#2a0a1a", levelRange: 161...180),
    World(id: 10, name: "Cosmos Core",   themeColorHex: "#FFFFFF", bgColorHex: "#050510", levelRange: 181...200),
]

// MARK: - Level

struct LevelLesson {
    let title: String
    let message: String
}

struct Level {
    let id: Int
    let worldId: Int
    let rows: Int
    let cols: Int
    let moves: Int
    let availableColors: [GemColor]
    let objectives: [LevelObjective]
    let holes: [(row: Int, col: Int)]
    let obstacles: [BoardObstacle]
    let portalLinks: [PortalLink]
    let starThresholds: (one: Int, two: Int, three: Int)
    let lesson: LevelLesson?

    init(id: Int,
         worldId: Int,
         rows: Int,
         cols: Int,
         moves: Int,
         availableColors: [GemColor],
         objectives: [LevelObjective],
         holes: [(row: Int, col: Int)],
         obstacles: [BoardObstacle],
         portalLinks: [PortalLink] = [],
         starThresholds: (one: Int, two: Int, three: Int),
         lesson: LevelLesson? = nil) {
        self.id = id
        self.worldId = worldId
        self.rows = rows
        self.cols = cols
        self.moves = moves
        self.availableColors = availableColors
        self.objectives = objectives
        self.holes = holes
        self.obstacles = obstacles
        self.portalLinks = portalLinks
        self.starThresholds = starThresholds
        self.lesson = lesson
    }

    var world: World? { GameWorlds.first { $0.id == worldId } }
    var displayName: String { L10n.fmt("level.name", id, fallback: "Level %d") }

    func stars(for score: Int) -> Int {
        if score >= starThresholds.three { return 3 }
        if score >= starThresholds.two   { return 2 }
        // This is called only after the level objective is completed: completion is
        // the first star, while score and saved moves determine mastery stars.
        return 1
    }
}
