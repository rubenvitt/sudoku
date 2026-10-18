import Foundation
import Observation
import SudokuEngine

@MainActor @Observable
final class PuzzleStock {
    private let store: Store
    private let fixed: Puzzle?
    private var stock: [Difficulty: Puzzle]
    private var tasks: [Difficulty: Task<Void, Never>] = [:]

    /// `fixed` is the UI-test hook: every `take` returns it and nothing is generated.
    init(store: Store, fixed: Puzzle? = nil) {
        self.store = store
        self.fixed = fixed
        stock = store.loadStock()
    }

    func isGenerating(_ difficulty: Difficulty) -> Bool { tasks[difficulty] != nil }

    func fillAll() {
        for difficulty in Difficulty.allCases { fill(difficulty) }
    }

    func take(_ difficulty: Difficulty) async -> Puzzle {
        if let fixed { return fixed }
        while true {
            if let puzzle = stock.removeValue(forKey: difficulty) {
                persist()
                fill(difficulty)
                return puzzle
            }
            fill(difficulty)
            await tasks[difficulty]?.value
        }
    }

    private func fill(_ difficulty: Difficulty) {
        guard fixed == nil, stock[difficulty] == nil, tasks[difficulty] == nil else { return }
        tasks[difficulty] = Task {
            let puzzle = await Task.detached { Self.generate(difficulty) }.value
            stock[difficulty] = puzzle
            tasks[difficulty] = nil
            persist()
        }
    }

    private func persist() {
        try? store.saveStock(stock) // a lost stock file only costs regeneration
    }

    nonisolated private static func generate(_ difficulty: Difficulty) -> Puzzle {
        var rng = SystemRandomNumberGenerator()
        while true {
            if let puzzle = Generator.make(difficulty, using: &rng) { return puzzle }
        }
    }
}
