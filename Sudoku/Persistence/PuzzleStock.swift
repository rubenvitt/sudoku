import Foundation
import Observation
import SudokuEngine

/// One ready puzzle per variant and difficulty, so a new game starts without waiting.
@MainActor @Observable
final class PuzzleStock {
    private struct Kind: Hashable {
        let variant: Variant
        let difficulty: Difficulty
    }

    private let store: Store
    private let fixed: Puzzle?
    /// Per variant id; a variant's file is read the first time that variant is asked for.
    private var stock: [String: [Difficulty: Puzzle]] = [:]
    private var tasks: [Kind: Task<Void, Never>] = [:]

    /// `fixed` is the UI-test hook: every `take` returns it and nothing is generated.
    init(store: Store, fixed: Puzzle? = nil) {
        self.store = store
        self.fixed = fixed
    }

    func isGenerating(_ difficulty: Difficulty, variant: Variant = .classic) -> Bool {
        tasks[Kind(variant: variant, difficulty: difficulty)] != nil
    }

    func fillAll(_ variant: Variant = .classic) {
        for difficulty in Difficulty.allCases { fill(Kind(variant: variant, difficulty: difficulty)) }
    }

    func take(_ difficulty: Difficulty, variant: Variant = .classic) async -> Puzzle {
        if let fixed { return fixed }
        let kind = Kind(variant: variant, difficulty: difficulty)
        while true {
            loadIfNeeded(variant)
            if let puzzle = stock[variant.id]?.removeValue(forKey: difficulty) {
                persist(variant)
                fill(kind)
                return puzzle
            }
            fill(kind)
            await tasks[kind]?.value
        }
    }

    private func loadIfNeeded(_ variant: Variant) {
        if stock[variant.id] == nil { stock[variant.id] = store.loadStock(variant) }
    }

    private func fill(_ kind: Kind) {
        guard fixed == nil else { return }
        loadIfNeeded(kind.variant)
        guard stock[kind.variant.id]?[kind.difficulty] == nil, tasks[kind] == nil else { return }
        tasks[kind] = Task {
            let puzzle = await Task.detached { Self.generate(kind) }.value
            stock[kind.variant.id, default: [:]][kind.difficulty] = puzzle
            tasks[kind] = nil
            persist(kind.variant)
        }
    }

    private func persist(_ variant: Variant) {
        try? store.saveStock(stock[variant.id] ?? [:], variant: variant) // a lost stock file only costs regeneration
    }

    nonisolated private static func generate(_ kind: Kind) -> Puzzle {
        var rng = SystemRandomNumberGenerator()
        while true {
            if let puzzle = Generator.make(kind.difficulty, variant: kind.variant, using: &rng) { return puzzle }
        }
    }
}
