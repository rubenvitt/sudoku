import XCTest
import SudokuEngine
@testable import Sudoku

final class StatisticsTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    private func solved(_ puzzle: Puzzle = StoreTests.puzzle, in seconds: TimeInterval, hint: Bool = false) -> Game {
        var game = Game(puzzle: puzzle)
        if hint { _ = game.hint() }
        game.elapsed = seconds
        return game
    }

    func testBestAndAverageTimePerVariantAndDifficulty() {
        var statistics = Statistics()
        for _ in 0..<3 { statistics.recordStart(StoreTests.puzzle) }
        XCTAssertFalse(statistics.recordSolve(solved(in: 300)), "a first solve has nothing to beat")
        XCTAssertTrue(statistics.recordSolve(solved(in: 200, hint: true)))
        XCTAssertFalse(statistics.recordSolve(solved(in: 250)))

        let summary = statistics.summary(variant: Variant.classic.id, difficulty: .easy)
        XCTAssertEqual(summary.started, 3)
        XCTAssertEqual(summary.solved, 3)
        XCTAssertEqual(summary.best, 200)
        XCTAssertEqual(summary.average, 250)
        XCTAssertEqual(summary.withoutHints, 2)
        XCTAssertEqual(summary.playTime, 750)
        XCTAssertEqual(statistics.summary(variant: Variant.classic.id, difficulty: .hard), Statistics.Summary())
    }

    func testVariantsAreCountedApartAndTotalled() {
        var statistics = Statistics()
        let diagonal = Puzzle(variant: .diagonal, givens: StoreTests.puzzle.givens, solution: StoreTests.puzzle.solution,
                              difficulty: .hard)
        statistics.recordStart(diagonal)
        statistics.recordSolve(solved(diagonal, in: 600))
        statistics.recordStart(StoreTests.puzzle)

        XCTAssertNil(statistics.summary(variant: Variant.classic.id).best)
        XCTAssertEqual(statistics.summary(variant: Variant.diagonal.id, difficulty: .hard).best, 600)
        XCTAssertEqual(statistics.summary().started, 2)
        XCTAssertEqual(statistics.summary().solved, 1)
        XCTAssertEqual(statistics.playedVariants.map(\.id), [Variant.classic.id, Variant.diagonal.id])
    }

    /// A game started before the update was never counted, but its solve is: started never drops below solved.
    func testSolvesWithoutStartStillCount() {
        var statistics = Statistics()
        statistics.recordSolve(solved(in: 100))
        XCTAssertEqual(statistics.summary().started, 1)
    }

    func testStoreKeepsStatisticsApartFromTheGame() throws {
        let store = Store(directory: dir)
        XCTAssertTrue(store.loadStatistics().isEmpty)
        store.updateStatistics { $0.recordStart(StoreTests.puzzle) }
        try store.save(Game(puzzle: StoreTests.puzzle))
        try store.deleteGame()
        XCTAssertEqual(store.loadStatistics().summary().started, 1)

        try "kaputt".write(to: dir.appendingPathComponent("statistics.json"), atomically: true, encoding: .utf8)
        XCTAssertTrue(store.loadStatistics().isEmpty)
    }
}
