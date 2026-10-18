import XCTest
@testable import SudokuEngine

/// Boards from sudokuwiki.org (Andrew Stuart), "Load example" links on the named strategy pages,
/// unless noted otherwise ("example N" = N-th distinct board link on the page). Each technique test replays easier steps until the board reaches the
/// state where the technique is due, so the asserted technique is the first applicable in enum order.
private enum Fixtures {
    /// Wikipedia, article "Sudoku" (lead image).
    static let wikipedia = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
    /// sudokuwiki.org/Hidden_Candidates, example 1.
    static let hiddenSingle = "000000000904607000076804100309701080008000300050308702007502610000403208000000000"
    /// sudokuwiki.org/Intersection_Removal, example 1.
    static let intersection = "010903600000080000900000507002010430000402000064070200701000005000030000005601020"
    /// sudokuwiki.org/Naked_Candidates, example 3.
    static let nakedPair = "080090030030000069902063158020804590851907046394605870563040987200000015010050020"
    /// sudokuwiki.org/Hidden_Candidates, example 2.
    static let hiddenPair = "720408030080000047401076802810739000000851000000264080209680413340000008168943275"
    /// sudokuwiki.org/Naked_Candidates, example 9.
    static let nakedTriple = "001400000000070008600000100300205000500001000000000070070000240080000000000030000"
    /// sudokuwiki.org/X_Wing_Strategy, example 1.
    static let xWing = "100000569402000008050009040000640801000010000208035000040500010900000402621000005"
    /// sudokuwiki.org/Sword_Fish_Strategy, example 1.
    static let swordfish = "500010003006003002003200000002300076000050000190007500000009400200800600900040005"
    /// sudokuwiki.org/Y_Wing_Strategy, example 1.
    static let xyWing = "034500000802060400600008000003900004050000090900005800000300008001040605000007120"
    /// Arto Inkala, "world's hardest sudoku" (2012) — needs guessing.
    static let needsGuessing = "800000000003600000070090200050007000000045700000100030001000068008500010090000400"

    static let all = [wikipedia, hiddenSingle, intersection, nakedPair, hiddenPair, nakedTriple,
                      xWing, swordfish, xyWing, needsGuessing]
}

final class GraderTests: XCTestCase {
    /// Applies steps easier than `target`, then returns the next step.
    private func firstStep(_ puzzle: String, reaching target: Technique) -> Step? {
        var board = Board(Grid(puzzle), in: .classic)
        while let step = board.nextStep() {
            if step.technique >= target { return step }
            board.apply(step)
        }
        return nil
    }

    func testNakedSingle() { XCTAssertEqual(firstStep(Fixtures.wikipedia, reaching: .nakedSingle)?.technique, .nakedSingle) }
    func testHiddenSingle() { XCTAssertEqual(firstStep(Fixtures.hiddenSingle, reaching: .hiddenSingle)?.technique, .hiddenSingle) }
    func testIntersection() { XCTAssertEqual(firstStep(Fixtures.intersection, reaching: .intersection)?.technique, .intersection) }
    func testNakedPair() { XCTAssertEqual(firstStep(Fixtures.nakedPair, reaching: .nakedPair)?.technique, .nakedPair) }
    func testHiddenPair() { XCTAssertEqual(firstStep(Fixtures.hiddenPair, reaching: .hiddenPair)?.technique, .hiddenPair) }
    func testNakedTriple() { XCTAssertEqual(firstStep(Fixtures.nakedTriple, reaching: .nakedTriple)?.technique, .nakedTriple) }
    func testXWing() { XCTAssertEqual(firstStep(Fixtures.xWing, reaching: .xWing)?.technique, .xWing) }
    func testSwordfish() { XCTAssertEqual(firstStep(Fixtures.swordfish, reaching: .swordfish)?.technique, .swordfish) }
    func testXYWing() { XCTAssertEqual(firstStep(Fixtures.xyWing, reaching: .xyWing)?.technique, .xyWing) }

    func testGradeEasyPuzzle() { XCTAssertEqual(Grader.grade(Grid(Fixtures.wikipedia), in: .classic), .easy) }
    func testGradeExpertPuzzle() { XCTAssertEqual(Grader.grade(Grid(Fixtures.xWing), in: .classic), .expert) }
    func testGradeReturnsNilWhenGuessingNeeded() { XCTAssertNil(Grader.grade(Grid(Fixtures.needsGuessing), in: .classic)) }

    func testHiddenSingleExplanation() {
        // Empty grid, all candidates open, except that row 4 allows the 7 only in column 2.
        var masks = [CandidateMask](repeating: 0x1FF, count: 81)
        for column in 0..<9 where column != 1 { masks[27 + column] &= ~(1 << 6) }
        let step = Grader.nextStep(Grid(String(repeating: ".", count: 81)), candidates: masks, in: .classic)
        XCTAssertEqual(step?.technique, .hiddenSingle)
        XCTAssertEqual(step?.placement?.cell, 28)
        XCTAssertEqual(step?.placement?.digit, 7)
        XCTAssertEqual(step?.focus, [28])
        XCTAssertEqual(step?.explanation, "In Zeile 4 passt die 7 nur noch in Spalte 2.")
    }

    func testEliminationsAreCorrect() throws {
        for puzzle in Fixtures.all {
            let grid = Grid(puzzle)
            XCTAssertEqual(Solver.countSolutions(grid, in: .classic, limit: 2), 1, puzzle)
            let solution = try XCTUnwrap(Solver.solve(grid, in: .classic))
            var board = Board(grid, in: .classic)
            while let step = board.nextStep() {
                XCTAssertFalse(step.placement == nil && step.eliminations.isEmpty, "\(step.technique) made no progress")
                if let p = step.placement {
                    XCTAssertEqual(Int(solution.cells[p.cell]), p.digit, step.explanation)
                }
                for e in step.eliminations {
                    XCTAssertNotEqual(Int(solution.cells[e.cell]), e.digit, step.explanation)
                }
                XCTAssertFalse(step.explanation.isEmpty)
                board.apply(step)
            }
        }
    }

    func testDifficultyTitles() {
        XCTAssertEqual(Difficulty.allCases.map(\.title), ["Leicht", "Mittel", "Schwer", "Experte"])
        XCTAssertEqual(Technique.hiddenSingle.difficulty, .easy)
        XCTAssertEqual(Technique.intersection.difficulty, .medium)
        XCTAssertEqual(Technique.nakedTriple.difficulty, .hard)
        XCTAssertEqual(Technique.xyWing.difficulty, .expert)
    }
}
