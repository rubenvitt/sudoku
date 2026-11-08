import XCTest
import SudokuEngine
@testable import Sudoku

@MainActor
final class ExerciseStockTests: XCTestCase {
    private func store() -> (Store, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (Store(directory: dir), dir)
    }

    func testEveryTechniqueHasAnExerciseRightAway() throws {
        let (store, dir) = store()
        defer { try? FileManager.default.removeItem(at: dir) }
        let stock = ExerciseStock(store: store)
        for technique in Exercises.techniques {
            let exercise = try XCTUnwrap(stock.take(technique), "\(technique)")
            XCTAssertEqual(exercise.technique, technique)
            XCTAssertFalse(exercise.applications.isEmpty, "\(technique)")
        }
    }

    func testPractisedAfterThreeAndKeptOnDisk() {
        let (store, dir) = store()
        defer { try? FileManager.default.removeItem(at: dir) }
        let stock = ExerciseStock(store: store)
        for _ in 0..<ExerciseStock.practisedAfter - 1 { stock.recordSolved(.xWing) }
        XCTAssertFalse(stock.isPractised(.xWing))
        stock.recordSolved(.xWing)
        XCTAssertTrue(stock.isPractised(.xWing))
        XCTAssertEqual(stock.practisedCount, 1)
        XCTAssertTrue(ExerciseStock(store: store).isPractised(.xWing), "progress survives a restart")
    }

    func testMinedExercisesAreSaved() async throws {
        let (store, dir) = store()
        defer { try? FileManager.default.removeItem(at: dir) }
        let stock = ExerciseStock(store: store)
        _ = stock.take(.nakedSingle) // starts mining an easy puzzle in the background
        // Debug builds generate slowly, hence the generous deadline.
        let deadline = Date().addingTimeInterval(120)
        while store.loadExercises().isEmpty, Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        let saved = store.loadExercises()
        XCTAssertFalse(saved.isEmpty)
        for (name, exercises) in saved {
            XCTAssertTrue(exercises.allSatisfy { "\($0.technique)" == name })
        }
    }
}
