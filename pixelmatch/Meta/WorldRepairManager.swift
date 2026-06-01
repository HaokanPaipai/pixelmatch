import Foundation

struct WorldRepairSnapshot {
    let world: World
    let earnedStars: Int
    let totalStars: Int
    let unlockedPieces: Int
    let totalPieces: Int

    var progress: Double {
        guard totalStars > 0 else { return 0 }
        return min(1, Double(earnedStars) / Double(totalStars))
    }

    var percent: Int {
        Int((progress * 100).rounded())
    }

    var isComplete: Bool {
        unlockedPieces >= totalPieces
    }
}

struct OverallRepairSnapshot {
    let earnedStars: Int
    let totalStars: Int
    let unlockedPieces: Int
    let totalPieces: Int

    var percent: Int {
        guard totalStars > 0 else { return 0 }
        return Int((min(1, Double(earnedStars) / Double(totalStars)) * 100).rounded())
    }
}

final class WorldRepairManager {
    static let shared = WorldRepairManager()

    private let piecesPerWorld = 5

    private init() {}

    func snapshot(for world: World) -> WorldRepairSnapshot {
        let levels = LevelData.all.filter { $0.worldId == world.id }
        let earned = levels.reduce(0) { $0 + PlayerData.shared.stars(forLevel: $1.id) }
        let total = levels.count * 3
        let progress = total > 0 ? min(1, Double(earned) / Double(total)) : 0
        let pieces = min(piecesPerWorld, Int((progress * Double(piecesPerWorld)).rounded(.down)))

        return WorldRepairSnapshot(world: world,
                                   earnedStars: earned,
                                   totalStars: total,
                                   unlockedPieces: pieces,
                                   totalPieces: piecesPerWorld)
    }

    func snapshots() -> [WorldRepairSnapshot] {
        GameWorlds.map { snapshot(for: $0) }
    }

    var overall: OverallRepairSnapshot {
        let snapshots = snapshots()
        return OverallRepairSnapshot(
            earnedStars: snapshots.reduce(0) { $0 + $1.earnedStars },
            totalStars: snapshots.reduce(0) { $0 + $1.totalStars },
            unlockedPieces: snapshots.reduce(0) { $0 + $1.unlockedPieces },
            totalPieces: snapshots.reduce(0) { $0 + $1.totalPieces }
        )
    }
}
