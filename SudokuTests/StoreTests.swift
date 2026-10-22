import XCTest
import SudokuEngine
@testable import Sudoku

final class StoreTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    static let puzzle = Puzzle(
        variant: .classic,
        givens: Grid("53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"),
        solution: Grid("534678912672195348198342567859761423426853791713924856961537284287419635345286179"),
        difficulty: .easy)

    func testSaveAndLoadGame() throws {
        let store = Store(directory: dir)
        var game = Game(puzzle: Self.puzzle)
        game.setDigit(4, at: 2)
        try store.save(game)
        let loaded = try XCTUnwrap(store.loadGame())
        XCTAssertEqual(loaded.entries, game.entries)
        try store.deleteGame()
        XCTAssertNil(store.loadGame())
    }

    func testInkIsSavedWithTheGameAndResetByANewOne() throws {
        let store = Store(directory: dir)
        let ink = try XCTUnwrap(Ink(digit: 4, strokes: [[.zero, CGPoint(x: 10, y: 10)]], in: CGRect(x: 0, y: 0, width: 20, height: 20)))
        try store.save(Game(puzzle: Self.puzzle), ink: [2: ink])
        XCTAssertEqual(store.loadInk(), [2: ink])
        try store.save(Game(puzzle: Self.puzzle)) // a new game
        XCTAssertEqual(store.loadInk(), [:])
        try store.save(Game(puzzle: Self.puzzle), ink: [2: ink])
        try store.deleteGame()
        XCTAssertEqual(store.loadInk(), [:])
    }

    func testLoadReturnsNilForCorruptFile() throws {
        let store = Store(directory: dir)
        try "kaputt".write(to: dir.appendingPathComponent("game.json"), atomically: true, encoding: .utf8)
        try "kaputt".write(to: dir.appendingPathComponent("stock.json"), atomically: true, encoding: .utf8)
        XCTAssertNil(store.loadGame())
        XCTAssertTrue(store.loadStock().isEmpty)
    }

    func testStockRoundTrip() throws {
        let store = Store(directory: dir)
        try store.saveStock([.easy: Self.puzzle])
        XCTAssertEqual(store.loadStock()[.easy], Self.puzzle)
    }
}
