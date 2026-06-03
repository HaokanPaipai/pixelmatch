import XCTest
@testable import pixelmatch

final class BoardRulesTests: XCTestCase {

    func testThreeMatchCreatesNoSpecial() {
        let board = makeBoard(rows: 3, cols: 3)
        board.grid[1][0] = tile(1, 0, .red)
        board.grid[1][1] = tile(1, 1, .red)
        board.grid[1][2] = tile(1, 2, .red)

        let matches = board.detectMatches()

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].createsSpecial, .none)
        XCTAssertNil(matches[0].specialPosition)
    }

    func testFourInRowCreatesHorizontalStripedAtPreferredPosition() {
        let board = makeBoard(rows: 4, cols: 4)
        for col in 0..<4 {
            board.grid[1][col] = tile(1, col, .blue)
        }

        let matches = board.detectMatches(preferredSpecialPositions: [(1, 3)])

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].createsSpecial, .stripedH)
        XCTAssertEqual(matches[0].specialPosition?.row, 1)
        XCTAssertEqual(matches[0].specialPosition?.col, 3)
    }

    func testFourInColumnCreatesVerticalStriped() {
        let board = makeBoard(rows: 4, cols: 4)
        for row in 0..<4 {
            board.grid[row][2] = tile(row, 2, .green)
        }

        let matches = board.detectMatches()

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].createsSpecial, .stripedV)
    }

    func testStraightFiveCreatesColorBomb() {
        let board = makeBoard(rows: 5, cols: 5)
        for col in 0..<5 {
            board.grid[2][col] = tile(2, col, .yellow)
        }

        let matches = board.detectMatches()

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].createsSpecial, .colorBomb)
        XCTAssertEqual(matches[0].specialPosition?.row, 2)
        XCTAssertEqual(matches[0].specialPosition?.col, 2)
    }

    func testBentFiveCreatesWrappedAtCorner() {
        let board = makeBoard(rows: 5, cols: 5)
        for pos in [(1, 1), (1, 2), (1, 3), (2, 1), (3, 1)] {
            board.grid[pos.0][pos.1] = tile(pos.0, pos.1, .purple)
        }

        let matches = board.detectMatches()

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].positions.count, 5)
        XCTAssertEqual(matches[0].createsSpecial, .wrapped)
        XCTAssertEqual(matches[0].specialPosition?.row, 1)
        XCTAssertEqual(matches[0].specialPosition?.col, 1)
    }

    func testStraightFiveOutranksWrappedCross() {
        let board = makeBoard(rows: 5, cols: 5)
        for col in 0..<5 {
            board.grid[2][col] = tile(2, col, .orange)
        }
        board.grid[1][2] = tile(1, 2, .orange)
        board.grid[3][2] = tile(3, 2, .orange)

        let matches = board.detectMatches()

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].positions.count, 7)
        XCTAssertEqual(matches[0].createsSpecial, .colorBomb)
        XCTAssertEqual(matches[0].specialPosition?.row, 2)
        XCTAssertEqual(matches[0].specialPosition?.col, 2)
    }

    func testSeparateSimultaneousMatchesCreateMultipleSpecials() {
        let board = makeBoard(rows: 5, cols: 5)
        for col in 0..<4 {
            board.grid[0][col] = tile(0, col, .red)
        }
        for row in 1..<5 {
            board.grid[row][4] = tile(row, 4, .blue)
        }

        let matches = board.detectMatches(preferredSpecialPositions: [(0, 2), (3, 4)])

        XCTAssertEqual(matches.count, 2)
        XCTAssertTrue(matches.contains { $0.createsSpecial == .stripedH })
        XCTAssertTrue(matches.contains { $0.createsSpecial == .stripedV })
        XCTAssertTrue(matches.contains { $0.specialPosition?.row == 0 && $0.specialPosition?.col == 2 })
        XCTAssertTrue(matches.contains { $0.specialPosition?.row == 3 && $0.specialPosition?.col == 4 })
    }

    func testRemoveTilesPreservesMultipleSpecialCreations() {
        let board = makeBoard(rows: 5, cols: 5)
        for col in 0..<4 {
            board.grid[0][col] = tile(0, col, .red)
        }
        for row in 1..<5 {
            board.grid[row][4] = tile(row, 4, .blue)
        }
        let matches = board.detectMatches(preferredSpecialPositions: [(0, 2), (3, 4)])
        let positions = matches.flatMap { $0.positions }
        let creations = matches.compactMap { match -> (pos: (row: Int, col: Int), special: TileSpecial)? in
            guard let pos = match.specialPosition, match.createsSpecial != .none else { return nil }
            return (pos, match.createsSpecial)
        }

        let result = board.removeTiles(at: positions, specialCreations: creations)

        XCTAssertEqual(result.removedPositions.count, 6)
        XCTAssertEqual(board.grid[0][2]?.special, .stripedH)
        XCTAssertEqual(board.grid[3][4]?.special, .stripedV)
    }

    func testStripedTilesParticipateInColorMatches() {
        let board = makeBoard(rows: 3, cols: 3)
        board.grid[1][0] = tile(1, 0, .red)
        board.grid[1][1] = tile(1, 1, .red, special: .stripedH)
        board.grid[1][2] = tile(1, 2, .red)

        let matches = board.detectMatches()

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].positions.count, 3)
    }

    func testColorBombDoesNotParticipateInNormalColorMatches() {
        let board = makeBoard(rows: 3, cols: 3)
        board.grid[1][0] = tile(1, 0, .red)
        board.grid[1][1] = tile(1, 1, .red, special: .colorBomb)
        board.grid[1][2] = tile(1, 2, .red)

        XCTAssertTrue(board.detectMatches().isEmpty)
    }

    func testStripedStripedComboClearsOneRowAndOneColumn() {
        let board = filledBoard(rows: 5, cols: 5, color: .blue)
        board.grid[2][1]?.special = .stripedH
        board.grid[2][2]?.special = .stripedV

        let effect = board.specialComboEffect(first: .stripedH,
                                              firstColor: .blue,
                                              at: (2, 1),
                                              second: .stripedV,
                                              secondColor: .blue,
                                              at: (2, 2))

        XCTAssertEqual(Set(effectPositions(effect)), Set([
            "2_0", "2_1", "2_2", "2_3", "2_4",
            "0_2", "1_2", "3_2", "4_2"
        ]))
    }

    func testStripedWrappedComboClearsThreeRowsAndThreeColumns() {
        let board = filledBoard(rows: 7, cols: 7, color: .green)

        let effect = board.specialComboEffect(first: .stripedH,
                                              firstColor: .green,
                                              at: (3, 3),
                                              second: .wrapped,
                                              secondColor: .green,
                                              at: (3, 4))

        XCTAssertEqual(effect?.positions.count, 33)
        XCTAssertTrue(effectPositions(effect).contains("2_0"))
        XCTAssertTrue(effectPositions(effect).contains("6_4"))
    }

    func testWrappedWrappedComboClearsLargeArea() {
        let board = filledBoard(rows: 9, cols: 9, color: .yellow)

        let effect = board.specialComboEffect(first: .wrapped,
                                              firstColor: .yellow,
                                              at: (4, 4),
                                              second: .wrapped,
                                              secondColor: .yellow,
                                              at: (4, 5))

        XCTAssertEqual(effect?.positions.count, 49)
        XCTAssertTrue(effectPositions(effect).contains("1_1"))
        XCTAssertTrue(effectPositions(effect).contains("7_7"))
    }

    func testColorBombColorBombComboClearsBoardExceptStonesAndHoles() {
        let board = filledBoard(rows: 4, cols: 4, color: .purple)
        board.grid[0][0]?.isHole = true
        board.grid[1][1]?.obstacle = .stone

        let effect = board.specialComboEffect(first: .colorBomb,
                                              firstColor: .purple,
                                              at: (0, 1),
                                              second: .colorBomb,
                                              secondColor: .purple,
                                              at: (0, 2))

        XCTAssertEqual(effect?.positions.count, 14)
        XCTAssertFalse(effectPositions(effect).contains("0_0"))
        XCTAssertFalse(effectPositions(effect).contains("1_1"))
    }

    func testGravityDoesNotDropTilesIntoBottomHoles() {
        let board = makeBoard(rows: 4, cols: 1)
        board.grid[0][0] = tile(0, 0, .red)
        board.grid[1][0] = nil
        board.grid[2][0] = nil
        board.grid[3][0] = Tile(row: 3, col: 0, color: .blue, isHole: true)

        let falls = board.applyGravity()

        XCTAssertEqual(falls.count, 1)
        XCTAssertEqual(falls[0].fromRow, 0)
        XCTAssertEqual(falls[0].toRow, 2)
        XCTAssertTrue(board.grid[3][0]?.isHole == true)
        XCTAssertEqual(board.grid[2][0]?.gemColor, .red)
    }

    func testDoubleJellyDowngradesBeforeRemovingTile() {
        let board = makeBoard(rows: 3, cols: 3)
        board.grid[1][1] = tile(1, 1, .red)
        board.grid[1][1]?.obstacle = .jelly2

        let result = board.removeTiles(at: [(1, 1)])

        XCTAssertEqual(board.grid[1][1]?.obstacle, .jelly1)
        XCTAssertNotNil(board.grid[1][1])
        XCTAssertEqual(result.jellyReduced.count, 1)
        XCTAssertTrue(result.removedPositions.isEmpty)
    }

    func testSingleJellyRemovesTileAndClearsLayer() {
        let board = makeBoard(rows: 3, cols: 3)
        board.grid[1][1] = tile(1, 1, .red)
        board.grid[1][1]?.obstacle = .jelly1

        let result = board.removeTiles(at: [(1, 1)])

        XCTAssertNil(board.grid[1][1])
        XCTAssertEqual(result.jellyReduced.count, 1)
        XCTAssertEqual(result.removedPositions.count, 1)
    }

    func testRemoveResultCountsEachObstacleOnce() {
        let board = makeBoard(rows: 3, cols: 3)
        board.grid[1][1] = tile(1, 1, .red)
        board.grid[1][1]?.obstacle = .jelly2
        board.grid[1][2] = tile(1, 2, .blue)
        board.grid[1][2]?.obstacle = .ice

        let result = board.removeTiles(at: [(1, 1), (1, 1), (1, 2), (1, 2)])

        XCTAssertEqual(result.jellyReduced.count, 1)
        XCTAssertEqual(result.iceCleared.count, 1)
    }

    func testStoneCannotBeRemovedOrMovedThroughGravity() {
        let board = makeBoard(rows: 4, cols: 1)
        board.grid[0][0] = tile(0, 0, .red)
        board.grid[1][0] = tile(1, 0, .blue)
        board.grid[1][0]?.obstacle = .stone
        board.grid[2][0] = nil
        board.grid[3][0] = nil

        let result = board.removeTiles(at: [(1, 0)])
        let falls = board.applyGravity()

        XCTAssertTrue(result.removedPositions.isEmpty)
        XCTAssertEqual(board.grid[1][0]?.obstacle, .stone)
        XCTAssertTrue(falls.isEmpty)
        XCTAssertEqual(board.grid[0][0]?.gemColor, .red)
    }

    func testRemovingAdjacentTileClearsChocolate() {
        let board = makeBoard(rows: 3, cols: 3)
        board.grid[1][1] = tile(1, 1, .red)
        board.grid[1][2] = tile(1, 2, .blue)
        board.grid[1][2]?.obstacle = .chocolate

        let result = board.removeTiles(at: [(1, 1)])

        XCTAssertEqual(board.grid[1][2]?.obstacle, .none)
        XCTAssertEqual(result.chocolateCleared.count, 1)
        XCTAssertTrue(result.removedPositions.contains { $0.row == 1 && $0.col == 2 })
    }

    func testSpecialDirectHitClearsChocolate() {
        let board = makeBoard(rows: 3, cols: 3)
        board.grid[1][1] = tile(1, 1, .red)
        board.grid[1][1]?.obstacle = .chocolate

        let result = board.removeTiles(at: [(1, 1)])

        XCTAssertNil(board.grid[1][1])
        XCTAssertEqual(result.chocolateCleared.count, 1)
    }

    func testChocolateCannotMoveOrJoinNormalMatches() {
        let board = makeBoard(rows: 3, cols: 3)
        board.grid[1][0] = tile(1, 0, .red)
        board.grid[1][1] = tile(1, 1, .red)
        board.grid[1][1]?.obstacle = .chocolate
        board.grid[1][2] = tile(1, 2, .red)

        XCTAssertFalse(board.grid[1][1]?.isMovable == true)
        XCTAssertTrue(board.detectMatches().isEmpty)
    }

    func testChocolateSpreadAddsOneChocolateWhenForced() {
        let board = filledBoard(rows: 3, cols: 3, color: .green)
        board.grid[1][1]?.obstacle = .chocolate

        let newChocolate = board.spreadChocolate(force: true)

        XCTAssertEqual(newChocolate.count, 1)
        XCTAssertEqual(board.chocolateCount, 2)
    }

    func testChocolateDoesNotSpreadToSpecialsOrBlockedTiles() {
        let board = filledBoard(rows: 3, cols: 3, color: .green)
        board.grid[1][1]?.obstacle = .chocolate
        board.grid[0][1]?.special = .stripedH
        board.grid[1][0]?.obstacle = .ice
        board.grid[1][2]?.obstacle = .jelly1

        let newChocolate = board.spreadChocolate(force: true)

        XCTAssertEqual(newChocolate.count, 1)
        XCTAssertEqual(newChocolate[0].row, 2)
        XCTAssertEqual(newChocolate[0].col, 1)
    }

    func testCageBlocksSwapButCanJoinMatchToUnlock() {
        let board = makeBoard(rows: 3, cols: 3)
        board.grid[1][0] = tile(1, 0, .red)
        board.grid[1][1] = tile(1, 1, .red)
        board.grid[1][1]?.obstacle = .cage
        board.grid[1][2] = tile(1, 2, .red)

        XCTAssertFalse(board.grid[1][1]?.isMovable == true)
        XCTAssertEqual(board.detectMatches().count, 1)

        let result = board.removeTiles(at: [(1, 0), (1, 1), (1, 2)])

        XCTAssertNil(board.grid[1][0])
        XCTAssertNotNil(board.grid[1][1])
        XCTAssertNil(board.grid[1][2])
        XCTAssertEqual(board.grid[1][1]?.obstacle, .none)
        XCTAssertEqual(result.cageCleared.count, 1)
    }

    func testCageStopsGravityUntilUnlocked() {
        let board = makeBoard(rows: 4, cols: 1)
        board.grid[0][0] = tile(0, 0, .blue)
        board.grid[1][0] = tile(1, 0, .red)
        board.grid[1][0]?.obstacle = .cage
        board.grid[2][0] = nil
        board.grid[3][0] = nil

        let blockedFalls = board.applyGravity()
        XCTAssertTrue(blockedFalls.isEmpty)

        let result = board.removeTiles(at: [(1, 0)])
        let falls = board.applyGravity()

        XCTAssertEqual(result.cageCleared.count, 1)
        XCTAssertEqual(falls.count, 2)
        XCTAssertEqual(board.grid[3][0]?.gemColor, .red)
        XCTAssertEqual(board.grid[2][0]?.gemColor, .blue)
    }

    func testChestTakesTwoHitsAndOpensIntoPlayableTile() {
        let board = makeBoard(rows: 3, cols: 3)
        board.grid[1][1] = tile(1, 1, .yellow)
        board.grid[1][1]?.obstacle = .chest2

        let firstHit = board.removeTiles(at: [(1, 1)])
        let secondHit = board.removeTiles(at: [(1, 1)])

        XCTAssertEqual(firstHit.chestDamaged.count, 1)
        XCTAssertTrue(firstHit.chestOpened.isEmpty)
        XCTAssertEqual(board.grid[1][1]?.obstacle, .none)
        XCTAssertEqual(secondHit.chestDamaged.count, 1)
        XCTAssertEqual(secondHit.chestOpened.count, 1)
        XCTAssertNotNil(board.grid[1][1])
    }

    func testRemovingAdjacentTileDamagesChestOnce() {
        let board = makeBoard(rows: 3, cols: 3)
        board.grid[1][0] = tile(1, 0, .red)
        board.grid[1][1] = tile(1, 1, .yellow)
        board.grid[1][1]?.obstacle = .chest2
        board.grid[1][2] = tile(1, 2, .blue)

        let result = board.removeTiles(at: [(1, 0), (1, 2)])

        XCTAssertEqual(result.chestDamaged.count, 1)
        XCTAssertTrue(result.chestOpened.isEmpty)
        XCTAssertEqual(board.grid[1][1]?.obstacle, .chest1)
    }

    func testChestBlocksSwapMatchesAndGravityUntilOpened() {
        let board = makeBoard(rows: 4, cols: 3)
        board.grid[0][1] = tile(0, 1, .blue)
        board.grid[1][0] = tile(1, 0, .red)
        board.grid[1][1] = tile(1, 1, .red)
        board.grid[1][1]?.obstacle = .chest1
        board.grid[1][2] = tile(1, 2, .red)
        board.grid[2][1] = nil
        board.grid[3][1] = nil

        XCTAssertFalse(board.grid[1][1]?.isMovable == true)
        XCTAssertTrue(board.detectMatches().isEmpty)
        XCTAssertTrue(board.applyGravity().isEmpty)

        let result = board.removeTiles(at: [(1, 1)])
        let falls = board.applyGravity()

        XCTAssertEqual(result.chestOpened.count, 1)
        XCTAssertEqual(falls.count, 2)
        XCTAssertEqual(board.grid[3][1]?.gemColor, .red)
        XCTAssertEqual(board.grid[2][1]?.gemColor, .blue)
    }

    func testCollectingKeyOpensNearestLock() {
        let board = makeBoard(rows: 4, cols: 4)
        board.grid[1][1] = tile(1, 1, .yellow)
        board.grid[1][1]?.obstacle = .key
        board.grid[1][2] = tile(1, 2, .blue)
        board.grid[1][2]?.obstacle = .lock
        board.grid[3][3] = tile(3, 3, .blue)
        board.grid[3][3]?.obstacle = .lock

        let result = board.removeTiles(at: [(1, 1)])

        XCTAssertEqual(result.keysCollected.count, 1)
        XCTAssertEqual(result.locksOpened.count, 1)
        XCTAssertEqual(board.grid[1][2]?.obstacle, .none)
        XCTAssertEqual(board.grid[3][3]?.obstacle, .lock)
        XCTAssertNil(board.grid[1][1])
    }

    func testLockBlocksGravityAndCannotBeSpecialCleared() {
        let board = makeBoard(rows: 4, cols: 1)
        board.grid[0][0] = tile(0, 0, .green)
        board.grid[1][0] = tile(1, 0, .blue)
        board.grid[1][0]?.obstacle = .lock
        board.grid[2][0] = nil
        board.grid[3][0] = nil

        let affected = board.positionsForSpecial(.stripedV, at: (0, 0))
        let result = board.removeTiles(at: affected)
        let falls = board.applyGravity()

        XCTAssertFalse(affected.contains { $0.row == 1 && $0.col == 0 })
        XCTAssertTrue(result.locksOpened.isEmpty)
        XCTAssertEqual(board.grid[1][0]?.obstacle, .lock)
        XCTAssertTrue(falls.isEmpty)
    }

    func testPortalRedirectsFallingTileToLinkedExitColumn() {
        let board = makeBoard(rows: 5, cols: 3)
        board.portalLinks = [PortalLink(entrance: (row: 2, col: 0), exit: (row: 1, col: 2))]
        board.grid[0][0] = tile(0, 0, .purple)

        let falls = board.applyGravity()

        XCTAssertFalse(falls.isEmpty)
        XCTAssertNil(board.grid[0][0])
        XCTAssertNil(board.grid[2][0])
        XCTAssertEqual(board.grid[4][2]?.gemColor, .purple)
    }

    private func makeBoard(rows: Int, cols: Int) -> Board {
        let board = Board(rows: rows, cols: cols, availableColors: GemColor.allCases)
        board.grid = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        return board
    }

    private func filledBoard(rows: Int, cols: Int, color: GemColor) -> Board {
        let board = makeBoard(rows: rows, cols: cols)
        for row in 0..<rows {
            for col in 0..<cols {
                board.grid[row][col] = tile(row, col, color)
            }
        }
        return board
    }

    private func tile(_ row: Int,
                      _ col: Int,
                      _ color: GemColor,
                      special: TileSpecial = .none) -> Tile {
        Tile(row: row, col: col, color: color, special: special)
    }

    private func effectPositions(_ effect: SpecialComboEffect?) -> [String] {
        guard let effect = effect else { return [] }
        return effect.positions.map { "\($0.row)_\($0.col)" }
    }
}
