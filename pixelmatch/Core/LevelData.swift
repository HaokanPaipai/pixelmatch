import Foundation

struct LevelData {

    static let all: [Level] = buildAll()

    static func level(_ id: Int) -> Level? {
        all.first { $0.id == id }
    }

    // MARK: - Builder Helpers

    private static func lesson(_ titleKey: String, _ messageKey: String) -> LevelLesson {
        LevelLesson(title: L10n.tr(titleKey), message: L10n.tr(messageKey))
    }

    private static func score(_ id: Int, world: Int, rows: Int, cols: Int,
                               moves: Int, colors: Int, target: Int,
                               holes: [(row: Int, col: Int)] = [],
                               obstacles: [BoardObstacle] = [],
                               lesson: LevelLesson? = nil) -> Level {
        let c = Array(GemColor.allCases.prefix(colors))
        return Level(id: id, worldId: world, rows: rows, cols: cols, moves: moves,
                     availableColors: c,
                     objectives: [LevelObjective(kind: .score(target: target))],
                     holes: holes, obstacles: obstacles,
                     starThresholds: (target, target * 15 / 10, target * 2),
                     lesson: lesson)
    }

    private static func collect(_ id: Int, world: Int, rows: Int, cols: Int,
                                 moves: Int, colors: Int,
                                 collectColor: GemColor, count: Int,
                                 obstacles: [BoardObstacle] = [],
                                 lesson: LevelLesson? = nil) -> Level {
        let c = Array(GemColor.allCases.prefix(colors))
        let baseScore = count * GameConstants.scorePerTile
        return Level(id: id, worldId: world, rows: rows, cols: cols, moves: moves,
                     availableColors: c,
                     objectives: [LevelObjective(kind: .collect(color: collectColor, count: count))],
                     holes: [], obstacles: obstacles,
                     starThresholds: (baseScore, baseScore * 15 / 10, baseScore * 2),
                     lesson: lesson)
    }

    private static func jelly(_ id: Int, world: Int, rows: Int, cols: Int,
                               moves: Int, colors: Int,
                               jellyPositions: [(row: Int, col: Int)],
                               target: Int,
                               lesson: LevelLesson? = nil) -> Level {
        let c = Array(GemColor.allCases.prefix(colors))
        let obs = jellyPositions.map { BoardObstacle(position: $0, type: .jelly1) }
        return Level(id: id, worldId: world, rows: rows, cols: cols, moves: moves,
                     availableColors: c,
                     objectives: [LevelObjective(kind: .clearAllJelly, progress: jellyPositions.count)],
                     holes: [], obstacles: obs,
                     starThresholds: (target, target * 15 / 10, target * 2),
                     lesson: lesson)
    }

    private static func ice(_ id: Int, world: Int, rows: Int, cols: Int,
                             moves: Int, colors: Int,
                             icePositions: [(row: Int, col: Int)],
                             target: Int,
                             lesson: LevelLesson? = nil) -> Level {
        let c = Array(GemColor.allCases.prefix(colors))
        let obs = icePositions.map { BoardObstacle(position: $0, type: .ice) }
        return Level(id: id, worldId: world, rows: rows, cols: cols, moves: moves,
                     availableColors: c,
                     objectives: [LevelObjective(kind: .breakIce(count: icePositions.count))],
                     holes: [], obstacles: obs,
                     starThresholds: (target, target * 15 / 10, target * 2),
                     lesson: lesson)
    }

    // MARK: - All Levels

    private static func buildAll() -> [Level] {
        var levels: [Level] = []

        // ── World 1: Pixel Forest (1–20) ──────────────────────────────────────
        levels += [
            score(1,  world:1, rows:6, cols:6, moves:28, colors:4, target:1200,
                  lesson: lesson("lesson.swap.title", "lesson.swap.message")),
            score(2,  world:1, rows:6, cols:6, moves:26, colors:4, target:2200,
                  lesson: lesson("lesson.chain.title", "lesson.chain.message")),
            score(3,  world:1, rows:7, cols:7, moves:26, colors:4, target:3600,
                  lesson: lesson("lesson.striped.title", "lesson.striped.message")),
            score(4,  world:1, rows:7, cols:7, moves:25, colors:4, target:4800,
                  lesson: lesson("lesson.color_bomb.title", "lesson.color_bomb.message")),
            collect(5, world:1, rows:7, cols:7, moves:25, colors:4, collectColor:.red, count:16,
                    lesson: lesson("lesson.collect.title", "lesson.collect.message")),
            jelly(6,  world:1, rows:7, cols:7, moves:27, colors:4,
                  jellyPositions: rowJelly(row:6, cols:7), target:4200,
                  lesson: lesson("lesson.jelly.title", "lesson.jelly.message")),
            score(7,  world:1, rows:8, cols:8, moves:24, colors:5, target:6500,
                  lesson: lesson("lesson.combo.title", "lesson.combo.message")),
            collect(8, world:1, rows:8, cols:8, moves:24, colors:5, collectColor:.blue, count:22,
                    lesson: lesson("lesson.focus.title", "lesson.focus.message")),
            ice(9,   world:1, rows:8, cols:8, moves:27, colors:5,
                 icePositions: rowIce(row:0, cols:8), target:6200,
                 lesson: lesson("lesson.ice.title", "lesson.ice.message")),
            score(10, world:1, rows:8, cols:8, moves:25, colors:5, target:9000,
                  lesson: lesson("lesson.boss.title", "lesson.boss.message")),
            jelly(11, world:1, rows:8, cols:8, moves:25, colors:5,
                  jellyPositions: rowJelly(row:7, cols:8), target:6500),
            jelly(12, world:1, rows:8, cols:8, moves:23, colors:5,
                  jellyPositions: colJelly(col:4, rows:8), target:7600),
            score(13, world:1, rows:9, cols:9, moves:21, colors:5, target:12000,
                  holes: cornerHoles4(rows:9,cols:9)),
            score(14, world:1, rows:9, cols:9, moves:20, colors:5, target:13500),
            collect(15, world:1, rows:9, cols:9, moves:23, colors:5, collectColor:.green, count:26),
            collect(16, world:1, rows:9, cols:9, moves:22, colors:5, collectColor:.yellow, count:28),
            score(17, world:1, rows:9, cols:9, moves:20, colors:6, target:15500),
            jelly(18, world:1, rows:9, cols:9, moves:27, colors:5,
                  jellyPositions: centerJelly(rows:9,cols:9,size:3), target:10000),
            score(19, world:1, rows:9, cols:9, moves:18, colors:6, target:18000),
            score(20, world:1, rows:9, cols:9, moves:24, colors:6, target:22000), // world boss
        ]

        // ── World 2: Crystal Ocean (21–40) ────────────────────────────────────
        levels += [
            ice(21, world:2, rows:8, cols:8, moves:26, colors:5,
                icePositions: rowIce(row:0, cols:8), target:8000),
            ice(22, world:2, rows:8, cols:8, moves:24, colors:5,
                icePositions: rowIce(row:7, cols:8), target:9000),
            score(23, world:2, rows:9, cols:9, moves:21, colors:5, target:19000),
            collect(24, world:2, rows:9, cols:9, moves:24, colors:6, collectColor:.blue, count:34),
            jelly(25, world:2, rows:9, cols:9, moves:28, colors:5,
                  jellyPositions: diamondJelly(rows:9,cols:9), target:12000),
            score(26, world:2, rows:9, cols:9, moves:19, colors:6, target:23000,
                  holes: crossHoles(rows:9,cols:9)),
            ice(27, world:2, rows:9, cols:9, moves:29, colors:5,
                icePositions: outerIce(rows:9,cols:9), target:13000),
            collect(28, world:2, rows:9, cols:9, moves:23, colors:6, collectColor:.purple, count:36),
            score(29, world:2, rows:9, cols:9, moves:18, colors:6, target:26000),
            score(30, world:2, rows:9, cols:9, moves:24, colors:6, target:30000),
            jelly(31, world:2, rows:9, cols:9, moves:30, colors:6,
                  jellyPositions: fullBorder(rows:9,cols:9), target:10000),
            score(32, world:2, rows:9, cols:9, moves:14, colors:6, target:28000),
            ice(33, world:2, rows:9, cols:9, moves:25, colors:6,
                icePositions: diagonalIce(rows:9,cols:9), target:10000),
            collect(34, world:2, rows:9, cols:9, moves:22, colors:6, collectColor:.orange, count:40),
            score(35, world:2, rows:9, cols:9, moves:13, colors:6, target:30000),
            jelly(36, world:2, rows:9, cols:9, moves:28, colors:6,
                  jellyPositions: checkerJelly(rows:9,cols:9), target:12000),
            score(37, world:2, rows:9, cols:9, moves:14, colors:6, target:32000),
            ice(38, world:2, rows:9, cols:9, moves:26, colors:6,
                icePositions: centerCross(rows:9,cols:9), target:11000),
            score(39, world:2, rows:9, cols:9, moves:13, colors:6, target:34000),
            score(40, world:2, rows:9, cols:9, moves:25, colors:6, target:40000), // world boss
        ]

        // ── World 3: Sky Kingdom (41–60) ──────────────────────────────────────
        levels += worlds3(startId: 41)

        // ── World 4: Lava Desert (61–80) ──────────────────────────────────────
        levels += worlds4(startId: 61)

        // ── World 5: Frozen Tundra (81–100) ───────────────────────────────────
        levels += worlds5(startId: 81)

        // ── Worlds 6–10 (101–200) ─────────────────────────────────────────────
        levels += higherWorlds(startId: 101)

        return levels
    }

    // MARK: - World builders

    private static func worlds3(startId: Int) -> [Level] {
        var l: [Level] = []; var id = startId
        for i in 0..<20 {
            let diff = i + 1
            if diff % 4 == 0 {
                l.append(jelly(id, world:3, rows:9, cols:9, moves:max(12, 28-diff), colors:6,
                               jellyPositions: randomJelly(rows:9,cols:9,count:diff*2+5), target:diff*2000))
            } else if diff % 4 == 1 {
                l.append(ice(id, world:3, rows:9, cols:9, moves:max(13, 28-diff), colors:6,
                             icePositions: randomIce(rows:9,cols:9,count:diff+5), target:diff*2000))
            } else if diff % 4 == 2 {
                let cc = GemColor.allCases[diff % GemColor.allCases.count]
                l.append(collect(id, world:3, rows:9, cols:9, moves:max(14, 28-diff), colors:6,
                                 collectColor:cc, count:diff*3+10))
            } else {
                l.append(score(id, world:3, rows:9, cols:9, moves:max(13, 26-diff), colors:6,
                               target:diff*3000 + 15000))
            }
            id += 1
        }
        return l
    }

    private static func worlds4(startId: Int) -> [Level] {
        var l: [Level] = []; var id = startId
        for i in 0..<20 {
            let diff = i + 1
            let targetScore = diff * 4000 + 20000
            l.append(score(id, world:4, rows:9, cols:9, moves:max(12, 25-diff), colors:6,
                           target:targetScore,
                           holes: diff > 10 ? cornerHoles4(rows:9,cols:9) : []))
            id += 1
        }
        return l
    }

    private static func worlds5(startId: Int) -> [Level] {
        var l: [Level] = []; var id = startId
        for i in 0..<20 {
            let diff = i + 1
            let icePos = (0..<min(diff+3, 20)).map { k -> (row: Int, col: Int) in
                let r = (k * 2) % 9; let c = (k * 3 + k/9) % 9
                return (row: r, col: c)
            }
            l.append(ice(id, world:5, rows:9, cols:9, moves:max(13, 28-diff), colors:6,
                         icePositions: icePos, target:diff*3000+25000))
            id += 1
        }
        return l
    }

    private static func higherWorlds(startId: Int) -> [Level] {
        var l: [Level] = []; var id = startId
        for w in 6...10 {
            for i in 0..<20 {
                let diff = i + 1
                let baseScore = (w - 5) * 15000 + diff * 5000
                let moves = max(10, 22 - diff)
                if i % 3 == 0 {
                    let jellys = randomJelly(rows:9, cols:9, count: min(diff * 2 + 8, 30))
                    l.append(jelly(id, world:w, rows:9, cols:9, moves:moves, colors:6,
                                   jellyPositions: jellys, target: baseScore))
                } else if i % 3 == 1 {
                    let ices = randomIce(rows:9, cols:9, count: min(diff + 6, 20))
                    l.append(ice(id, world:w, rows:9, cols:9, moves:moves, colors:6,
                                 icePositions: ices, target: baseScore))
                } else {
                    let holes = i > 10 ? cornerHoles4(rows:9, cols:9) : []
                    l.append(score(id, world:w, rows:9, cols:9, moves:moves, colors:6,
                                   target: baseScore, holes: holes))
                }
                id += 1
            }
        }
        return l
    }

    // MARK: - Position Helpers

    private static func rowJelly(row: Int, cols: Int) -> [(row: Int, col: Int)] {
        (0..<cols).map { (row: row, col: $0) }
    }

    private static func colJelly(col: Int, rows: Int) -> [(row: Int, col: Int)] {
        (0..<rows).map { (row: $0, col: col) }
    }

    private static func rowIce(row: Int, cols: Int) -> [(row: Int, col: Int)] {
        (0..<cols).map { (row: row, col: $0) }
    }

    private static func cornerHoles4(rows: Int, cols: Int) -> [(row: Int, col: Int)] {
        [(0,0),(0,1),(1,0),
         (0,cols-1),(0,cols-2),(1,cols-1),
         (rows-1,0),(rows-2,0),(rows-1,1),
         (rows-1,cols-1),(rows-2,cols-1),(rows-1,cols-2)]
            .map { (row: $0.0, col: $0.1) }
    }

    private static func crossHoles(rows: Int, cols: Int) -> [(row: Int, col: Int)] {
        let mid = cols / 2
        var h: [(row: Int, col: Int)] = []
        for c in [0, cols-1] {
            h.append(contentsOf: (0..<rows).map { (row: $0, col: c) })
        }
        h.append(contentsOf: [(0, mid), (rows-1, mid)])
        return h
    }

    private static func centerJelly(rows: Int, cols: Int, size: Int) -> [(row: Int, col: Int)] {
        let rStart = rows/2 - size/2, cStart = cols/2 - size/2
        var p: [(row: Int, col: Int)] = []
        for r in rStart..<(rStart+size) {
            for c in cStart..<(cStart+size) {
                p.append((row: r, col: c))
            }
        }
        return p
    }

    private static func diamondJelly(rows: Int, cols: Int) -> [(row: Int, col: Int)] {
        let mid = rows / 2
        var p: [(row: Int, col: Int)] = []
        for r in 0..<rows {
            let dist = abs(r - mid)
            let spread = mid - dist
            for c in (mid - spread)...(mid + spread) {
                if c >= 0 && c < cols { p.append((row: r, col: c)) }
            }
        }
        return p
    }

    private static func outerIce(rows: Int, cols: Int) -> [(row: Int, col: Int)] {
        var p: [(row: Int, col: Int)] = []
        for c in 0..<cols { p.append((row: 0, col: c)); p.append((row: rows-1, col: c)) }
        for r in 1..<(rows-1) { p.append((row: r, col: 0)); p.append((row: r, col: cols-1)) }
        return p
    }

    private static func fullBorder(rows: Int, cols: Int) -> [(row: Int, col: Int)] {
        outerIce(rows: rows, cols: cols)
    }

    private static func diagonalIce(rows: Int, cols: Int) -> [(row: Int, col: Int)] {
        var p: [(row: Int, col: Int)] = []
        for i in 0..<min(rows, cols) { p.append((row: i, col: i)) }
        for i in 0..<min(rows, cols) { p.append((row: i, col: cols - 1 - i)) }
        return Array(Set(p.map { "\($0.row)_\($0.col)" })).compactMap {
            let s = $0.split(separator: "_"); return (row: Int(s[0])!, col: Int(s[1])!)
        }
    }

    private static func centerCross(rows: Int, cols: Int) -> [(row: Int, col: Int)] {
        let mr = rows/2, mc = cols/2
        var p: [(row: Int, col: Int)] = []
        for c in 0..<cols { p.append((row: mr, col: c)) }
        for r in 0..<rows { p.append((row: r, col: mc)) }
        return Array(Set(p.map { "\($0.row)_\($0.col)" })).compactMap {
            let s = $0.split(separator: "_"); return (row: Int(s[0])!, col: Int(s[1])!)
        }
    }

    private static func checkerJelly(rows: Int, cols: Int) -> [(row: Int, col: Int)] {
        var p: [(row: Int, col: Int)] = []
        for r in 0..<rows {
            for c in 0..<cols {
                if (r + c) % 2 == 0 { p.append((row: r, col: c)) }
            }
        }
        return p
    }

    private static func randomJelly(rows: Int, cols: Int, count: Int) -> [(row: Int, col: Int)] {
        let clamped = min(count, rows * cols)
        var all: [(row: Int, col: Int)] = []
        for r in 0..<rows { for c in 0..<cols { all.append((row: r, col: c)) } }
        return Array(all.shuffled().prefix(clamped))
    }

    private static func randomIce(rows: Int, cols: Int, count: Int) -> [(row: Int, col: Int)] {
        randomJelly(rows: rows, cols: cols, count: count)
    }
}
