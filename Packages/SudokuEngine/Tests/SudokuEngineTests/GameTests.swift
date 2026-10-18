import XCTest
@testable import SudokuEngine

final class GameTests: XCTestCase {
    private static let givens = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    private static let solution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"

    private func makeGame() -> Game {
        Game(puzzle: Puzzle(variant: .classic, givens: Grid(Self.givens), solution: Grid(Self.solution), difficulty: .easy))
    }

    func testGivensAreReadOnly() {
        var game = makeGame()
        game.setDigit(9, at: 0)
        game.toggleNote(1, at: 0)
        game.clear(0)
        XCTAssertEqual(game.entries, Grid(Self.givens))
        XCTAssertFalse(game.canUndo)
    }

    func testSetDigitRemovesNoteFromPeers() {
        var game = makeGame()
        game.toggleNote(4, at: 3)   // same row as cell 2
        game.toggleNote(4, at: 10)  // empty cell, same box only
        game.toggleNote(4, at: 29)  // same column as cell 2
        game.toggleNote(4, at: 40)  // not a peer
        game.toggleNote(2, at: 3)
        game.setDigit(4, at: 2)
        XCTAssertEqual(game.notes[3], digitBit(2))
        XCTAssertEqual(game.notes[10], 0)
        XCTAssertEqual(game.notes[29], 0)
        XCTAssertEqual(game.notes[40], digitBit(4))
    }

    func testSetSameDigitTwiceClears() {
        var game = makeGame()
        game.setDigit(4, at: 2)
        game.setDigit(4, at: 2)
        XCTAssertEqual(game.entries.cells[2], 0)
    }

    func testCheckMarksOnlyWrongEntries() {
        var game = makeGame()
        game.setDigit(4, at: 2)  // right
        game.setDigit(1, at: 3)  // wrong (solution 6)
        let wrong = game.check()
        XCTAssertEqual(wrong, [3])
        XCTAssertEqual(game.errorMarks, [3])
        XCTAssertEqual(game.checksUsed, 1)
        XCTAssertEqual(game.errorsFound, 1)
    }

    func testUndoClearsErrorMark() {
        var game = makeGame()
        game.setDigit(1, at: 3)
        _ = game.check()
        game.undo()
        XCTAssertTrue(game.errorMarks.isEmpty)
        game.redo()
        XCTAssertTrue(game.errorMarks.isEmpty)
        XCTAssertEqual(game.entries.cells[3], 1)
    }

    func testHintReportsWrongEntryRow() {
        var game = makeGame()
        game.setDigit(1, at: 27 + 2)  // row 4, solution 5
        guard case .wrongEntry(let row)? = game.hint() else { return XCTFail("expected wrongEntry") }
        XCTAssertEqual(row, 4)
        XCTAssertEqual(game.hintsUsed, 1)
    }

    func testHintIgnoresNotes() {
        var plain = makeGame()
        var noted = makeGame()
        noted.toggleNote(9, at: 2)
        noted.toggleNote(1, at: 3)
        guard case .step(let a)? = plain.hint(), case .step(let b)? = noted.hint() else { return XCTFail("expected steps") }
        XCTAssertEqual(a.explanation, b.explanation)
        XCTAssertEqual(a.placement?.cell, b.placement?.cell)
    }

    func testHintNilWhenSolved() {
        var game = Game(puzzle: Puzzle(variant: .classic, givens: Grid(Self.solution), solution: Grid(Self.solution), difficulty: .easy))
        XCTAssertNil(game.hint())
        XCTAssertEqual(game.hintsUsed, 0)
    }

    func testRepeatedHintAdvances() throws {
        // Fill naked/hidden singles until the first step is elimination-only.
        let start = "010903600000080000900000507002010430000402000064070200701000005000030000005601020"
        let solved = try XCTUnwrap(Solver.solve(Grid(start), in: .classic))
        var grid = Grid(start)
        var step = Grader.nextStep(grid, candidates: candidates(for: grid, in: .classic), in: .classic)
        while let s = step, let p = s.placement {
            grid.cells[p.cell] = UInt8(p.digit)
            step = Grader.nextStep(grid, candidates: candidates(for: grid, in: .classic), in: .classic)
        }
        XCTAssertNotNil(step)
        XCTAssertNil(step?.placement)
        var game = Game(puzzle: Puzzle(variant: .classic, givens: grid, solution: solved, difficulty: .medium))
        guard case .step(let first)? = game.hint(), case .step(let second)? = game.hint() else { return XCTFail("expected steps") }
        XCTAssertNil(first.placement)
        XCTAssertNotEqual(first.explanation, second.explanation)
    }

    func testDecodingRejectsWrongSizes() throws {
        let game = makeGame()
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(game)) as! [String: Any]
        for key in ["notes", "hintEliminations"] {
            var bad = json
            bad[key] = [0, 0]
            let data = try JSONSerialization.data(withJSONObject: bad)
            XCTAssertThrowsError(try JSONDecoder().decode(Game.self, from: data), key)
        }
        var bad = json
        bad["entries"] = ["cells": [0, 0]]
        XCTAssertThrowsError(try JSONDecoder().decode(Game.self, from: JSONSerialization.data(withJSONObject: bad)))
    }

    func testNoOpEditKeepsErrorMark() {
        var game = makeGame()
        game.setDigit(1, at: 3)
        _ = game.check()
        game.toggleNote(5, at: 3)  // filled cell: no-op
        XCTAssertEqual(game.errorMarks, [3])
    }

    func testCodableRoundTrip() throws {
        var game = makeGame()
        game.setDigit(4, at: 2)
        game.toggleNote(1, at: 3)
        game.undo()
        let decoded = try JSONDecoder().decode(Game.self, from: JSONEncoder().encode(game))
        XCTAssertEqual(decoded.entries, game.entries)
        XCTAssertEqual(decoded.notes, game.notes)
        XCTAssertEqual(decoded.canUndo, game.canUndo)
        XCTAssertEqual(decoded.canRedo, game.canRedo)
    }
}
