import Foundation

// nonisolated：Core 纯逻辑层不挂 MainActor。工程默认隔离为 MainActor 时，
// 隔离类的合成 deinit 会走 deinitOnExecutor back-deploy，在非主线程（如单测）
// 释放对象时触发 malloc double-free 崩溃（实测 iOS 18.6 模拟器必现）。
nonisolated final class Tile {
    var row: Int
    var col: Int
    var gemColor: GemColor
    var special: TileSpecial
    var obstacle: ObstacleType
    var isHole: Bool

    var isMovable: Bool {
        return !isHole
            && obstacle != .stone
            && obstacle != .chocolate
            && obstacle != .cage
            && obstacle != .chest1
            && obstacle != .chest2
            && obstacle != .lock
    }

    var isMatchable: Bool {
        return !isHole
            && obstacle != .stone
            && obstacle != .ice
            && obstacle != .chocolate
            && obstacle != .chest1
            && obstacle != .chest2
            && obstacle != .lock
    }

    var isGravityBlocker: Bool {
        isHole
            || obstacle == .stone
            || obstacle == .cage
            || obstacle == .chest1
            || obstacle == .chest2
            || obstacle == .lock
    }

    init(row: Int, col: Int, color: GemColor,
         special: TileSpecial = .none,
         obstacle: ObstacleType = .none,
         isHole: Bool = false) {
        self.row = row
        self.col = col
        self.gemColor = color
        self.special = special
        self.obstacle = obstacle
        self.isHole = isHole
    }

    func copy() -> Tile {
        Tile(row: row, col: col, color: gemColor,
             special: special, obstacle: obstacle, isHole: isHole)
    }
}

extension Tile: Equatable {
    static func == (lhs: Tile, rhs: Tile) -> Bool {
        lhs === rhs
    }
}

extension Tile: CustomStringConvertible {
    var description: String {
        isHole ? "H" : "\(gemColor.name[gemColor.name.startIndex])\(special != .none ? "*" : "")"
    }
}
