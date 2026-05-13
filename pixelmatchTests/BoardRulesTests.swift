import XCTest
@testable import pixelmatch

final class BoardRulesTests: XCTestCase {

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
