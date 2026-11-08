import XCTest
@testable import SudokuEngine

final class ThermoTests: XCTestCase {
    /// sudoku from the Wikipedia article, solved.
    private let solution = Grid("534678912672195348198342567859761423426853791713924856961537284287419635345286179")

    func testGeneratedPuzzlesFollowTheThermometers() throws {
        XCTAssertEqual(Variant.thermo.difficulties, [.easy, .medium, .hard])
        var expertRNG = SplitMix64(seed: 5)
        XCTAssertNil(Generator.make(.expert, variant: .thermo, using: &expertRNG))
        for d in Variant.thermo.difficulties {
            var rng = SplitMix64(seed: 5)
            let p = try XCTUnwrap(Generator.make(d, variant: .thermo, using: &rng), "\(d)")
            XCTAssertEqual(p.variant.offered, .thermo)
            XCTAssertFalse(p.variant.thermos.isEmpty)
            XCTAssertEqual(Set(p.variant.thermos.joined()).count, p.variant.thermos.joined().count, "thermometers don't overlap")
            for thermo in p.variant.thermos {
                XCTAssertTrue(Variant.isThermometer(thermo), "\(thermo)")
                let digits = thermo.map { p.solution.cells[$0] }
                XCTAssertEqual(digits, digits.sorted(), "digits rise from the bulb")
                XCTAssertEqual(Set(digits).count, digits.count)
            }
            XCTAssertEqual(Grader.grade(p.givens, in: p.variant), d)
            XCTAssertEqual(Solver.countSolutions(p.givens, in: p.variant, limit: 2), 1)
            XCTAssertEqual(Solver.solve(p.givens, in: p.variant), p.solution)
        }
    }

    func testSolverKeepsToTheThermometers() {
        // Row 1 reads 5 3 4 6 7 8 9 1 2: the 3, 4, 6, 7, 8, 9 rise, so a thermometer over them holds.
        let rising = Variant.thermo.with(thermos: [[1, 2, 3, 4, 5, 6]])
        var givens = solution
        for cell in 0..<9 { givens.cells[cell] = 0 }
        XCTAssertEqual(Solver.solve(givens, in: rising), solution)
        // Rising from cell 0 to cell 1 fails: their columns leave only the 5 and the 3 there.
        let falling = Variant.thermo.with(thermos: [[0, 1]])
        XCTAssertEqual(Solver.countSolutions(givens, in: falling, limit: 2), 0)
        XCTAssertEqual(Solver.countSolutions(solution, in: falling, limit: 2), 0, "givens that break a thermometer have no solution")
    }

    func testThermometersSurviveSaving() throws {
        let variant = Variant.thermo.with(thermos: [[0, 10, 11], [8, 17]])
        XCTAssertEqual(try JSONDecoder().decode(Variant.self, from: JSONEncoder().encode(variant)), variant)
        XCTAssertEqual(variant.thermos[0], [0, 10, 11], "the bulb stays first")
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Variant.classic)) as! [String: Any]
        XCTAssertNil(json["thermos"], "saves from before Thermo carry none")
        for bad in [[[0, 2]], [[0]], [[0, 1], [1, 2]], [[80, 81]]] {
            json["thermos"] = bad
            XCTAssertThrowsError(try JSONDecoder().decode(Variant.self, from: JSONSerialization.data(withJSONObject: json)), "\(bad)")
        }
    }

    func testThermoHint() {
        // A thermometer of five from the top-left corner: its third cell holds 3 to 7.
        let variant = Variant.thermo.with(thermos: [[0, 1, 2, 3, 4]])
        let step = Grader.nextStep(Grid(String(repeating: ".", count: 81)),
                                   candidates: [CandidateMask](repeating: 0x1FF, count: 81), in: variant)
        XCTAssertEqual(step?.technique, .thermo)
        XCTAssertEqual(step?.focus, [0, 1, 2, 3, 4])
        XCTAssertEqual(Set(step?.eliminations.filter { $0.cell == 2 }.map(\.digit) ?? []), [1, 2, 8, 9])
        XCTAssertEqual(Set(step?.eliminations.filter { $0.cell == 0 }.map(\.digit) ?? []), [6, 7, 8, 9])
        XCTAssertEqual(step?.explanation(language: "de"), """
            Auf dem markierten Thermometer steigen die Ziffern vom Kolben aus an, \
            also fällt in seinen Feldern weg, was dafür zu klein oder zu groß ist.
            """)
        XCTAssertTrue(step?.explanation(language: "en").contains("thermometer") == true)
    }

    func testEliminationsInGeneratedPuzzlesAreCorrect() throws {
        var rng = SplitMix64(seed: 9)
        let p = try XCTUnwrap(Generator.make(.hard, variant: .thermo, using: &rng))
        assertStepsAreCorrect(p)
    }
}

final class KropkiTests: XCTestCase {
    private let solution = Grid("534678912672195348198342567859761423426853791713924856961537284287419635345286179")

    func testGeneratedPuzzlesFollowTheDots() throws {
        XCTAssertEqual(Variant.kropki.difficulties, [.easy, .medium, .hard])
        for d in Variant.kropki.difficulties {
            var rng = SplitMix64(seed: 5)
            let p = try XCTUnwrap(Generator.make(d, variant: .kropki, using: &rng), "\(d)")
            XCTAssertEqual(p.variant.offered, .kropki)
            XCTAssertFalse(p.variant.dots.isEmpty)
            for dot in p.variant.dots {
                XCTAssertTrue(neighbours(dot.cells[0]).contains(dot.cells[1]), "\(dot) joins neighbours")
                XCTAssertTrue(dot.allows(Int(p.solution.cells[dot.cells[0]]), Int(p.solution.cells[dot.cells[1]])), "\(dot)")
            }
            XCTAssertEqual(Grader.grade(p.givens, in: p.variant), d)
            XCTAssertEqual(Solver.countSolutions(p.givens, in: p.variant, limit: 2), 1)
            XCTAssertEqual(Solver.solve(p.givens, in: p.variant), p.solution)
        }
    }

    func testDotRules() {
        let white = Dot(4, 3, .white), black = Dot(0, 9, .black)
        XCTAssertEqual(white.cells, [3, 4], "the left cell comes first")
        XCTAssertTrue(white.allows(3, 4))
        XCTAssertTrue(white.allows(5, 4))
        XCTAssertFalse(white.allows(3, 5))
        XCTAssertTrue(black.allows(3, 6))
        XCTAssertTrue(black.allows(8, 4))
        XCTAssertFalse(black.allows(3, 4))
        XCTAssertTrue(white.allows(1, 2) && black.allows(1, 2), "1 and 2 fit both")
    }

    func testSolverKeepsToTheDots() {
        // Row 1 starts 5 3 4: a white dot between 3 and 4 holds, a black one doesn't.
        var givens = solution
        for cell in [1, 2] { givens.cells[cell] = 0 }
        XCTAssertEqual(Solver.solve(givens, in: Variant.kropki.with(dots: [Dot(1, 2, .white)])), solution)
        XCTAssertEqual(Solver.countSolutions(givens, in: Variant.kropki.with(dots: [Dot(1, 2, .black)]), limit: 2), 0)
    }

    func testDotsSurviveSaving() throws {
        let variant = Variant.kropki.with(dots: [Dot(0, 1, .white), Dot(10, 19, .black)])
        XCTAssertEqual(try JSONDecoder().decode(Variant.self, from: JSONEncoder().encode(variant)), variant)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Variant.classic)) as! [String: Any]
        XCTAssertNil(json["dots"], "saves from before Kropki carry none")
        json["dots"] = [["cells": [8, 9], "kind": "white"]]
        XCTAssertThrowsError(try JSONDecoder().decode(Variant.self, from: JSONSerialization.data(withJSONObject: json)),
                             "8 and 9 lie in different rows")
    }

    func testKropkiHint() {
        // A black dot between {3, 5} and {6, 7}: only 3 and 6 pair up, so the 5 and the 7 drop out.
        var masks = [CandidateMask](repeating: 0x1FF, count: 81)
        masks[0] = 1 << 2 | 1 << 4
        masks[1] = 1 << 5 | 1 << 6
        let variant = Variant.kropki.with(dots: [Dot(0, 1, .black)])
        let step = Grader.nextStep(Grid(String(repeating: ".", count: 81)), candidates: masks, in: variant)
        XCTAssertEqual(step?.technique, .kropki)
        XCTAssertEqual(step?.focus, [0, 1])
        XCTAssertEqual(step?.eliminations.map { [$0.cell, $0.digit] }, [[0, 5], [1, 7]])
        XCTAssertEqual(step?.explanation(language: "de"), """
            Am schwarzen Punkt ist eine Ziffer der beiden markierten Felder doppelt so groß wie die andere, \
            also fällt weg, was auf der anderen Seite keinen Partner hat.
            """)
    }

    func testEliminationsInGeneratedPuzzlesAreCorrect() throws {
        var rng = SplitMix64(seed: 9)
        let p = try XCTUnwrap(Generator.make(.hard, variant: .kropki, using: &rng))
        assertStepsAreCorrect(p)
    }
}

/// Every step of the solve keeps the solution's digits and ends on the solution.
private func assertStepsAreCorrect(_ p: Puzzle, file: StaticString = #filePath, line: UInt = #line) {
    var board = Board(p.givens, in: p.variant)
    while let step = board.nextStep() {
        if let placement = step.placement {
            XCTAssertEqual(Int(p.solution.cells[placement.cell]), placement.digit, file: file, line: line)
        }
        for e in step.eliminations {
            XCTAssertNotEqual(Int(p.solution.cells[e.cell]), e.digit, "\(step.technique)", file: file, line: line)
        }
        board.apply(step)
    }
    XCTAssertEqual(Grid(cells: board.cells), p.solution, file: file, line: line)
}
