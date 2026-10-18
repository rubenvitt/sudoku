import XCTest
@testable import SudokuEngine

final class SolverTests: XCTestCase {
    func testClassicVariantHasTwentyPeers() {
        XCTAssertEqual(Variant.classic.peers(of: 0).count, 20)
        XCTAssertEqual(Variant.classic.groups.count, 27)
    }

    func testSolvesKnownPuzzle() {
        let p = Grid("53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79")
        XCTAssertEqual(Solver.solve(p, in: .classic), Grid("534678912672195348198342567859761423426853791713924856961537284287419635345286179"))
    }

    func testDetectsMultipleSolutions() {
        let p = Grid(String(repeating: ".", count: 81))
        XCTAssertEqual(Solver.countSolutions(p, in: .classic, limit: 2), 2)
    }

    func testRandomSolutionIsValidAndSeeded() {
        var a = SplitMix64(seed: 1), b = SplitMix64(seed: 1)
        let s = Solver.randomSolution(in: .classic, using: &a)
        XCTAssertEqual(s, Solver.randomSolution(in: .classic, using: &b))
        XCTAssertTrue(s.isComplete)
        XCTAssertEqual(Solver.countSolutions(s, in: .classic, limit: 2), 1)
    }

    func testConflictingGivensHaveNoSolution() {
        let p = Grid("11" + String(repeating: ".", count: 79))
        XCTAssertEqual(Solver.countSolutions(p, in: .classic, limit: 2), 0)
        XCTAssertNil(Solver.solve(p, in: .classic))
    }

    func testCandidatesExcludePeerDigits() {
        let p = Grid("5" + String(repeating: ".", count: 80))
        let c = candidates(for: p, in: .classic)
        XCTAssertEqual(c[1] & 0b10000, 0)       // same row
        XCTAssertNotEqual(c[80] & 0b10000, 0)   // unrelated cell
        XCTAssertEqual(c[0], 0b10000)           // filled cell keeps its digit
    }

    func testGridCodableRoundTrip() throws {
        let g = Grid("53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79")
        XCTAssertEqual(try JSONDecoder().decode(Grid.self, from: JSONEncoder().encode(g)), g)
        let v = try JSONDecoder().decode(Variant.self, from: JSONEncoder().encode(Variant.classic))
        XCTAssertEqual(v.peers(of: 40).count, 20)
    }
}
