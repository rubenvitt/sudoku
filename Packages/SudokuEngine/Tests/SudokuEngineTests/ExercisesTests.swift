import XCTest
@testable import SudokuEngine

final class ExercisesTests: XCTestCase {
    /// Boards from GraderTests' sources, one per technique.
    private let boards: [Technique: String] = [
        .hiddenSingle: "000000000904607000076804100309701080008000300050308702007502610000403208000000000",
        .intersection: "010903600000080000900000507002010430000402000064070200701000005000030000005601020",
        .nakedPair: "080090030030000069902063158020804590851907046394605870563040987200000015010050020",
        .hiddenPair: "720408030080000047401076802810739000000851000000264080209680413340000008168943275",
        .nakedTriple: "001400000000070008600000100300205000500001000000000070070000240080000000000030000",
        .xWing: "100000569402000008050009040000640801000010000208035000040500010900000402621000005",
        .swordfish: "500010003006003002003200000002300076000050000190007500000009400200800600900040005",
        .xyWing: "034500000802060400600008000003900004050000090900005800000300008001040605000007120",
    ]

    private func exercises(_ board: String) throws -> [Exercise] {
        let givens = Grid(board)
        let solution = try XCTUnwrap(Solver.solve(givens, in: .classic))
        return Exercises.mine(givens: givens, solution: solution)
    }

    func testEveryBoardYieldsItsTechnique() throws {
        for (technique, board) in boards {
            let found = try exercises(board).map(\.technique)
            XCTAssertTrue(found.contains(technique), "\(technique): \(found)")
            XCTAssertEqual(found, Exercises.techniques.filter(found.contains), "in teaching order")
        }
    }

    func testNothingEasierHelps() throws {
        for board in boards.values {
            for exercise in try exercises(board) {
                let board = Board(layout: Layout(.classic), cells: exercise.cells.cells, cand: exercise.candidates)
                XCTAssertEqual(board.nextStep()?.technique, exercise.technique)
                assertApplicationsAreCorrect(exercise)
            }
        }
    }

    func testSinglesComeWithUntouchedCandidates() throws {
        let singles = try exercises(boards[.hiddenSingle]!).filter { $0.technique <= .hiddenSingle }
        XCTAssertFalse(singles.isEmpty)
        for exercise in singles {
            XCTAssertEqual(exercise.candidates, candidates(for: exercise.cells, in: .classic), "\(exercise.technique)")
        }
    }

    func testEveryApplicationCounts() throws {
        // An empty board where the 5 fits in row 1 only at its start and in row 9 only at its end: two hidden singles.
        var masks = [CandidateMask](repeating: 0x1FF, count: 81)
        for cell in 1..<9 { masks[cell] &= ~digitBit(5) }
        for cell in 72..<80 { masks[cell] &= ~digitBit(5) }
        let board = Board(layout: Layout(.classic), cells: [UInt8](repeating: 0, count: 81), cand: masks)
        let placements = board.steps(of: .hiddenSingle).compactMap(\.placement).map { [$0.cell, $0.digit] }
        XCTAssertTrue(placements.contains([0, 5]) && placements.contains([80, 5]), "\(placements)")
        XCTAssertEqual(board.first(.hiddenSingle)?.placement?.cell, board.nextStep()?.placement?.cell)
    }

    func testDisguisedExercisesStayTheSameTechnique() throws {
        var rng = SplitMix64(seed: 4)
        for board in boards.values {
            for exercise in try exercises(board) {
                for _ in 0..<5 {
                    let disguised = exercise.transformed(using: &rng)
                    XCTAssertEqual(disguised.technique, exercise.technique)
                    XCTAssertTrue(disguised.solution.isComplete)
                    XCTAssertEqual(Solver.countSolutions(disguised.solution, in: .classic, limit: 2), 1, "the solution is a valid grid")
                    for cell in 0..<81 {
                        let digit = Int(disguised.solution.cells[cell])
                        XCTAssertNotEqual(disguised.candidates[cell] & digitBit(digit), 0, "the solution stays possible")
                        if disguised.cells.cells[cell] != 0 { XCTAssertEqual(Int(disguised.cells.cells[cell]), digit) }
                    }
                    let next = Board(layout: Layout(.classic), cells: disguised.cells.cells, cand: disguised.candidates).nextStep()
                    XCTAssertEqual(next?.technique, exercise.technique)
                    XCTAssertEqual(disguised.applications.count, exercise.applications.count)
                    assertApplicationsAreCorrect(disguised)
                }
            }
        }
    }

    func testExercisesSurviveSaving() throws {
        let exercise = try XCTUnwrap(try exercises(boards[.xWing]!).first { $0.technique == .xWing })
        let data = try JSONEncoder().encode(exercise)
        XCTAssertEqual(try JSONDecoder().decode(Exercise.self, from: data), exercise)
        XCTAssertEqual(String(data: try JSONEncoder().encode(Technique.xWing), encoding: .utf8), "\"xWing\"", "saved by name")
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json["candidates"] = [511]
        XCTAssertThrowsError(try JSONDecoder().decode(Exercise.self, from: JSONSerialization.data(withJSONObject: json)))
        json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json["technique"] = "uniqueRectangle"
        XCTAssertThrowsError(try JSONDecoder().decode(Exercise.self, from: JSONSerialization.data(withJSONObject: json)))
    }

    /// How many generated puzzles it takes until each technique shows up; printed for the CI log.
    func testHowOftenTechniquesComeUp() throws {
        var counts: [Technique: Int] = [:]
        var rng = SplitMix64(seed: 21)
        var puzzles = 0
        for difficulty in [Difficulty.medium, .hard, .expert] {
            for _ in 0..<4 {
                guard let p = Generator.make(difficulty, using: &rng) else { continue }
                puzzles += 1
                for exercise in Exercises.mine(givens: p.givens, solution: p.solution) { counts[exercise.technique, default: 0] += 1 }
            }
        }
        print("Exercises from \(puzzles) puzzles:", Exercises.techniques.map { "\($0) \(counts[$0] ?? 0)" }.joined(separator: ", "))
        for technique in [Technique.nakedSingle, .hiddenSingle, .intersection] {
            XCTAssertGreaterThan(counts[technique] ?? 0, 0, "\(technique)")
        }
    }

    private func assertApplicationsAreCorrect(_ exercise: Exercise, file: StaticString = #filePath, line: UInt = #line) {
        let applications = exercise.applications
        XCTAssertFalse(applications.isEmpty, "\(exercise.technique)", file: file, line: line)
        for step in applications {
            XCTAssertEqual(step.technique, exercise.technique, file: file, line: line)
            if let p = step.placement { XCTAssertEqual(Int(exercise.solution.cells[p.cell]), p.digit, file: file, line: line) }
            for e in step.eliminations {
                XCTAssertNotEqual(Int(exercise.solution.cells[e.cell]), e.digit, "\(step.technique)", file: file, line: line)
            }
        }
    }
}

final class ExerciseJudgeTests: XCTestCase {
    private func exercise(_ technique: Technique, board: String) throws -> Exercise {
        let givens = Grid(board)
        let solution = try XCTUnwrap(Solver.solve(givens, in: .classic))
        return try XCTUnwrap(Exercises.mine(givens: givens, solution: solution).first { $0.technique == technique })
    }

    func testCrossingOutEveryNoteOfOneApplicationSolves() throws {
        let x = try exercise(.xWing, board: "100000569402000008050009040000640801000010000208035000040500010900000402621000005")
        var game = x.game
        XCTAssertEqual(game.notes.filter { $0 != 0 }.count, x.cells.cells.filter { $0 == 0 }.count, "every open cell has its notes")
        guard case .going = x.judge(entries: game.entries, notes: game.notes) else { return XCTFail("fresh exercise") }
        let step = try XCTUnwrap(x.applications.last, "any application counts, not just the first")
        for e in step.eliminations {
            if case .wrong = x.judge(entries: game.entries, notes: game.notes) { return XCTFail("crossing out \(e) is backed") }
            game.toggleNote(e.digit, at: e.cell)
        }
        guard case .solved = x.judge(entries: game.entries, notes: game.notes) else { return XCTFail("all notes of one application") }
    }

    func testWrongMovesAreCaught() throws {
        let x = try exercise(.xWing, board: "100000569402000008050009040000640801000010000208035000040500010900000402621000005")
        let open = try XCTUnwrap((0..<81).first { x.cells.cells[$0] == 0 })
        // Crossing out the solution's own digit is never backed by the technique.
        var game = x.game
        let digit = Int(x.solution.cells[open])
        game.toggleNote(digit, at: open)
        guard case let .wrong(cell, d, isNote) = x.judge(entries: game.entries, notes: game.notes) else { return XCTFail() }
        XCTAssertEqual([cell, d], [open, digit])
        XCTAssertTrue(isNote)
        // Placing even the right digit is no X-Wing.
        game = x.game
        game.setDigit(digit, at: open)
        guard case .wrong(_, _, false) = x.judge(entries: game.entries, notes: game.notes) else { return XCTFail() }
    }

    func testSinglesWantTheDigit() throws {
        let x = try exercise(.hiddenSingle, board: "000000000904607000076804100309701080008000300050308702007502610000403208000000000")
        XCTAssertTrue(x.isSingle)
        var game = x.game
        XCTAssertTrue(game.notes.allSatisfy { $0 == 0 }, "singles start without notes")
        game.toggleNote(1, at: try XCTUnwrap((0..<81).first { x.cells.cells[$0] == 0 }))
        guard case .going = x.judge(entries: game.entries, notes: game.notes) else { return XCTFail("notes don't count") }
        let placement = try XCTUnwrap(x.applications.first?.placement)
        game.setDigit(placement.digit, at: placement.cell)
        guard case .solved = x.judge(entries: game.entries, notes: game.notes) else { return XCTFail() }
    }
}

final class ExerciseStarterTests: XCTestCase {
    func testEveryTechniqueHasAStarter() {
        XCTAssertEqual(Set(Exercises.starters.keys), Set(Exercises.techniques))
        for (technique, exercise) in Exercises.starters {
            XCTAssertEqual(exercise.technique, technique)
            XCTAssertFalse(exercise.applications.isEmpty, "\(technique)")
        }
    }
}
