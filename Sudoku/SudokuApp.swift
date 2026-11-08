import SwiftUI
import SudokuEngine

@main
struct SudokuApp: App {
    @State private var stock: PuzzleStock
    @State private var exercises: ExerciseStock
    @AppStorage(AccentTheme.storageKey) private var accent: AccentTheme = .ocean
    private let store: Store

    init() {
        let store: Store
        let fixed: Puzzle?
        var fixedVariants: [Puzzle] = []
        #if DEBUG // UI tests run in Debug; the shipped app never reads this launch argument
        if ProcessInfo.processInfo.arguments.contains("-uiTestFixedPuzzle") {
            store = Store(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
            fixed = UITestFixtures.classic
            fixedVariants = [UITestFixtures.killer, UITestFixtures.jigsaw]
        } else {
            store = .applicationSupport
            fixed = nil
        }
        #else
        store = .applicationSupport
        fixed = nil
        #endif
        let stock = PuzzleStock(store: store, fixed: fixed, fixedVariants: fixedVariants)
        stock.fillAll()
        _stock = State(initialValue: stock)
        _exercises = State(initialValue: ExerciseStock(store: store))
        self.store = store
    }

    var body: some Scene {
        WindowGroup {
            MenuView(store: store)
                .environment(stock)
                .environment(exercises)
                .environment(\.accent, accent.color)
                .tint(accent.color)
        }
    }
}
