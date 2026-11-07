import XCTest
@testable import SudokuEngine

/// Temporary: grade distribution and time per attempt, run in Release by the bench workflow.
final class BenchTests: XCTestCase {
    func testJigsawAttempts() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BENCH"] == "1")
        var rng = SplitMix64(seed: 42)
        var counts: [String: Int] = [:]
        var layoutTime = 0.0, solveFails = 0, removeTime = 0.0, gradeTime = 0.0
        for _ in 0..<40 {
            var t = Date()
            var layout = Variant.jigsaw
            var solution: Grid?
            while solution == nil {
                layout = Variant.jigsaw.with(regions: JigsawRegions.make(using: &rng))
                solution = Solver.randomSolution(in: layout, using: &rng, maxNodes: 30_000)
                if solution == nil { solveFails += 1 }
            }
            layoutTime += Date().timeIntervalSince(t)
            t = Date()
            var givens = solution!
            for i in (0...40).shuffled(using: &rng) {
                var trial = givens
                for cell in Set([i, 80 - i]) { trial.cells[cell] = 0 }
                if Grader.solve(trial, in: layout).difficulty != nil { givens = trial }
            }
            removeTime += Date().timeIntervalSince(t)
            t = Date()
            let g = Grader.grade(givens, in: layout)
            gradeTime += Date().timeIntervalSince(t)
            counts[g.map(\.rawValue) ?? "nil", default: 0] += 1
        }
        print("BENCH jigsaw-logic 40 attempts: \(counts) layout+solution \(layoutTime)s (\(solveFails) failed layouts) removal \(removeTime)s grade \(gradeTime)s")
    }

    func testKillerAttempts() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BENCH"] == "1")
        for (name, sizes) in [("big", [2, 3, 3, 4, 4, 5, 5]), ("huge", [3, 4, 4, 5, 5, 6])] {
            var rng = SplitMix64(seed: 42)
            var counts: [String: Int] = [:]
            var givensTotal = 0
            let t = Date()
            for _ in 0..<60 {
                let solution = Solver.randomSolution(in: .classic, using: &rng)
                let variant = Variant.killer.with(cages: KillerGenerator.cages(over: solution, sizes: sizes, using: &rng))
                var givens = KillerGenerator.givensForLogic(in: variant, solution: solution, using: &rng)
                for cell in (0..<81).filter({ givens.cells[$0] != 0 }).shuffled(using: &rng) {
                    let trial = givens.setting(cell, to: 0)
                    if Grader.solve(trial, in: variant).difficulty != nil { givens = trial }
                }
                givensTotal += givens.cells.filter { $0 != 0 }.count
                let g = Grader.grade(givens, in: variant)
                counts[g.map(\.rawValue) ?? "nil", default: 0] += 1
            }
            print("BENCH killer \(name) 60 attempts: \(counts) avg givens \(Double(givensTotal) / 60) total \(Date().timeIntervalSince(t))s")
        }
        for d in [Difficulty]() {
            var rng = SplitMix64(seed: 7)
            let t = Date()
            let p = Generator.make(d, variant: .killer, using: &rng)
            print("BENCH killer make \(d): \(Date().timeIntervalSince(t))s ok=\(p != nil)")
        }
    }
}
