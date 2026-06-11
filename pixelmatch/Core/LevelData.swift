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

    private static func colorPool(_ count: Int) -> [GemColor] {
        Array(GemColor.allCases.prefix(count))
    }

    private static func makeLevel(_ id: Int, world: Int, rows: Int, cols: Int,
                                  moves: Int, colors: Int,
                                  objectives: [LevelObjective],
                                  holes: [(row: Int, col: Int)] = [],
                                  obstacles: [BoardObstacle] = [],
                                  portalLinks: [PortalLink] = [],
                                  target: Int,
                                  lesson: LevelLesson? = nil) -> Level {
        let thresholds = starThresholds(target: target,
                                        rows: rows,
                                        cols: cols,
                                        moves: moves,
                                        colors: colors,
                                        objectives: objectives,
                                        holes: holes,
                                        obstacles: obstacles,
                                        portalLinks: portalLinks)
        return Level(id: id, worldId: world, rows: rows, cols: cols, moves: moves,
                     availableColors: colorPool(colors),
                     objectives: objectives,
                     holes: holes, obstacles: obstacles, portalLinks: portalLinks,
                     starThresholds: thresholds,
                     lesson: lesson)
    }

    private static func starThresholds(target: Int,
                                       rows: Int,
                                       cols: Int,
                                       moves: Int,
                                       colors: Int,
                                       objectives: [LevelObjective],
                                       holes: [(row: Int, col: Int)],
                                       obstacles: [BoardObstacle],
                                       portalLinks: [PortalLink]) -> (one: Int, two: Int, three: Int) {
        let boardCells = rows * cols - holes.count
        let boardPressure = max(0, boardCells - 49) * 10
        let colorPressure = max(0, colors - 4) * moves * 25
        let objectivePressure = max(0, objectives.count - 1) * GameConstants.scorePerSpecial
        let portalPressure = portalLinks.count * 240
        let obstaclePressure = obstacles.reduce(0) { $0 + obstacleScorePressure($1.type) }
        let complexity = boardPressure + colorPressure + objectivePressure + portalPressure + obstaclePressure
        let completionFloor = max(target, objectiveCompletionScoreFloor(objectives))

        let one = roundedScore(max(completionFloor, target + moves * GameConstants.scorePerTile))
        let twoFloor = completionFloor + moves * GameConstants.scorePerTile * 3 + complexity / 2
        let threeFloor = completionFloor + moves * GameConstants.scorePerTile * 5 + complexity
        let two = roundedScore(max(one + moves * 45, max(twoFloor, completionFloor * 13 / 10)))
        let three = roundedScore(max(two + moves * 55, max(threeFloor, completionFloor * 18 / 10)))

        return (one, two, three)
    }

    private static func objectiveCompletionScoreFloor(_ objectives: [LevelObjective]) -> Int {
        var scoreTarget = 0
        var objectivePoints = 0

        for objective in objectives {
            switch objective.kind {
            case .score(let target):
                scoreTarget = max(scoreTarget, target)
            case .collect(_, let count):
                objectivePoints += count * GameConstants.scorePerTile
            case .breakIce(let count):
                objectivePoints += count * GameConstants.scorePerTile
            case .clearAllJelly:
                objectivePoints += objective.progress * GameConstants.scorePerTile
            case .eliminateChocolate:
                objectivePoints += objective.progress * GameConstants.scorePerTile
            case .openChests, .collectKeys:
                break
            }
        }

        return max(scoreTarget, objectivePoints)
    }

    private static func obstacleScorePressure(_ type: ObstacleType) -> Int {
        switch type {
        case .none: return 0
        case .jelly1: return 70
        case .jelly2: return 120
        case .ice: return 130
        case .chocolate: return 180
        case .stone: return 150
        case .cage: return 180
        case .chest1: return 150
        case .chest2: return 230
        case .key: return 100
        case .lock: return 160
        }
    }

    private static func roundedScore(_ value: Int) -> Int {
        max(100, ((value + 49) / 50) * 50)
    }

    private static func score(_ id: Int, world: Int, rows: Int, cols: Int,
                               moves: Int, colors: Int, target: Int,
                               holes: [(row: Int, col: Int)] = [],
                               obstacles: [BoardObstacle] = [],
                               lesson: LevelLesson? = nil) -> Level {
        makeLevel(id, world: world, rows: rows, cols: cols, moves: moves, colors: colors,
                  objectives: [LevelObjective(kind: .score(target: target))],
                  holes: holes, obstacles: obstacles, target: target, lesson: lesson)
    }

    private static func collect(_ id: Int, world: Int, rows: Int, cols: Int,
                                 moves: Int, colors: Int,
                                 collectColor: GemColor, count: Int,
                                 obstacles: [BoardObstacle] = [],
                                 lesson: LevelLesson? = nil) -> Level {
        let baseScore = count * GameConstants.scorePerTile
        return makeLevel(id, world: world, rows: rows, cols: cols, moves: moves, colors: colors,
                         objectives: [LevelObjective(kind: .collect(color: collectColor, count: count))],
                         obstacles: obstacles, target: baseScore, lesson: lesson)
    }

    private static func jelly(_ id: Int, world: Int, rows: Int, cols: Int,
                               moves: Int, colors: Int,
                               jellyPositions: [(row: Int, col: Int)],
                               target: Int,
                               layer: ObstacleType = .jelly1,
                               lesson: LevelLesson? = nil) -> Level {
        let obs = obstacles(jellyPositions, layer)
        return makeLevel(id, world: world, rows: rows, cols: cols, moves: moves, colors: colors,
                         objectives: [LevelObjective(kind: .clearAllJelly, progress: jellyPositions.count)],
                         obstacles: obs, target: target, lesson: lesson)
    }

    private static func ice(_ id: Int, world: Int, rows: Int, cols: Int,
                             moves: Int, colors: Int,
                             icePositions: [(row: Int, col: Int)],
                             target: Int,
                             lesson: LevelLesson? = nil) -> Level {
        let obs = obstacles(icePositions, .ice)
        return makeLevel(id, world: world, rows: rows, cols: cols, moves: moves, colors: colors,
                         objectives: [LevelObjective(kind: .breakIce(count: icePositions.count),
                                                     progress: icePositions.count)],
                         obstacles: obs, target: target, lesson: lesson)
    }

    private static func chocolate(_ id: Int, world: Int, rows: Int, cols: Int,
                                  moves: Int, colors: Int,
                                  chocolatePositions: [(row: Int, col: Int)],
                                  target: Int,
                                  extraObjectives: [ObjectiveKind] = [],
                                  extraObstacles: [BoardObstacle] = [],
                                  holes: [(row: Int, col: Int)] = [],
                                  lesson: LevelLesson? = nil) -> Level {
        let obs = extraObstacles + obstacles(chocolatePositions, .chocolate)
        let objectives = [LevelObjective(kind: .eliminateChocolate,
                                         progress: chocolatePositions.count)]
            + extraObjectives.map { objective($0, obstacles: obs) }
        return makeLevel(id, world: world, rows: rows, cols: cols, moves: moves, colors: colors,
                         objectives: objectives, holes: holes, obstacles: obs,
                         target: target, lesson: lesson)
    }

    private static func mixed(_ id: Int, world: Int, rows: Int, cols: Int,
                              moves: Int, colors: Int,
                              objectives: [ObjectiveKind],
                              obstacles: [BoardObstacle],
                              target: Int,
                              holes: [(row: Int, col: Int)] = [],
                              portalLinks: [PortalLink] = [],
                              lesson: LevelLesson? = nil) -> Level {
        makeLevel(id, world: world, rows: rows, cols: cols, moves: moves, colors: colors,
                  objectives: objectives.map { objective($0, obstacles: obstacles) },
                  holes: holes, obstacles: obstacles, portalLinks: portalLinks,
                  target: target, lesson: lesson)
    }

    private static func objective(_ kind: ObjectiveKind,
                                  obstacles: [BoardObstacle]) -> LevelObjective {
        switch kind {
        case .clearAllJelly:
            let count = obstacles.filter { $0.type == .jelly1 || $0.type == .jelly2 }.count
            return LevelObjective(kind: kind, progress: count)
        case .breakIce(let count):
            return LevelObjective(kind: kind, progress: count)
        case .eliminateChocolate:
            let count = obstacles.filter { $0.type == .chocolate }.count
            return LevelObjective(kind: kind, progress: count)
        case .openChests:
            let count = obstacles.filter { $0.type == .chest1 || $0.type == .chest2 }.count
            return LevelObjective(kind: kind, progress: count)
        default:
            return LevelObjective(kind: kind)
        }
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
            mixed(10, world:1, rows:8, cols:8, moves:26, colors:5,
                  objectives: [.score(target: 9000), .clearAllJelly],
                  obstacles: obstacles(centerJelly(rows:8, cols:8, size:2), .jelly1),
                  target: 9000,
                  lesson: lesson("lesson.boss.title", "lesson.boss.message")),
            jelly(11, world:1, rows:8, cols:8, moves:25, colors:5,
                  jellyPositions: rowJelly(row:7, cols:8), target:6500),
            jelly(12, world:1, rows:8, cols:8, moves:23, colors:5,
                  jellyPositions: colJelly(col:4, rows:8), target:7600),
            mixed(13, world:1, rows:9, cols:9, moves:23, colors:5,
                  objectives: [.score(target: 12000), .collect(color: .red, count: 18)],
                  obstacles: [],
                  target: 12000,
                  holes: cornerHoles4(rows:9,cols:9)),
            mixed(14, world:1, rows:9, cols:9, moves:22, colors:5,
                  objectives: [.clearAllJelly, .collect(color: .green, count: 18)],
                  obstacles: obstacles(centerJelly(rows:9,cols:9,size:3), .jelly1),
                  target: 11000),
            collect(15, world:1, rows:9, cols:9, moves:23, colors:5, collectColor:.green, count:28),
            mixed(16, world:1, rows:9, cols:9, moves:24, colors:5,
                  objectives: [.breakIce(count: 9), .collect(color: .yellow, count: 20)],
                  obstacles: obstacles(centerJelly(rows:9, cols:9, size:3), .ice),
                  target: 13000),
            jelly(17, world:1, rows:9, cols:9, moves:24, colors:5,
                  jellyPositions: centerJelly(rows:9,cols:9,size:3), target:14000, layer: .jelly2),
            mixed(18, world:1, rows:9, cols:9, moves:26, colors:5,
                  objectives: [.clearAllJelly, .score(target: 16000)],
                  obstacles: obstacles(diamondJelly(rows:9,cols:9), .jelly1),
                  target: 16000),
            mixed(19, world:1, rows:9, cols:9, moves:22, colors:6,
                  objectives: [.score(target: 18000), .collect(color: .purple, count: 24)],
                  obstacles: [],
                  target: 18000),
            mixed(20, world:1, rows:9, cols:9, moves:27, colors:6,
                  objectives: [.clearAllJelly, .breakIce(count: 9), .score(target: 22000)],
                  obstacles: obstacles(centerJelly(rows:9, cols:9, size:3), .jelly1)
                      + obstacles(pos([(0,4),(1,4),(2,4),(4,0),(4,1),(4,2),(4,6),(4,7),(4,8)]), .ice),
                  target: 22000), // world boss
        ]

        // ── World 2: Crystal Ocean (21–40) ────────────────────────────────────
        levels += [
            ice(21, world:2, rows:8, cols:8, moves:26, colors:5,
                icePositions: rowIce(row:0, cols:8), target:8000),
            mixed(22, world:2, rows:8, cols:8, moves:25, colors:5,
                  objectives: [.breakIce(count: 8), .collect(color: .blue, count: 18)],
                  obstacles: obstacles(rowIce(row:7, cols:8), .ice),
                  target: 10000),
            score(23, world:2, rows:9, cols:9, moves:21, colors:5, target:19000),
            mixed(24, world:2, rows:9, cols:9, moves:25, colors:6,
                  objectives: [.collect(color: .blue, count: 34), .score(target: 16000)],
                  obstacles: [],
                  target: 19000),
            jelly(25, world:2, rows:9, cols:9, moves:28, colors:5,
                  jellyPositions: diamondJelly(rows:9,cols:9), target:12000),
            mixed(26, world:2, rows:9, cols:9, moves:22, colors:6,
                  objectives: [.score(target: 23000), .collect(color: .red, count: 20)],
                  obstacles: [],
                  target: 23000,
                  holes: crossHoles(rows:9,cols:9)),
            mixed(27, world:2, rows:9, cols:9, moves:30, colors:5,
                  objectives: [.breakIce(count: outerIce(rows:9,cols:9).count), .clearAllJelly],
                  obstacles: obstacles(outerIce(rows:9,cols:9), .ice)
                      + obstacles(centerJelly(rows:9, cols:9, size:3), .jelly1),
                  target: 17000),
            collect(28, world:2, rows:9, cols:9, moves:23, colors:6, collectColor:.purple, count:36),
            mixed(29, world:2, rows:9, cols:9, moves:22, colors:6,
                  objectives: [.score(target: 26000), .breakIce(count: 9)],
                  obstacles: obstacles(centerJelly(rows:9, cols:9, size:3), .ice),
                  target: 26000),
            mixed(30, world:2, rows:9, cols:9, moves:27, colors:6,
                  objectives: [.clearAllJelly, .score(target: 30000)],
                  obstacles: obstacles(diamondJelly(rows:9,cols:9), .jelly2),
                  target: 30000),
            jelly(31, world:2, rows:9, cols:9, moves:30, colors:6,
                  jellyPositions: fullBorder(rows:9,cols:9), target:16000, layer: .jelly2),
            mixed(32, world:2, rows:9, cols:9, moves:18, colors:6,
                  objectives: [.score(target: 28000), .collect(color: .orange, count: 24)],
                  obstacles: [],
                  target: 28000),
            ice(33, world:2, rows:9, cols:9, moves:25, colors:6,
                icePositions: diagonalIce(rows:9,cols:9), target:18000),
            mixed(34, world:2, rows:9, cols:9, moves:24, colors:6,
                  objectives: [.collect(color: .orange, count: 40), .clearAllJelly],
                  obstacles: obstacles(pos([(0,4),(1,3),(1,5),(2,2),(2,6),(6,2),(6,6),(7,3),(7,5),(8,4)]), .jelly1),
                  target: 26000),
            mixed(35, world:2, rows:9, cols:9, moves:20, colors:6,
                  objectives: [.score(target: 30000), .clearAllJelly],
                  obstacles: obstacles(centerCross(rows:9,cols:9), .jelly1),
                  target: 30000),
            jelly(36, world:2, rows:9, cols:9, moves:28, colors:6,
                  jellyPositions: checkerJelly(rows:9,cols:9), target:22000, layer: .jelly1),
            mixed(37, world:2, rows:9, cols:9, moves:21, colors:6,
                  objectives: [.score(target: 32000), .breakIce(count: 17)],
                  obstacles: obstacles(centerCross(rows:9,cols:9), .ice),
                  target: 32000),
            mixed(38, world:2, rows:9, cols:9, moves:27, colors:6,
                  objectives: [.breakIce(count: 17), .clearAllJelly],
                  obstacles: obstacles(centerCross(rows:9,cols:9), .ice)
                      + obstacles(fullBorder(rows:9, cols:9), .jelly1),
                  target: 26000),
            mixed(39, world:2, rows:9, cols:9, moves:20, colors:6,
                  objectives: [.score(target: 34000), .collect(color: .green, count: 32)],
                  obstacles: [],
                  target: 34000),
            mixed(40, world:2, rows:9, cols:9, moves:29, colors:6,
                  objectives: [.clearAllJelly, .breakIce(count: 17), .score(target: 40000)],
                  obstacles: obstacles(diamondJelly(rows:9,cols:9), .jelly2)
                      + obstacles(centerCross(rows:9,cols:9), .ice),
                  target: 40000), // world boss
        ]

        // ── World 3: Sky Kingdom (41–60) ──────────────────────────────────────
        levels += worlds3(startId: 41)

        // ── World 4: Lava Desert (61–80) ──────────────────────────────────────
        levels += worlds4(startId: 61)

        // ── World 5: Frozen Tundra (81–100) ───────────────────────────────────
        levels += worlds5(startId: 81)

        // ── Worlds 6–10 (101–200) ─────────────────────────────────────────────
        levels += higherWorlds(startId: 101)

        // ── Worlds 11–15 (201–300)：波浪难度 + 手工 boss + 异形棋盘 ────────────
        levels += worldsElevenToFifteen(startId: 201)

        return levels
    }

    // MARK: - Worlds 11-15（201-300）

    /// 波浪难度：5 关一周期「松-松-平-紧-峰」，避免线性变难的疲劳感。
    /// 返回 (步数修正, 目标分百分比修正)。
    private static func waveAdjust(_ i: Int) -> (moves: Int, targetPct: Int) {
        let wave: [(Int, Int)] = [(2, -10), (1, -5), (0, 0), (-1, 8), (-2, 15)]
        let w = wave[i % wave.count]
        return (moves: w.0, targetPct: w.1)
    }

    /// 异形棋盘轮换：每世界 4 关用非 9×9 布局打破单调（i ∈ {2,7,12,17}）。
    private static func altLayout(_ i: Int) -> (rows: Int, cols: Int, holes: [(row: Int, col: Int)])? {
        switch i {
        case 2:  return (rows: 7, cols: 9, holes: [])
        case 7:  return (rows: 9, cols: 7, holes: [])
        case 12: return (rows: 8, cols: 8, holes: cornerHoles4(rows: 8, cols: 8))
        case 17: return (rows: 8, cols: 8, holes: centerHoles2x2(rows: 8, cols: 8))
        default: return nil
        }
    }

    private static func centerHoles2x2(rows: Int, cols: Int) -> [(row: Int, col: Int)] {
        let r = rows / 2 - 1, c = cols / 2 - 1
        return pos([(r, c), (r, c + 1), (r + 1, c), (r + 1, c + 1)])
    }

    /// 图案模板按 9×9 设计，异形棋盘上先裁掉越界位置
    private static func clamped(_ positions: [(row: Int, col: Int)],
                                rows: Int, cols: Int) -> [(row: Int, col: Int)] {
        positions.filter { $0.row >= 0 && $0.row < rows && $0.col >= 0 && $0.col < cols }
    }

    private static func worldsElevenToFifteen(startId: Int) -> [Level] {
        var l: [Level] = []
        var id = startId
        for w in 11...15 {
            for i in 0..<20 {
                // 每世界第 10/20 关为手工调参 boss
                if (i + 1) % 10 == 0 {
                    l.append(bossLevel(id: id, world: w))
                    id += 1
                    continue
                }

                let diff = i + 1
                let wave = waveAdjust(i)
                // 延续 World 6-10 的分值公式，保证 200→201 关难度连续
                let baseScore = (w - 5) * 15000 + diff * 5000
                let target = baseScore * (100 + wave.targetPct) / 100
                let baseMoves = max(15, 26 - diff / 2) + wave.moves
                let layout = altLayout(i)
                let rows = layout?.rows ?? 9
                let cols = layout?.cols ?? 9
                let holes = layout?.holes ?? (i > 13 ? cornerHoles4(rows: 9, cols: 9) : [])

                l.append(levelForWorld(w, id: id, i: i, rows: rows, cols: cols,
                                       moves: baseMoves, target: target, holes: holes))
                id += 1
            }
        }
        return l
    }

    /// 世界主题机制：11 冰+传送门，12 笼子+钥匙锁，13 果冻+巧克力+宝箱，
    /// 14 传送门+宝箱+冰，15 终局大混合（石头+笼子+巧克力）。
    private static func levelForWorld(_ w: Int, id: Int, i: Int, rows: Int, cols: Int,
                                      moves: Int, target: Int,
                                      holes: [(row: Int, col: Int)]) -> Level {
        let diff = i + 1
        let is9x9 = rows == 9 && cols == 9
        // 传送门模板按 9×9 设计，异形棋盘不挂传送门
        let portals = (is9x9 && w == 11 && i >= 4) || (is9x9 && w == 14)
            ? portalPattern(index: i, count: i >= 10 ? 2 : 1) : []
        let blocked = portalCells(portals) + holes

        switch w {
        case 11: // Aurora Bay：冰原 + 传送门
            if i % 3 == 0 {
                let ices = excluding(clamped(growingIcePattern(index: i, count: min(diff + 8, 24)),
                                             rows: rows, cols: cols), blocked: blocked)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.breakIce(count: ices.count), .score(target: target)],
                             obstacles: obstacles(ices, .ice),
                             target: target, holes: holes, portalLinks: portals)
            } else if i % 3 == 1 {
                let jellys = excluding(clamped(diamondJelly(rows: rows, cols: cols), rows: rows, cols: cols),
                                       blocked: blocked)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.clearAllJelly, .collect(color: .blue, count: 26 + diff)],
                             obstacles: obstacles(jellys, diff >= 10 ? .jelly2 : .jelly1),
                             target: target, holes: holes, portalLinks: portals)
            } else {
                let ices = excluding(clamped(diagonalIce(rows: rows, cols: cols), rows: rows, cols: cols),
                                     blocked: blocked)
                let stones = excluding(clamped(frozenStonePattern(index: i).prefix(3).map { $0 },
                                               rows: rows, cols: cols), blocked: blocked + ices)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.breakIce(count: ices.count), .score(target: target)],
                             obstacles: obstacles(ices, .ice) + obstacles(stones, .stone),
                             target: target, holes: holes, portalLinks: portals)
            }

        case 12: // Gear Works：笼子 + 钥匙锁 + 石头
            if i % 3 == 0 {
                let cages = excluding(clamped(cagePattern(index: i, count: min(6 + diff / 2, 14)),
                                              rows: rows, cols: cols), blocked: holes)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.score(target: target), .collect(color: .yellow, count: 24 + diff)],
                             obstacles: obstacles(cages, .cage),
                             target: target, holes: holes)
            } else if i % 3 == 1, is9x9 {
                let layout = keyLockPattern(index: i, count: min(3 + diff / 4, 6))
                let keys = excluding(layout.keys, blocked: holes)
                let locks = excluding(layout.locks, blocked: keys + holes)
                let cages = excluding(clamped(cagePattern(index: i + 2, count: 5), rows: rows, cols: cols),
                                      blocked: keys + locks + holes)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.collectKeys(count: keys.count), .score(target: target)],
                             obstacles: obstacles(keys, .key) + obstacles(locks, .lock)
                                 + obstacles(cages, .cage),
                             target: target, holes: holes)
            } else {
                let stones = excluding(clamped(lavaStonePattern(index: i), rows: rows, cols: cols),
                                       blocked: holes)
                let jellys = excluding(randomJelly(rows: rows, cols: cols, count: min(diff * 2 + 6, 26)),
                                       blocked: stones + holes)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.clearAllJelly, .score(target: target)],
                             obstacles: obstacles(stones, .stone) + obstacles(jellys, .jelly1),
                             target: target, holes: holes)
            }

        case 13: // Mystic Grove：双层果冻 + 巧克力 + 宝箱
            if i % 3 == 0 {
                let chocolates = excluding(clamped(pos([(0,0),(0,cols-1),(rows-1,0),(rows-1,cols-1),
                                                        (rows/2,cols/2)]), rows: rows, cols: cols),
                                           blocked: holes)
                let jellys = excluding(clamped(centerJelly(rows: rows, cols: cols, size: 3),
                                               rows: rows, cols: cols), blocked: chocolates + holes)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.eliminateChocolate, .clearAllJelly],
                             obstacles: obstacles(chocolates, .chocolate)
                                 + obstacles(jellys, diff >= 8 ? .jelly2 : .jelly1),
                             target: target, holes: holes)
            } else if i % 3 == 1 {
                let chests = excluding(clamped(chestPattern(index: i, count: min(5 + diff / 3, 12)),
                                               rows: rows, cols: cols), blocked: holes)
                let jellys = excluding(randomJelly(rows: rows, cols: cols, count: min(diff * 2 + 4, 24)),
                                       blocked: chests + holes)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.openChests(count: chests.count), .clearAllJelly],
                             obstacles: obstacles(chests, diff >= 9 ? .chest2 : .chest1)
                                 + obstacles(jellys, .jelly1),
                             target: target, holes: holes)
            } else {
                let jellys = excluding(clamped(checkerJelly(rows: rows, cols: cols), rows: rows, cols: cols),
                                       blocked: holes)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.clearAllJelly, .score(target: target)],
                             obstacles: obstacles(jellys, diff >= 12 ? .jelly2 : .jelly1),
                             target: target, holes: holes)
            }

        case 14: // Star Harbor：传送门 + 宝箱 + 冰
            if i % 3 == 0 {
                let chests = excluding(clamped(chestPattern(index: i, count: min(5 + diff / 3, 10)),
                                               rows: rows, cols: cols), blocked: blocked)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.openChests(count: chests.count), .score(target: target)],
                             obstacles: obstacles(chests, diff >= 8 ? .chest2 : .chest1),
                             target: target, holes: holes, portalLinks: portals)
            } else if i % 3 == 1 {
                let ices = excluding(clamped(outerIce(rows: rows, cols: cols), rows: rows, cols: cols),
                                     blocked: blocked)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.breakIce(count: ices.count), .collect(color: .purple, count: 26 + diff)],
                             obstacles: obstacles(ices, .ice),
                             target: target, holes: holes, portalLinks: portals)
            } else {
                let jellys = excluding(clamped(centerCross(rows: rows, cols: cols), rows: rows, cols: cols),
                                       blocked: blocked)
                let ices = excluding(randomIce(rows: rows, cols: cols, count: min(diff + 6, 16)),
                                     blocked: jellys + blocked)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.clearAllJelly, .breakIce(count: ices.count)],
                             obstacles: obstacles(jellys, .jelly1) + obstacles(ices, .ice),
                             target: target, holes: holes, portalLinks: portals)
            }

        default: // 15 Obsidian Peak：终局大混合
            if i % 3 == 0 {
                let stones = excluding(clamped(lavaStonePattern(index: i), rows: rows, cols: cols),
                                       blocked: holes)
                let cages = excluding(clamped(cagePattern(index: i, count: min(6 + diff / 2, 12)),
                                              rows: rows, cols: cols), blocked: stones + holes)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.score(target: target), .collect(color: .red, count: 28 + diff)],
                             obstacles: obstacles(stones, .stone) + obstacles(cages, .cage),
                             target: target, holes: holes)
            } else if i % 3 == 1 {
                let chocolates = excluding(clamped(pos([(1,1),(1,cols-2),(rows-2,1),(rows-2,cols-2),
                                                        (rows/2,cols/2),(0,cols/2),(rows-1,cols/2)]),
                                                   rows: rows, cols: cols), blocked: holes)
                let jellys = excluding(clamped(diamondJelly(rows: rows, cols: cols), rows: rows, cols: cols),
                                       blocked: chocolates + holes)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.eliminateChocolate, .clearAllJelly],
                             obstacles: obstacles(chocolates, .chocolate)
                                 + obstacles(jellys, diff >= 10 ? .jelly2 : .jelly1),
                             target: target, holes: holes)
            } else {
                let chests = excluding(clamped(chestPattern(index: i, count: min(4 + diff / 3, 10)),
                                               rows: rows, cols: cols), blocked: holes)
                let ices = excluding(clamped(growingIcePattern(index: i, count: min(diff + 8, 20)),
                                             rows: rows, cols: cols), blocked: chests + holes)
                return mixed(id, world: w, rows: rows, cols: cols, moves: moves, colors: 6,
                             objectives: [.openChests(count: chests.count), .breakIce(count: ices.count)],
                             obstacles: obstacles(chests, .chest2) + obstacles(ices, .ice),
                             target: target, holes: holes)
            }
        }
    }

    /// boss 目标分：与常规关同一条公式再乘 1.25，确保严格高于相邻关且全程连续。
    private static func bossTarget(world w: Int, diff: Int) -> Int {
        ((w - 5) * 15000 + diff * 5000) * 5 / 4
    }

    /// 手工 boss 关（每世界第 10/20 关）：复合目标 + 跨机制混搭，步数紧、目标高，
    /// 是付费续命的设计卡点。数值经 starThresholds 同链路计算保持星级一致性。
    private static func bossLevel(id: Int, world: Int) -> Level {
        // 中段 boss diff=10，终局 boss diff=20
        let bossDiff = (id % 20 == 0) ? 20 : 10
        let t = bossTarget(world: world, diff: bossDiff)

        switch id {
        case 210: // W11 中段：冰封钻石阵 + 双传送门
            let portals = portalPattern(index: 9, count: 2)
            let jellys = excluding(diamondJelly(rows: 9, cols: 9), blocked: portalCells(portals))
            let ices = excluding(growingIcePattern(index: 9, count: 20),
                                 blocked: portalCells(portals) + jellys)
            return mixed(id, world: 11, rows: 9, cols: 9, moves: 24, colors: 6,
                         objectives: [.breakIce(count: ices.count), .clearAllJelly],
                         obstacles: obstacles(jellys, .jelly1) + obstacles(ices, .ice),
                         target: t, portalLinks: portals)
        case 220: // W11 终局：全边框冰 + 中心冰核 + 石头
            let ices = unique(outerIce(rows: 9, cols: 9) + centerJelly(rows: 9, cols: 9, size: 3))
                .filter { !($0.row == 4 && $0.col == 4) }
            return mixed(id, world: 11, rows: 9, cols: 9, moves: 26, colors: 6,
                         objectives: [.breakIce(count: ices.count), .score(target: t)],
                         obstacles: obstacles(ices, .ice) + obstacles(pos([(4,4)]), .stone),
                         target: t)
        case 230: // W12 中段：钥匙锁 + 笼网
            let layout = keyLockPattern(index: 2, count: 5)
            let cages = excluding(cagePattern(index: 4, count: 8), blocked: layout.keys + layout.locks)
            return mixed(id, world: 12, rows: 9, cols: 9, moves: 25, colors: 6,
                         objectives: [.collectKeys(count: layout.keys.count), .score(target: t)],
                         obstacles: obstacles(layout.keys, .key) + obstacles(layout.locks, .lock)
                             + obstacles(cages, .cage),
                         target: t)
        case 240: // W12 终局：石头十字 + 满场笼子
            let stones = pos([(4,2),(4,4),(4,6),(2,4),(6,4)])
            return mixed(id, world: 12, rows: 9, cols: 9, moves: 27, colors: 6,
                         objectives: [.score(target: t), .collect(color: .yellow, count: 46)],
                         obstacles: obstacles(stones, .stone)
                             + obstacles(excluding(cagePattern(index: 7, count: 12), blocked: stones), .cage),
                         target: t)
        case 250: // W13 中段：巧克力扩散 + 双层果冻盘
            let chocolates = pos([(0,0),(0,8),(8,0),(8,8),(4,4)])
            return mixed(id, world: 13, rows: 9, cols: 9, moves: 26, colors: 6,
                         objectives: [.eliminateChocolate, .clearAllJelly],
                         obstacles: obstacles(chocolates, .chocolate)
                             + obstacles(excluding(checkerJelly(rows: 9, cols: 9), blocked: chocolates), .jelly2),
                         target: t)
        case 260: // W13 终局：巧克力走廊 + 强化宝箱
            let chocolates = pos([(2,0),(2,8),(6,0),(6,8),(0,4),(8,4)])
            let chests = excluding(chestPattern(index: 5, count: 8), blocked: chocolates)
            return mixed(id, world: 13, rows: 9, cols: 9, moves: 28, colors: 6,
                         objectives: [.openChests(count: chests.count), .eliminateChocolate],
                         obstacles: obstacles(chocolates, .chocolate) + obstacles(chests, .chest2),
                         target: t)
        case 270: // W14 中段：双传送门 + 外环冰 + 宝箱
            let portals = portalPattern(index: 3, count: 2)
            let ices = excluding(outerIce(rows: 9, cols: 9), blocked: portalCells(portals))
            let chests = excluding(chestPattern(index: 8, count: 6),
                                   blocked: portalCells(portals) + ices)
            return mixed(id, world: 14, rows: 9, cols: 9, moves: 25, colors: 6,
                         objectives: [.openChests(count: chests.count), .breakIce(count: ices.count)],
                         obstacles: obstacles(ices, .ice) + obstacles(chests, .chest2),
                         target: t, portalLinks: portals)
        case 280: // W14 终局：角洞异形 + 全目标三连
            let holes = cornerHoles4(rows: 9, cols: 9)
            let jellys = excluding(diamondJelly(rows: 9, cols: 9), blocked: holes)
            let ices = excluding(diagonalIce(rows: 9, cols: 9), blocked: holes + jellys)
            return mixed(id, world: 14, rows: 9, cols: 9, moves: 28, colors: 6,
                         objectives: [.clearAllJelly, .breakIce(count: ices.count), .score(target: t)],
                         obstacles: obstacles(jellys, .jelly2) + obstacles(ices, .ice),
                         target: t, holes: holes)
        case 290: // W15 中段：石头堡垒 + 巧克力 + 笼子
            let stones = pos([(3,3),(3,5),(5,3),(5,5)])
            let chocolates = pos([(0,4),(4,0),(4,8),(8,4)])
            return mixed(id, world: 15, rows: 9, cols: 9, moves: 27, colors: 6,
                         objectives: [.eliminateChocolate, .score(target: t)],
                         obstacles: obstacles(stones, .stone) + obstacles(chocolates, .chocolate)
                             + obstacles(excluding(cagePattern(index: 9, count: 10),
                                                   blocked: stones + chocolates), .cage),
                         target: t)
        default: // 300 全游戏终局：五机制同台
            let stones = pos([(4,4)])
            let chocolates = pos([(0,0),(0,8),(8,0),(8,8)])
            let chests = excluding(chestPattern(index: 9, count: 6), blocked: stones + chocolates)
            let jellys = excluding(checkerJelly(rows: 9, cols: 9),
                                   blocked: stones + chocolates + chests)
            return mixed(id, world: 15, rows: 9, cols: 9, moves: 30, colors: 6,
                         objectives: [.openChests(count: chests.count), .eliminateChocolate, .score(target: t)],
                         obstacles: obstacles(stones, .stone) + obstacles(chocolates, .chocolate)
                             + obstacles(chests, .chest2) + obstacles(jellys, .jelly1),
                         target: t)
        }
    }

    // MARK: - World builders

    private static func worlds3(startId: Int) -> [Level] {
        [
            chocolate(startId, world:3, rows:8, cols:8, moves:25, colors:5,
                      chocolatePositions: pos([(3,3),(3,4)]),
                      target: 12000,
                      extraObjectives: [.score(target: 12000)],
                      lesson: lesson("lesson.chocolate.title", "lesson.chocolate.message")),
            chocolate(startId + 1, world:3, rows:8, cols:8, moves:24, colors:5,
                      chocolatePositions: pos([(2,2),(2,5),(5,2),(5,5)]),
                      target: 13000,
                      extraObjectives: [.collect(color: .red, count: 18)]),
            chocolate(startId + 2, world:3, rows:9, cols:9, moves:26, colors:5,
                      chocolatePositions: pos([(4,3),(4,4),(4,5)]),
                      target: 15000,
                      extraObjectives: [.clearAllJelly],
                      extraObstacles: obstacles(rowJelly(row:8, cols:9), .jelly1)),
            chocolate(startId + 3, world:3, rows:9, cols:9, moves:24, colors:6,
                      chocolatePositions: pos([(0,0),(0,8),(8,0),(8,8)]),
                      target: 18000,
                      extraObjectives: [.score(target: 18000)]),
            chocolate(startId + 4, world:3, rows:9, cols:9, moves:26, colors:6,
                      chocolatePositions: pos([(2,4),(4,2),(4,6),(6,4)]),
                      target: 19000,
                      extraObjectives: [.breakIce(count: 9)],
                      extraObstacles: obstacles(centerJelly(rows:9, cols:9, size:3), .ice)),
            chocolate(startId + 5, world:3, rows:9, cols:9, moves:25, colors:6,
                      chocolatePositions: pos([(1,4),(4,1),(4,7),(7,4)]),
                      target: 20000,
                      extraObjectives: [.collect(color: .blue, count: 28)]),
            chocolate(startId + 6, world:3, rows:9, cols:9, moves:27, colors:6,
                      chocolatePositions: pos([(3,3),(3,5),(5,3),(5,5)]),
                      target: 21000,
                      extraObjectives: [.clearAllJelly],
                      extraObstacles: obstacles(centerJelly(rows:9, cols:9, size:3), .jelly2)),
            chocolate(startId + 7, world:3, rows:9, cols:9, moves:23, colors:6,
                      chocolatePositions: pos([(0,4),(1,4),(7,4),(8,4)]),
                      target: 23000,
                      extraObjectives: [.score(target: 23000)],
                      holes: pos([(4,0),(4,8)])),
            chocolate(startId + 8, world:3, rows:9, cols:9, moves:25, colors:6,
                      chocolatePositions: pos([(4,0),(4,1),(4,7),(4,8)]),
                      target: 24000,
                      extraObjectives: [.collect(color: .green, count: 30), .score(target: 18000)]),
            chocolate(startId + 9, world:3, rows:9, cols:9, moves:28, colors:6,
                      chocolatePositions: pos([(2,2),(2,6),(6,2),(6,6)]),
                      target: 26000,
                      extraObjectives: [.clearAllJelly, .breakIce(count: 9)],
                      extraObstacles: obstacles(fullBorder(rows:9, cols:9), .jelly1)
                          + obstacles(centerJelly(rows:9, cols:9, size:3), .ice)),
            chocolate(startId + 10, world:3, rows:9, cols:9, moves:24, colors:6,
                      chocolatePositions: pos([(3,4),(4,3),(4,5),(5,4)]),
                      target: 27000,
                      extraObjectives: [.collect(color: .yellow, count: 34)]),
            chocolate(startId + 11, world:3, rows:9, cols:9, moves:26, colors:6,
                      chocolatePositions: pos([(0,2),(0,6),(8,2),(8,6)]),
                      target: 29000,
                      extraObjectives: [.clearAllJelly],
                      extraObstacles: obstacles(checkerJelly(rows:9, cols:9), .jelly1)),
            chocolate(startId + 12, world:3, rows:9, cols:9, moves:22, colors:6,
                      chocolatePositions: pos([(2,4),(3,4),(5,4),(6,4)]),
                      target: 30000,
                      extraObjectives: [.score(target: 30000)],
                      holes: cornerHoles4(rows:9, cols:9)),
            chocolate(startId + 13, world:3, rows:9, cols:9, moves:25, colors:6,
                      chocolatePositions: pos([(1,1),(1,7),(7,1),(7,7)]),
                      target: 31000,
                      extraObjectives: [.breakIce(count: 17)],
                      extraObstacles: obstacles(centerCross(rows:9, cols:9), .ice)),
            chocolate(startId + 14, world:3, rows:9, cols:9, moves:24, colors:6,
                      chocolatePositions: pos([(4,2),(4,3),(4,5),(4,6)]),
                      target: 32000,
                      extraObjectives: [.collect(color: .purple, count: 36)]),
            chocolate(startId + 15, world:3, rows:9, cols:9, moves:28, colors:6,
                      chocolatePositions: pos([(2,3),(2,5),(4,4),(6,3),(6,5)]),
                      target: 34000,
                      extraObjectives: [.clearAllJelly, .score(target: 26000)],
                      extraObstacles: obstacles(diamondJelly(rows:9, cols:9), .jelly2)),
            chocolate(startId + 16, world:3, rows:9, cols:9, moves:22, colors:6,
                      chocolatePositions: pos([(0,4),(4,0),(4,8),(8,4)]),
                      target: 35000,
                      extraObjectives: [.score(target: 35000)]),
            chocolate(startId + 17, world:3, rows:9, cols:9, moves:26, colors:6,
                      chocolatePositions: pos([(3,3),(3,4),(3,5),(5,3),(5,4),(5,5)]),
                      target: 36000,
                      extraObjectives: [.breakIce(count: 16), .collect(color: .orange, count: 28)],
                      extraObstacles: obstacles(pos([(0,1),(0,2),(0,6),(0,7),(1,0),(2,0),(6,0),(7,0),
                                                     (1,8),(2,8),(6,8),(7,8),(8,1),(8,2),(8,6),(8,7)]), .ice)),
            chocolate(startId + 18, world:3, rows:9, cols:9, moves:24, colors:6,
                      chocolatePositions: pos([(1,4),(2,4),(3,4),(5,4),(6,4),(7,4)]),
                      target: 38000,
                      extraObjectives: [.score(target: 38000), .collect(color: .red, count: 36)]),
            chocolate(startId + 19, world:3, rows:9, cols:9, moves:30, colors:6,
                      chocolatePositions: pos([(0,0),(0,8),(2,2),(2,6),(4,4),(6,2),(6,6),(8,0),(8,8)]),
                      target: 42000,
                      extraObjectives: [.clearAllJelly, .breakIce(count: 17), .score(target: 42000)],
                      extraObstacles: obstacles(diamondJelly(rows:9, cols:9), .jelly2)
                          + obstacles(centerCross(rows:9, cols:9), .ice))
        ]
    }

    private static func worlds4(startId: Int) -> [Level] {
        var levels: [Level] = []
        for i in 0..<20 {
            let id = startId + i
            let diff = i + 1
            let target = 26000 + diff * 2600
            let holes = diff >= 12 ? cornerHoles4(rows:9, cols:9) : []
            let stones = excluding(lavaStonePattern(index: i), blocked: holes)
            let introLesson = i == 0 ? lesson("lesson.stone.title", "lesson.stone.message") : nil

            switch i % 4 {
            case 0:
                levels.append(mixed(id, world:4, rows:9, cols:9, moves:max(16, 27 - diff / 2), colors:6,
                                    objectives: [.score(target: target), .collect(color: .orange, count: 18 + diff)],
                                    obstacles: obstacles(stones, .stone),
                                    target: target,
                                    holes: holes,
                                    lesson: introLesson))
            case 1:
                let jelly = excluding(centerCross(rows:9, cols:9), blocked: stones + holes)
                levels.append(mixed(id, world:4, rows:9, cols:9, moves:max(17, 28 - diff / 2), colors:6,
                                    objectives: [.clearAllJelly, .score(target: target)],
                                    obstacles: obstacles(stones, .stone)
                                        + obstacles(jelly, diff >= 10 ? .jelly2 : .jelly1),
                                    target: target,
                                    holes: holes,
                                    lesson: introLesson))
            case 2:
                let ice = excluding(diagonalIce(rows:9, cols:9), blocked: stones + holes)
                levels.append(mixed(id, world:4, rows:9, cols:9, moves:max(17, 29 - diff / 2), colors:6,
                                    objectives: [.breakIce(count: ice.count), .score(target: target)],
                                    obstacles: obstacles(stones, .stone) + obstacles(ice, .ice),
                                    target: target,
                                    holes: holes,
                                    lesson: introLesson))
            default:
                let jelly = excluding(diamondJelly(rows:9, cols:9), blocked: stones + holes)
                levels.append(mixed(id, world:4, rows:9, cols:9, moves:max(16, 26 - diff / 2), colors:6,
                                    objectives: [.clearAllJelly, .collect(color: .red, count: 20 + diff)],
                                    obstacles: obstacles(stones, .stone) + obstacles(jelly, .jelly1),
                                    target: target,
                                    holes: holes,
                                    lesson: introLesson))
            }
        }
        return levels
    }

    private static func worlds5(startId: Int) -> [Level] {
        var levels: [Level] = []
        for i in 0..<20 {
            let id = startId + i
            let diff = i + 1
            let target = 30000 + diff * 2800
            let holes = diff >= 13 ? pos([(0,0),(0,8),(8,0),(8,8)]) : []
            let stones = excluding(frozenStonePattern(index: i), blocked: holes)
            let ice = excluding(growingIcePattern(index: i, count: min(diff + 7, 24)), blocked: stones + holes)

            if i % 5 == 4 {
                let jelly = excluding(fullBorder(rows:9, cols:9), blocked: stones + ice + holes)
                levels.append(mixed(id, world:5, rows:9, cols:9, moves:max(18, 30 - diff / 2), colors:6,
                                    objectives: [.breakIce(count: ice.count), .clearAllJelly, .score(target: target)],
                                    obstacles: obstacles(stones, .stone)
                                        + obstacles(ice, .ice)
                                        + obstacles(jelly, diff >= 10 ? .jelly2 : .jelly1),
                                    target: target,
                                    holes: holes))
            } else if i % 2 == 0 {
                levels.append(mixed(id, world:5, rows:9, cols:9, moves:max(17, 29 - diff / 2), colors:6,
                                    objectives: [.breakIce(count: ice.count), .collect(color: .blue, count: 24 + diff)],
                                    obstacles: obstacles(stones, .stone) + obstacles(ice, .ice),
                                    target: target,
                                    holes: holes))
            } else {
                levels.append(mixed(id, world:5, rows:9, cols:9, moves:max(17, 28 - diff / 2), colors:6,
                                    objectives: [.breakIce(count: ice.count), .score(target: target)],
                                    obstacles: obstacles(stones, .stone) + obstacles(ice, .ice),
                                    target: target,
                                    holes: holes))
            }
        }
        return levels
    }

    private static func higherWorlds(startId: Int) -> [Level] {
        var l: [Level] = []; var id = startId
        for w in 6...10 {
            for i in 0..<20 {
                let diff = i + 1
                let baseScore = (w - 5) * 15000 + diff * 5000
                let moves = max(10, 22 - diff)
                if w == 6 {
                    let cages = cagePattern(index: i, count: min(5 + diff / 2, 15))
                    let cageObstacles = obstacles(cages, .cage)
                    let cageMoves = max(18, 28 - diff / 2)
                    let introLesson = i == 0 ? lesson("lesson.cage.title", "lesson.cage.message") : nil

                    if i % 3 == 0 {
                        let jellys = excluding(randomJelly(rows: 9, cols: 9, count: min(diff * 2 + 8, 30)),
                                               blocked: cages)
                        l.append(mixed(id, world: w, rows: 9, cols: 9, moves: cageMoves, colors: 6,
                                       objectives: [.clearAllJelly, .score(target: baseScore)],
                                       obstacles: cageObstacles + obstacles(jellys, .jelly1),
                                       target: baseScore,
                                       lesson: introLesson))
                    } else if i % 3 == 1 {
                        let ices = excluding(randomIce(rows: 9, cols: 9, count: min(diff + 6, 20)),
                                             blocked: cages)
                        l.append(mixed(id, world: w, rows: 9, cols: 9, moves: cageMoves, colors: 6,
                                       objectives: [.breakIce(count: ices.count), .collect(color: .purple, count: 22 + diff)],
                                       obstacles: cageObstacles + obstacles(ices, .ice),
                                       target: baseScore,
                                       lesson: introLesson))
                    } else {
                        let holes = i > 10 ? cornerHoles4(rows: 9, cols: 9) : []
                        let filteredCages = excluding(cages, blocked: holes)
                        l.append(score(id, world: w, rows: 9, cols: 9, moves: cageMoves, colors: 6,
                                       target: baseScore,
                                       holes: holes,
                                       obstacles: obstacles(filteredCages, .cage),
                                       lesson: introLesson))
                    }
                    id += 1
                    continue
                }
                if w == 7 {
                    let chests = chestPattern(index: i, count: min(4 + diff / 2, 14))
                    let reinforced = Array(chests.prefix(diff >= 8 ? min(6, chests.count / 2) : min(3, chests.count / 3)))
                    let simple = excluding(chests, blocked: reinforced)
                    let chestObstacles = obstacles(reinforced, .chest2) + obstacles(simple, .chest1)
                    let chestMoves = max(17, 29 - diff / 2)
                    let introLesson = i == 0 ? lesson("lesson.chest.title", "lesson.chest.message") : nil

                    if i % 3 == 0 {
                        let jellys = excluding(randomJelly(rows: 9, cols: 9, count: min(diff * 2 + 6, 28)),
                                               blocked: chests)
                        l.append(mixed(id, world: w, rows: 9, cols: 9, moves: chestMoves, colors: 6,
                                       objectives: [.openChests(count: chests.count), .clearAllJelly],
                                       obstacles: chestObstacles + obstacles(jellys, diff >= 10 ? .jelly2 : .jelly1),
                                       target: baseScore,
                                       lesson: introLesson))
                    } else if i % 3 == 1 {
                        let stones = i >= 10 ? lavaStonePattern(index: i).prefix(4).map { $0 } : []
                        let ices = excluding(randomIce(rows: 9, cols: 9, count: min(diff + 5, 18)),
                                             blocked: chests + stones)
                        l.append(mixed(id, world: w, rows: 9, cols: 9, moves: chestMoves, colors: 6,
                                       objectives: [.openChests(count: chests.count), .breakIce(count: ices.count)],
                                       obstacles: chestObstacles
                                           + obstacles(stones, .stone)
                                           + obstacles(ices, .ice),
                                       target: baseScore,
                                       lesson: introLesson))
                    } else {
                        let holes = i > 10 ? cornerHoles4(rows: 9, cols: 9) : []
                        let filteredChests = excluding(chests, blocked: holes)
                        let filteredReinforced = excluding(reinforced, blocked: holes)
                        let filteredSimple = excluding(filteredChests, blocked: filteredReinforced)
                        let filteredChestObstacles = obstacles(filteredReinforced, .chest2) + obstacles(filteredSimple, .chest1)
                        l.append(mixed(id, world: w, rows: 9, cols: 9, moves: chestMoves, colors: 6,
                                       objectives: [.openChests(count: filteredChests.count), .score(target: baseScore)],
                                       obstacles: filteredChestObstacles,
                                       target: baseScore,
                                       holes: holes,
                                       lesson: introLesson))
                    }
                    id += 1
                    continue
                }
                if w == 8 {
                    let keyCount = min(2 + diff / 4, 6)
                    let layout = keyLockPattern(index: i, count: keyCount)
                    let holes = i > 10 ? cornerHoles4(rows: 9, cols: 9) : []
                    let keys = excluding(layout.keys, blocked: holes)
                    let locks = excluding(layout.locks, blocked: keys + holes)
                    let blockers = keys + locks + holes
                    let keyLockObstacles = obstacles(keys, .key) + obstacles(locks, .lock)
                    let keyMoves = max(18, 30 - diff / 2)
                    let introLesson = i == 0 ? lesson("lesson.key_lock.title", "lesson.key_lock.message") : nil

                    if i % 3 == 0 {
                        l.append(mixed(id, world: w, rows: 9, cols: 9, moves: keyMoves, colors: 6,
                                       objectives: [.collectKeys(count: keys.count), .score(target: baseScore)],
                                       obstacles: keyLockObstacles,
                                       target: baseScore,
                                       holes: holes,
                                       lesson: introLesson))
                    } else if i % 3 == 1 {
                        let jellys = excluding(centerCross(rows: 9, cols: 9), blocked: blockers)
                        l.append(mixed(id, world: w, rows: 9, cols: 9, moves: keyMoves, colors: 6,
                                       objectives: [.collectKeys(count: keys.count), .clearAllJelly],
                                       obstacles: keyLockObstacles + obstacles(jellys, diff >= 12 ? .jelly2 : .jelly1),
                                       target: baseScore,
                                       holes: holes,
                                       lesson: introLesson))
                    } else {
                        let ices = excluding(growingIcePattern(index: i, count: min(diff + 7, 22)),
                                             blocked: blockers)
                        l.append(mixed(id, world: w, rows: 9, cols: 9, moves: keyMoves, colors: 6,
                                       objectives: [.collectKeys(count: keys.count), .breakIce(count: ices.count)],
                                       obstacles: keyLockObstacles + obstacles(ices, .ice),
                                       target: baseScore,
                                       holes: holes,
                                       lesson: introLesson))
                    }
                    id += 1
                    continue
                }
                if w == 9 {
                    let portals = portalPattern(index: i, count: i >= 8 ? 2 : 1)
                    let holes = diff >= 14 ? pos([(0,0),(0,8),(8,0),(8,8)]) : []
                    let blocked = portalCells(portals) + holes
                    let portalMoves = max(16, 28 - diff / 2)
                    let introLesson = i == 0 ? lesson("lesson.portal.title", "lesson.portal.message") : nil

                    if i % 3 == 0 {
                        let jellys = excluding(diamondJelly(rows: 9, cols: 9), blocked: blocked)
                        l.append(mixed(id, world: w, rows: 9, cols: 9, moves: portalMoves, colors: 6,
                                       objectives: [.clearAllJelly, .score(target: baseScore)],
                                       obstacles: obstacles(jellys, diff >= 11 ? .jelly2 : .jelly1),
                                       target: baseScore,
                                       holes: holes,
                                       portalLinks: portals,
                                       lesson: introLesson))
                    } else if i % 3 == 1 {
                        let ices = excluding(diagonalIce(rows: 9, cols: 9), blocked: blocked)
                        l.append(mixed(id, world: w, rows: 9, cols: 9, moves: portalMoves, colors: 6,
                                       objectives: [.breakIce(count: ices.count), .collect(color: .green, count: 28 + diff)],
                                       obstacles: obstacles(ices, .ice),
                                       target: baseScore,
                                       holes: holes,
                                       portalLinks: portals,
                                       lesson: introLesson))
                    } else {
                        let chests = excluding(chestPattern(index: i, count: min(5 + diff / 3, 12)),
                                               blocked: blocked)
                        l.append(mixed(id, world: w, rows: 9, cols: 9, moves: portalMoves, colors: 6,
                                       objectives: [.openChests(count: chests.count), .score(target: baseScore)],
                                       obstacles: obstacles(chests, diff >= 10 ? .chest2 : .chest1),
                                       target: baseScore,
                                       holes: holes,
                                       portalLinks: portals,
                                       lesson: introLesson))
                    }
                    id += 1
                    continue
                }
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

    private static func pos(_ raw: [(Int, Int)]) -> [(row: Int, col: Int)] {
        raw.map { (row: $0.0, col: $0.1) }
    }

    private static func obstacles(_ positions: [(row: Int, col: Int)],
                                  _ type: ObstacleType) -> [BoardObstacle] {
        unique(positions).map { BoardObstacle(position: $0, type: type) }
    }

    private static func unique(_ positions: [(row: Int, col: Int)]) -> [(row: Int, col: Int)] {
        var seen = Set<String>()
        var result: [(row: Int, col: Int)] = []
        for position in positions {
            let key = "\(position.row)_\(position.col)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(position)
        }
        return result
    }

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

    private static func lavaStonePattern(index: Int) -> [(row: Int, col: Int)] {
        var stones: [(row: Int, col: Int)]
        switch index % 5 {
        case 0:
            stones = pos([(4,3),(4,4),(4,5)])
        case 1:
            stones = pos([(2,4),(3,4),(5,4),(6,4)])
        case 2:
            stones = pos([(2,2),(2,6),(6,2),(6,6)])
        case 3:
            stones = pos([(1,4),(3,4),(4,1),(4,7),(5,4),(7,4)])
        default:
            stones = pos([(3,3),(3,5),(4,4),(5,3),(5,5)])
        }

        if index >= 6 {
            stones.append(contentsOf: pos([(4,0),(4,8)]))
        }
        if index >= 12 {
            stones.append(contentsOf: pos([(0,4),(8,4)]))
        }
        if index == 19 {
            stones.append(contentsOf: pos([(3,4),(4,3),(4,5),(5,4)]))
        }
        return unique(stones)
    }

    private static func frozenStonePattern(index: Int) -> [(row: Int, col: Int)] {
        var stones: [(row: Int, col: Int)]
        switch index % 4 {
        case 0:
            stones = pos([(3,3),(3,5),(5,3),(5,5)])
        case 1:
            stones = pos([(1,4),(4,1),(4,7),(7,4)])
        case 2:
            stones = pos([(2,3),(2,5),(6,3),(6,5)])
        default:
            stones = pos([(1,1),(1,7),(4,4),(7,1),(7,7)])
        }

        if index >= 8 {
            stones.append(contentsOf: pos([(0,4),(8,4)]))
        }
        if index >= 14 {
            stones.append(contentsOf: pos([(4,0),(4,8)]))
        }
        return unique(stones)
    }

    private static func cagePattern(index: Int, count: Int) -> [(row: Int, col: Int)] {
        var cages: [(row: Int, col: Int)]
        switch index % 5 {
        case 0:
            cages = pos([(3,3),(3,4),(3,5),(5,3),(5,4),(5,5)])
        case 1:
            cages = pos([(2,2),(2,6),(4,4),(6,2),(6,6)])
        case 2:
            cages = pos([(1,4),(2,4),(4,2),(4,6),(6,4),(7,4)])
        case 3:
            cages = pos([(1,1),(1,7),(3,3),(3,5),(5,3),(5,5),(7,1),(7,7)])
        default:
            cages = pos([(0,4),(2,2),(2,6),(4,0),(4,8),(6,2),(6,6),(8,4)])
        }

        var k = 0
        while cages.count < count && k < 81 {
            cages.append((row: (k * 2 + index) % 9,
                          col: (k * 5 + index + 2) % 9))
            k += 1
        }
        return Array(unique(cages).prefix(count))
    }

    private static func chestPattern(index: Int, count: Int) -> [(row: Int, col: Int)] {
        var chests: [(row: Int, col: Int)]
        switch index % 5 {
        case 0:
            chests = pos([(3,3),(3,5),(4,4),(5,3),(5,5)])
        case 1:
            chests = pos([(2,4),(3,3),(3,5),(5,3),(5,5),(6,4)])
        case 2:
            chests = pos([(1,1),(1,7),(4,3),(4,5),(7,1),(7,7)])
        case 3:
            chests = pos([(2,2),(2,6),(4,1),(4,4),(4,7),(6,2),(6,6)])
        default:
            chests = pos([(0,4),(2,2),(2,6),(4,0),(4,8),(6,2),(6,6),(8,4)])
        }

        var k = 0
        while chests.count < count && k < 81 {
            chests.append((row: (k * 3 + index + 1) % 9,
                           col: (k * 4 + index * 2 + 3) % 9))
            k += 1
        }
        return Array(unique(chests).prefix(count))
    }

    private static func keyLockPattern(index: Int, count: Int) -> (keys: [(row: Int, col: Int)], locks: [(row: Int, col: Int)]) {
        let keyTemplates: [[(Int, Int)]] = [
            [(1,1),(1,7),(7,1),(7,7),(4,2),(4,6)],
            [(0,4),(2,2),(2,6),(6,2),(6,6),(8,4)],
            [(1,4),(3,1),(3,7),(5,1),(5,7),(7,4)],
            [(2,1),(2,7),(4,4),(6,1),(6,7),(0,4)],
            [(1,2),(1,6),(4,1),(4,7),(7,2),(7,6)]
        ]
        let lockTemplates: [[(Int, Int)]] = [
            [(4,3),(4,4),(4,5),(3,4),(5,4),(2,4)],
            [(3,3),(3,4),(3,5),(5,3),(5,4),(5,5)],
            [(2,4),(3,4),(4,4),(5,4),(6,4),(4,2)],
            [(4,2),(4,3),(4,4),(4,5),(4,6),(2,4)],
            [(3,2),(3,6),(4,3),(4,5),(5,2),(5,6)]
        ]
        let keys = Array(unique(pos(keyTemplates[index % keyTemplates.count])).prefix(count))
        let locks = Array(unique(pos(lockTemplates[index % lockTemplates.count])).prefix(count))
        return (keys, locks)
    }

    private static func portalPattern(index: Int, count: Int) -> [PortalLink] {
        let templates: [[PortalLink]] = [
            [PortalLink(entrance: (row: 5, col: 1), exit: (row: 1, col: 7)),
             PortalLink(entrance: (row: 5, col: 7), exit: (row: 1, col: 1))],
            [PortalLink(entrance: (row: 6, col: 2), exit: (row: 2, col: 6)),
             PortalLink(entrance: (row: 6, col: 6), exit: (row: 2, col: 2))],
            [PortalLink(entrance: (row: 4, col: 0), exit: (row: 1, col: 8)),
             PortalLink(entrance: (row: 4, col: 8), exit: (row: 1, col: 0))],
            [PortalLink(entrance: (row: 5, col: 3), exit: (row: 2, col: 7)),
             PortalLink(entrance: (row: 5, col: 5), exit: (row: 2, col: 1))],
            [PortalLink(entrance: (row: 6, col: 4), exit: (row: 1, col: 2)),
             PortalLink(entrance: (row: 4, col: 7), exit: (row: 2, col: 4))]
        ]
        return Array(templates[index % templates.count].prefix(count))
    }

    private static func portalCells(_ links: [PortalLink]) -> [(row: Int, col: Int)] {
        unique(links.flatMap { [$0.entrance, $0.exit] })
    }

    private static func growingIcePattern(index: Int, count: Int) -> [(row: Int, col: Int)] {
        var positions: [(row: Int, col: Int)] = []
        var k = 0
        while positions.count < count && k < 81 {
            let row = (k * 2 + index) % 9
            let col = (k * 3 + index * 2 + k / 9) % 9
            positions.append((row: row, col: col))
            k += 1
        }
        return unique(positions)
    }

    private static func excluding(_ positions: [(row: Int, col: Int)],
                                  blocked: [(row: Int, col: Int)]) -> [(row: Int, col: Int)] {
        let blockedKeys = Set(blocked.map { "\($0.row)_\($0.col)" })
        return positions.filter { !blockedKeys.contains("\($0.row)_\($0.col)") }
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
