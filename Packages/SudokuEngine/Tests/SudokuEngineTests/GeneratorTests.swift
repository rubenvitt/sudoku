import XCTest
@testable import SudokuEngine

final class GeneratorTests: XCTestCase {
    func testGeneratedPuzzlesAreUniqueAndMatchDifficulty() throws {
        for d in Difficulty.allCases {
            for seed: UInt64 in 1...3 {
                var rng = SplitMix64(seed: seed)
                let p = try XCTUnwrap(Generator.make(d, using: &rng), "\(d) seed \(seed)")
                XCTAssertEqual(p.difficulty, d)
                XCTAssertEqual(Solver.countSolutions(p.givens, in: .classic, limit: 2), 1)
                XCTAssertEqual(Grader.grade(p.givens, in: .classic), d)
                XCTAssertEqual(Solver.solve(p.givens, in: .classic), p.solution)
            }
        }
    }

    /// Target: < 3 s average in a release build (`swift test -c release --filter GeneratorTests`).
    func testExpertGenerationIsFastEnough() {
        var seed: UInt64 = 100
        measure {
            seed += 1
            var rng = SplitMix64(seed: seed)
            XCTAssertNotNil(Generator.make(.expert, using: &rng))
        }
    }
}
