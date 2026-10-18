import SwiftUI
import SudokuEngine

@main
struct SudokuApp: App {
    @State private var stock: PuzzleStock
    private let store: Store

    init() {
        let store: Store
        let fixed: Puzzle?
        #if DEBUG // UI tests run in Debug; the shipped app never reads this launch argument
        if ProcessInfo.processInfo.arguments.contains("-uiTestFixedPuzzle") {
            store = Store(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
            fixed = Puzzle(
                variant: .classic,
                givens: Grid("53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"),
                solution: Grid("534678912672195348198342567859761423426853791713924856961537284287419635345286179"),
                difficulty: .easy)
        } else {
            store = .applicationSupport
            fixed = nil
        }
        #else
        store = .applicationSupport
        fixed = nil
        #endif
        let stock = PuzzleStock(store: store, fixed: fixed)
        stock.fillAll()
        _stock = State(initialValue: stock)
        self.store = store
    }

    var body: some Scene {
        WindowGroup { MenuView(store: store).environment(stock) }
    }
}
