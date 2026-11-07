import XCTest
@testable import SudokuEngine

final class VariantTests: XCTestCase {
    func testDiagonalExtrasAreBothMainDiagonals() {
        XCTAssertEqual(Variant.diagonal.extras, [[0, 10, 20, 30, 40, 50, 60, 70, 80], [8, 16, 24, 32, 40, 48, 56, 64, 72]])
        // The centre sees its row, column and box (20) plus the 8 + 8 diagonal cells; 4 of those already lie in its box.
        XCTAssertEqual(Variant.diagonal.peers(of: 40).count, 20 + 16 - 4)
    }

    func testWindokuWindowsSitOneCellInFromEachCorner() {
        XCTAssertEqual(Variant.windoku.extras.count, 4)
        XCTAssertEqual(Variant.windoku.extras[0], [10, 11, 12, 19, 20, 21, 28, 29, 30])
        XCTAssertEqual(Variant.windoku.extras[3], [50, 51, 52, 59, 60, 61, 68, 69, 70])
        XCTAssertEqual(Set(Variant.windoku.extras.joined()).count, 36, "windows don't overlap")
    }

    func testEveryVariantIsFoundByItsId() {
        XCTAssertEqual(Variant.all.map(\.id), ["classic", "diagonal", "windoku", "jigsaw", "killer"])
        for variant in Variant.all { XCTAssertEqual(Variant.named(variant.id), variant) }
        XCTAssertNil(Variant.named("thermo"))
    }

    func testVariantSurvivesSaving() throws {
        for variant in Variant.all {
            let data = try JSONEncoder().encode(variant)
            XCTAssertEqual(try JSONDecoder().decode(Variant.self, from: data), variant)
        }
    }

    func testGeneratedPuzzlesKeepTheExtraRules() throws {
        for variant in [Variant.diagonal, .windoku] {
            for d in Difficulty.allCases {
                var rng = SplitMix64(seed: 7)
                let p = try XCTUnwrap(Generator.make(d, variant: variant, using: &rng), "\(variant.id) \(d)")
                XCTAssertEqual(p.variant, variant)
                XCTAssertEqual(Solver.countSolutions(p.givens, in: variant, limit: 2), 1)
                XCTAssertEqual(Grader.grade(p.givens, in: variant), d)
                for group in variant.extras {
                    XCTAssertEqual(Set(group.map { p.solution.cells[$0] }), Set(1...9), "\(variant.id) \(d)")
                }
            }
        }
    }

    func testHintNamesTheDiagonal() {
        // Empty grid, all candidates open, except that the falling diagonal allows the 7 only in the centre.
        var masks = [CandidateMask](repeating: 0x1FF, count: 81)
        for cell in Variant.diagonal.extras[0] where cell != 40 { masks[cell] &= ~(1 << 6) }
        let step = Grader.nextStep(Grid(String(repeating: ".", count: 81)), candidates: masks, in: .diagonal)
        XCTAssertEqual(step?.technique, .hiddenSingle)
        XCTAssertEqual(step?.placement?.cell, 40)
        XCTAssertEqual(step?.explanation(language: "de"), "In der Diagonale von links oben passt die 7 nur noch in Zeile 5, Spalte 5.")
        XCTAssertTrue(step?.explanation(language: "en").contains("diagonal from the top left") == true)
    }

    func testHintNamesTheWindow() {
        // Empty grid, all candidates open, except that the bottom-right window allows the 3 only in its first cell.
        var masks = [CandidateMask](repeating: 0x1FF, count: 81)
        for cell in Variant.windoku.extras[3] where cell != 50 { masks[cell] &= ~(1 << 2) }
        let step = Grader.nextStep(Grid(String(repeating: ".", count: 81)), candidates: masks, in: .windoku)
        XCTAssertEqual(step?.technique, .hiddenSingle)
        XCTAssertEqual(step?.explanation(language: "de"), "Im Fenster unten rechts passt die 3 nur noch in Zeile 6, Spalte 6.")
        XCTAssertTrue(step?.explanation(language: "en").contains("bottom-right window") == true)
    }
}
