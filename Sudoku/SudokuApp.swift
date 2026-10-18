import SwiftUI
import SudokuEngine

@main
struct SudokuApp: App {
    @State private var stock: PuzzleStock

    init() {
        let isUITest = ProcessInfo.processInfo.arguments.contains("-uiTestFixedPuzzle")
        let store = isUITest
            ? Store(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
            : .applicationSupport
        let fixed = isUITest ? Puzzle(
            variant: .classic,
            givens: Grid("53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"),
            solution: Grid("534678912672195348198342567859761423426853791713924856961537284287419635345286179"),
            difficulty: .easy) : nil
        let stock = PuzzleStock(store: store, fixed: fixed)
        stock.fillAll()
        _stock = State(initialValue: stock)
    }

    var body: some Scene {
        WindowGroup { MenuView().environment(stock) }
    }
}

// Placeholder until the real UI replaces it.
struct MenuView: View {
    var body: some View { Text("Sudoku") }
}
