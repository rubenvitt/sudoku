import XCTest
import SudokuEngine
@testable import Sudoku

@MainActor
final class PuzzleStockTests: XCTestCase {
    func testStockRefillsAfterTake() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = Store(directory: dir)
        let stock = PuzzleStock(store: store)

        let puzzle = await stock.take(.easy)
        XCTAssertEqual(puzzle.difficulty, .easy)

        // Debug builds generate slowly, hence the generous deadline.
        let deadline = Date().addingTimeInterval(120)
        while store.loadStock()[.easy] == nil, Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertNotNil(store.loadStock()[.easy])
        XCTAssertFalse(stock.isGenerating(.easy))
    }

    func testFixedPuzzleIgnoresDifficulty() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let stock = PuzzleStock(store: Store(directory: dir), fixed: StoreTests.puzzle)
        let puzzle = await stock.take(.expert)
        XCTAssertEqual(puzzle, StoreTests.puzzle)
    }
}
