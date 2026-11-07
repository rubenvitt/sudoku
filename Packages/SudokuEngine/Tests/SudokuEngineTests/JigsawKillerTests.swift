import XCTest
@testable import SudokuEngine

final class JigsawTests: XCTestCase {
    func testGeneratedPuzzlesHaveTheirOwnRegions() throws {
        for d in Difficulty.allCases {
            var rng = SplitMix64(seed: 11)
            let p = try XCTUnwrap(Generator.make(d, variant: .jigsaw, using: &rng), "\(d)")
            let regions = p.variant.regions
            XCTAssertEqual(p.variant.id, "jigsaw")
            XCTAssertEqual(p.variant.offered, .jigsaw)
            XCTAssertNotEqual(Set(regions.map(Set.init)), Set(Variant.classic.regions.map(Set.init)), "regions are no longer the boxes")
            XCTAssertEqual(regions.count, 9)
            XCTAssertEqual(Set(regions.joined()), Set(0..<81), "regions cover the board")
            for region in regions {
                XCTAssertEqual(region.count, 9)
                XCTAssertTrue(isConnected(region), "\(region) is one piece")
                XCTAssertEqual(Set(region.map { p.solution.cells[$0] }), Set(1...9))
            }
            XCTAssertEqual(Solver.countSolutions(p.givens, in: p.variant, limit: 2), 1)
            XCTAssertEqual(Grader.grade(p.givens, in: p.variant), d)
            XCTAssertEqual(Solver.solve(p.givens, in: p.variant), p.solution)
        }
    }

    func testRegionsSurviveSaving() throws {
        var rng = SplitMix64(seed: 3)
        let variant = Variant.jigsaw.with(regions: JigsawRegions.make(using: &rng))
        XCTAssertEqual(try JSONDecoder().decode(Variant.self, from: JSONEncoder().encode(variant)), variant)
    }

    func testHintNamesTheRegionByItsFirstCell() {
        // Empty grid, all candidates open, except that the top-left region allows the 3 only in row 2, column 2.
        var masks = [CandidateMask](repeating: 0x1FF, count: 81)
        for cell in Variant.jigsaw.regions[0] where cell != 10 { masks[cell] &= ~(1 << 2) }
        let step = Grader.nextStep(Grid(String(repeating: ".", count: 81)), candidates: masks, in: .jigsaw)
        XCTAssertEqual(step?.technique, .hiddenSingle)
        XCTAssertEqual(step?.explanation(language: "de"), "Im Gebiet ab Zeile 1, Spalte 1 passt die 3 nur noch in Zeile 2, Spalte 2.")
        XCTAssertTrue(step?.explanation(language: "en").contains("region starting at row 1, column 1") == true)
    }

    private func isConnected(_ region: [Int]) -> Bool {
        let cells = Set(region)
        var seen: Set<Int> = [region[0]], stack = [region[0]]
        while let cell = stack.popLast() {
            for n in neighbours(cell) where cells.contains(n) && seen.insert(n).inserted { stack.append(n) }
        }
        return seen == cells
    }
}

final class KillerTests: XCTestCase {
    /// sudoku from the Wikipedia article, solved.
    private let solution = Grid("534678912672195348198342567859761423426853791713924856961537284287419635345286179")

    func testGeneratedPuzzlesFollowTheCages() throws {
        for d in Difficulty.allCases {
            var rng = SplitMix64(seed: 5)
            let p = try XCTUnwrap(Generator.make(d, variant: .killer, using: &rng), "\(d)")
            XCTAssertEqual(p.variant.offered, .killer)
            XCTAssertEqual(p.variant.regions, Variant.classic.regions)
            let cells = p.variant.cages.flatMap(\.cells)
            XCTAssertEqual(cells.count, 81, "cages don't overlap")
            XCTAssertEqual(Set(cells), Set(0..<81), "cages cover the board")
            for cage in p.variant.cages {
                let digits = cage.cells.map { Int(p.solution.cells[$0]) }
                XCTAssertEqual(Set(digits).count, digits.count, "no digit repeats in a cage")
                XCTAssertEqual(digits.reduce(0, +), cage.sum)
            }
            XCTAssertEqual(Grader.grade(p.givens, in: p.variant), d)
            // A grade means the techniques solve it without guessing, which already proves the solution unique.
            XCTAssertEqual(Solver.solve(p.givens, in: p.variant), p.solution)
        }
    }

    func testSolverKeepsToTheSums() {
        var rng = SplitMix64(seed: 1)
        let cages = KillerGenerator.cages(over: solution, sizes: [2, 3, 4], using: &rng)
        XCTAssertEqual(Set(cages.flatMap(\.cells)), Set(0..<81))
        var givens = solution
        for cell in Variant.classic.regions[0] { givens.cells[cell] = 0 }
        XCTAssertEqual(Solver.solve(givens, in: Variant.killer.with(cages: cages)), solution)
        // One sum off by one: the cell it covers can no longer be filled.
        let wrongSum = [Cage(cells: cages[0].cells, sum: cages[0].sum + 1)] + cages.dropFirst()
        var almost = solution
        almost.cells[cages[0].cells[0]] = 0
        XCTAssertEqual(Solver.countSolutions(almost, in: Variant.killer.with(cages: wrongSum), limit: 2), 0)
        XCTAssertEqual(Solver.countSolutions(almost, in: Variant.killer.with(cages: cages), limit: 2), 1)
    }

    func testCagesSurviveSaving() throws {
        let variant = Variant.killer.with(cages: [Cage(cells: [1, 0], sum: 8), Cage(cells: [2], sum: 4)])
        XCTAssertEqual(variant.cages[0].cells, [0, 1], "cells are kept in reading order")
        XCTAssertEqual(try JSONDecoder().decode(Variant.self, from: JSONEncoder().encode(variant)), variant)
        // Saves from before Killer carry no cages at all.
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Variant.classic)) as! [String: Any]
        XCTAssertNil(json["cages"])
        json["cages"] = [["cells": [0, 1], "sum": 3], ["cells": [1, 2], "sum": 5]]
        XCTAssertThrowsError(try JSONDecoder().decode(Variant.self, from: JSONSerialization.data(withJSONObject: json)), "overlapping cages")
        json["cages"] = [["cells": [80, 81], "sum": 3]]
        XCTAssertThrowsError(try JSONDecoder().decode(Variant.self, from: JSONSerialization.data(withJSONObject: json)), "cell off the board")
    }

    func testCagePeersSeeEachOther() {
        let variant = Variant.killer.with(cages: [Cage(cells: [0, 10, 20, 30], sum: 10)])
        XCTAssertTrue(variant.peers(of: 0).contains(30), "a cage's digits differ, even across boxes")
    }

    func testCageSumHint() {
        let variant = Variant.killer.with(cages: [Cage(cells: [0, 1], sum: 3)])
        let step = Grader.nextStep(Grid(String(repeating: ".", count: 81)),
                                   candidates: [CandidateMask](repeating: 0x1FF, count: 81), in: variant)
        XCTAssertEqual(step?.technique, .cageSum)
        XCTAssertEqual(step?.focus, [0, 1])
        XCTAssertEqual(Set(step?.eliminations.map(\.digit) ?? []), Set(3...9))
        XCTAssertEqual(step?.explanation(language: "de"),
                       "Die markierten Felder ergeben zusammen 3. Das geht nur noch mit 1 + 2, also fällt dort weg, was nicht dazu passt.")
        XCTAssertEqual(step?.explanation(language: "en"),
                       "The marked cells add up to 3. That only works with 1 + 2, so whatever doesn’t fit drops out there.")
    }

    func testRuleOf45Hint() {
        // Row 1 holds cages of 15, 15 and 9, so its last cell is 45 − 39 = 6.
        let variant = Variant.killer.with(cages: [Cage(cells: [0, 1, 2], sum: 15), Cage(cells: [3, 4, 5], sum: 15), Cage(cells: [6, 7], sum: 9)])
        var board = Board(Grid(String(repeating: ".", count: 81)), in: variant)
        var step = board.nextStep()
        while let s = step, s.technique != .rule45 {
            board.apply(s)
            step = board.nextStep()
        }
        XCTAssertEqual(step?.focus, [8])
        XCTAssertEqual(Set(step?.eliminations.map(\.digit) ?? []), Set(1...9).subtracting([6]))
        XCTAssertEqual(step?.explanation(language: "de"), """
            In Zeile 1 ergeben alle Ziffern zusammen 45 und die Käfige ganz darin 39, also ergeben die markierten Felder \
            zusammen 6. Das geht nur noch mit 6, also fällt dort weg, was nicht dazu passt.
            """)
    }

    func testEliminationsInGeneratedPuzzlesAreCorrect() throws {
        var rng = SplitMix64(seed: 9)
        let p = try XCTUnwrap(Generator.make(.hard, variant: .killer, using: &rng))
        var board = Board(p.givens, in: p.variant)
        while let step = board.nextStep() {
            if let placement = step.placement { XCTAssertEqual(Int(p.solution.cells[placement.cell]), placement.digit) }
            for e in step.eliminations {
                XCTAssertNotEqual(Int(p.solution.cells[e.cell]), e.digit, "\(step.technique): \(step.explanation(language: "de"))")
            }
            board.apply(step)
        }
        XCTAssertEqual(Grid(cells: board.cells), p.solution)
    }
}
