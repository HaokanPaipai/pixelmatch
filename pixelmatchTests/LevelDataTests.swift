import XCTest
import UIKit
@testable import pixelmatch

final class LevelDataTests: XCTestCase {

    func testLevelIdsAreContinuousThroughTwoHundredLevels() {
        let ids = LevelData.all.map { $0.id }

        XCTAssertEqual(ids.count, 200)
        XCTAssertEqual(ids, Array(1...200))
    }

    func testEachWorldHasTwentyLevels() {
        for world in GameWorlds {
            let count = LevelData.all.filter { $0.worldId == world.id }.count

            XCTAssertEqual(count, 20, "World \(world.id) should contain 20 levels")
        }
    }

    func testObstacleAndHolePositionsAreInsideBoard() {
        for level in LevelData.all {
            for hole in level.holes {
                XCTAssertTrue(isValid(hole, in: level), "Invalid hole in level \(level.id)")
            }
            for obstacle in level.obstacles {
                XCTAssertTrue(isValid(obstacle.position, in: level), "Invalid obstacle in level \(level.id)")
                XCTAssertFalse(contains(level.holes, obstacle.position), "Obstacle overlaps hole in level \(level.id)")
            }
            for portal in level.portalLinks {
                XCTAssertTrue(isValid(portal.entrance, in: level), "Invalid portal entrance in level \(level.id)")
                XCTAssertTrue(isValid(portal.exit, in: level), "Invalid portal exit in level \(level.id)")
                XCTAssertFalse(contains(level.holes, portal.entrance), "Portal entrance overlaps hole in level \(level.id)")
                XCTAssertFalse(contains(level.holes, portal.exit), "Portal exit overlaps hole in level \(level.id)")
                XCTAssertFalse(level.obstacles.contains { contains([portal.entrance, portal.exit], $0.position) },
                               "Portal overlaps obstacle in level \(level.id)")
            }
        }
    }

    func testFirstSixtyLevelsIntroducePlannedMechanics() {
        let firstSixty = LevelData.all.filter { $0.id <= 60 }

        XCTAssertTrue(firstSixty.contains { level in
            level.obstacles.contains { $0.type == .jelly2 }
        })
        XCTAssertTrue(firstSixty.contains { level in
            level.obstacles.contains { $0.type == .chocolate }
        })
        XCTAssertTrue(firstSixty.contains { $0.objectives.count >= 2 })
        XCTAssertTrue(firstSixty.filter { $0.id >= 41 && $0.id <= 60 }.allSatisfy { level in
            level.objectives.contains { objective in
                if case .eliminateChocolate = objective.kind { return true }
                return false
            }
        })
    }

    func testNineByNineBoardFitsSmallPhonePlayArea() {
        let level13 = LevelData.level(13)!
        let boardSize = boardVisualSize(for: level13)
        let sceneSize = CGSize(width: 320, height: 568)
        let layout = BoardLayoutCalculator.metrics(sceneSize: sceneSize,
                                                   safeAreaInsets: .zero,
                                                   boardSize: boardSize)

        XCTAssertLessThan(layout.scale, 1)
        XCTAssertLessThanOrEqual(boardSize.width * layout.scale, sceneSize.width - 28 + 0.001)
        XCTAssertGreaterThanOrEqual(layout.centerY - boardSize.height * layout.scale / 2,
                                    layout.playableBottom - 0.001)
        XCTAssertLessThanOrEqual(layout.centerY + boardSize.height * layout.scale / 2,
                                 layout.playableTop + 0.001)
    }

    func testAllLevelBoardsFitSmallPhonePlayArea() {
        let sidePadding: CGFloat = 14
        let verticalPadding: CGFloat = 8
        let profiles: [(name: String, size: CGSize, safeAreaInsets: UIEdgeInsets)] = [
            ("iPhone SE 1st gen", CGSize(width: 320, height: 568), .zero),
            ("iPhone SE 3rd gen", CGSize(width: 375, height: 667), .zero),
            ("iPhone 12 mini", CGSize(width: 375, height: 812), UIEdgeInsets(top: 50, left: 0, bottom: 34, right: 0))
        ]

        for level in LevelData.all {
            let boardSize = boardVisualSize(for: level)

            for profile in profiles {
                let layout = BoardLayoutCalculator.metrics(sceneSize: profile.size,
                                                           safeAreaInsets: profile.safeAreaInsets,
                                                           boardSize: boardSize,
                                                           sidePadding: sidePadding,
                                                           verticalPadding: verticalPadding)
                let renderedWidth = boardSize.width * layout.scale
                let renderedHeight = boardSize.height * layout.scale
                let availableWidth = profile.size.width
                    - profile.safeAreaInsets.left
                    - profile.safeAreaInsets.right
                    - sidePadding * 2

                XCTAssertLessThanOrEqual(renderedWidth,
                                         availableWidth + 0.001,
                                         "Level \(level.id) should fit width on \(profile.name)")
                XCTAssertGreaterThanOrEqual(layout.centerY - renderedHeight / 2,
                                            layout.playableBottom + verticalPadding - 0.001,
                                            "Level \(level.id) should stay above boosters on \(profile.name)")
                XCTAssertLessThanOrEqual(layout.centerY + renderedHeight / 2,
                                         layout.playableTop - verticalPadding + 0.001,
                                         "Level \(level.id) should stay below HUD on \(profile.name)")
            }
        }
    }

    func testChocolateObjectiveLevelsContainChocolateObstacles() {
        for level in LevelData.all {
            let hasChocolateObjective = level.objectives.contains { objective in
                if case .eliminateChocolate = objective.kind { return true }
                return false
            }
            guard hasChocolateObjective else { continue }

            XCTAssertTrue(level.obstacles.contains { $0.type == .chocolate },
                          "Level \(level.id) has chocolate objective without chocolate obstacles")
        }
    }

    func testBoardBackedObjectivesStartWithVisibleProgress() {
        for level in LevelData.all {
            let jellyCount = level.obstacles.filter { $0.type == .jelly1 || $0.type == .jelly2 }.count
            let iceCount = level.obstacles.filter { $0.type == .ice }.count
            let chocolateCount = level.obstacles.filter { $0.type == .chocolate }.count
            let chestCount = level.obstacles.filter { $0.type == .chest1 || $0.type == .chest2 }.count
            let keyCount = level.obstacles.filter { $0.type == .key }.count

            for objective in level.objectives {
                switch objective.kind {
                case .clearAllJelly:
                    XCTAssertEqual(objective.progress, jellyCount,
                                   "Level \(level.id) jelly progress should match board setup")
                case .breakIce(let count):
                    XCTAssertEqual(objective.progress, count,
                                   "Level \(level.id) ice progress should match objective target")
                    XCTAssertEqual(count, iceCount,
                                   "Level \(level.id) ice target should match board setup")
                case .eliminateChocolate:
                    XCTAssertEqual(objective.progress, chocolateCount,
                                   "Level \(level.id) chocolate progress should match board setup")
                case .openChests(let count):
                    XCTAssertEqual(objective.progress, chestCount,
                                   "Level \(level.id) chest progress should match board setup")
                    XCTAssertEqual(count, chestCount,
                                   "Level \(level.id) chest target should match board setup")
                case .collectKeys(let count):
                    XCTAssertEqual(objective.progress, 0,
                                   "Level \(level.id) key progress should start at zero")
                    XCTAssertEqual(count, keyCount,
                                   "Level \(level.id) key target should match board setup")
                default:
                    break
                }
            }
        }
    }

    func testStarThresholdsScaleWithMovesAndLevelComplexity() {
        for level in LevelData.all {
            XCTAssertGreaterThanOrEqual(level.starThresholds.one, minimumObjectiveScore(for: level),
                                        "Level \(level.id) one-star score should cover the base objective score")
            XCTAssertGreaterThan(level.starThresholds.two, level.starThresholds.one,
                                 "Level \(level.id) two-star score should exceed completion score")
            XCTAssertGreaterThan(level.starThresholds.three, level.starThresholds.two,
                                 "Level \(level.id) three-star score should exceed two-star score")
            XCTAssertGreaterThanOrEqual(level.starThresholds.two - level.starThresholds.one,
                                        level.moves * 45,
                                        "Level \(level.id) two-star gap should reflect move budget")
            XCTAssertGreaterThanOrEqual(level.starThresholds.three - level.starThresholds.two,
                                        level.moves * 55,
                                        "Level \(level.id) three-star gap should reflect mastery, not automatic completion")
        }
    }

    func testCompletedLevelAlwaysAwardsAtLeastOneStar() {
        let level = LevelData.level(1)!

        XCTAssertEqual(level.stars(for: 0), 1)
        XCTAssertEqual(level.stars(for: level.starThresholds.two), 2)
        XCTAssertEqual(level.stars(for: level.starThresholds.three), 3)
    }

    func testChocolateWorldStartsWithLesson() {
        let firstChocolateLevel = LevelData.level(41)

        XCTAssertNotNil(firstChocolateLevel?.lesson)
        XCTAssertTrue(firstChocolateLevel?.obstacles.contains { $0.type == .chocolate } == true)
    }

    func testStoneCurveStartsAtWorldFourAndContinuesThroughWorldFive() {
        let worldFour = LevelData.all.filter { $0.worldId == 4 }
        let worldFive = LevelData.all.filter { $0.worldId == 5 }

        XCTAssertTrue(worldFour.allSatisfy { level in
            level.obstacles.contains { $0.type == .stone }
        })
        XCTAssertTrue(worldFive.allSatisfy { level in
            level.obstacles.contains { $0.type == .stone }
        })
        XCTAssertNotNil(LevelData.level(61)?.lesson)
    }

    func testCageWorldStartsAtWorldSix() {
        let worldSix = LevelData.all.filter { $0.worldId == 6 }

        XCTAssertTrue(worldSix.allSatisfy { level in
            level.obstacles.contains { $0.type == .cage }
        })
        XCTAssertNotNil(LevelData.level(101)?.lesson)
    }

    func testChestWorldStartsAtWorldSeven() {
        let worldSeven = LevelData.all.filter { $0.worldId == 7 }

        XCTAssertTrue(worldSeven.allSatisfy { level in
            level.obstacles.contains { $0.type == .chest1 || $0.type == .chest2 }
        })
        XCTAssertTrue(worldSeven.allSatisfy { level in
            level.objectives.contains { objective in
                if case .openChests = objective.kind { return true }
                return false
            }
        })
        XCTAssertNotNil(LevelData.level(121)?.lesson)
    }

    func testKeyLockWorldStartsAtWorldEight() {
        let worldEight = LevelData.all.filter { $0.worldId == 8 }

        XCTAssertTrue(worldEight.allSatisfy { level in
            level.obstacles.contains { $0.type == .key }
                && level.obstacles.contains { $0.type == .lock }
        })
        XCTAssertTrue(worldEight.allSatisfy { level in
            level.objectives.contains { objective in
                if case .collectKeys = objective.kind { return true }
                return false
            }
        })
        XCTAssertNotNil(LevelData.level(141)?.lesson)
    }

    func testPortalWorldStartsAtWorldNine() {
        let worldNine = LevelData.all.filter { $0.worldId == 9 }

        XCTAssertTrue(worldNine.allSatisfy { !$0.portalLinks.isEmpty })
        XCTAssertNotNil(LevelData.level(161)?.lesson)
    }

    private func isValid(_ position: (row: Int, col: Int), in level: Level) -> Bool {
        position.row >= 0 && position.row < level.rows
            && position.col >= 0 && position.col < level.cols
    }

    private func boardVisualSize(for level: Level) -> CGSize {
        let boardSize = CGSize(width: CGFloat(level.cols) * GameConstants.tileStep - GameConstants.tileGap,
                               height: CGFloat(level.rows) * GameConstants.tileStep - GameConstants.tileGap)
        return CGSize(width: boardSize.width + BoardNode.visualPadding * 2,
                      height: boardSize.height + BoardNode.visualPadding * 2)
    }

    private func minimumObjectiveScore(for level: Level) -> Int {
        var scoreTarget = 0
        var objectivePoints = 0

        for objective in level.objectives {
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

    private func contains(_ positions: [(row: Int, col: Int)], _ position: (row: Int, col: Int)) -> Bool {
        positions.contains { $0.row == position.row && $0.col == position.col }
    }
}
