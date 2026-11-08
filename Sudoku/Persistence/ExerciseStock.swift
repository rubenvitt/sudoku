import Foundation
import Observation
import SudokuEngine

/// Practice exercises and progress. Every technique starts with a fixed starter; exercises mined from freshly
/// generated puzzles join it in the background, and each one is handed out in a new disguise.
@MainActor @Observable
final class ExerciseStock {
    /// Solved exercises after which a technique counts as practised. It unlocks nothing.
    static let practisedAfter = 3

    private let store: Store
    /// Mined exercises by technique name, at most `poolSize` each.
    private var pool: [String: [Exercise]]
    private(set) var solved: [String: Int]
    private var mining: Task<Void, Never>?
    private static let poolSize = 8

    init(store: Store) {
        self.store = store
        pool = store.loadExercises()
        solved = store.loadPractice()
    }

    func isPractised(_ technique: Technique) -> Bool { solved["\(technique)", default: 0] >= Self.practisedAfter }

    var practisedCount: Int { Exercises.techniques.filter(isPractised).count }

    /// A new exercise for `technique`, disguised so it doesn't look like the last one.
    func take(_ technique: Technique) -> Exercise? {
        var rng = SystemRandomNumberGenerator()
        let base = pool["\(technique)"]?.randomElement(using: &rng) ?? Exercises.starters[technique]
        mine(for: technique)
        return base?.transformed(using: &rng)
    }

    func recordSolved(_ technique: Technique) {
        solved["\(technique)", default: 0] += 1
        try? store.savePractice(solved) // a lost file only resets the ticks
    }

    /// Generates one puzzle of the technique's difficulty and keeps every exercise it yields, for all techniques.
    private func mine(for technique: Technique) {
        guard mining == nil, pool["\(technique)", default: []].count < Self.poolSize else { return }
        let difficulty = technique.difficulty
        mining = Task {
            let found = await Task.detached(priority: .utility) { Self.exercises(difficulty) }.value
            for exercise in found {
                var list = pool["\(exercise.technique)", default: []]
                guard list.count < Self.poolSize else { continue }
                list.append(exercise)
                pool["\(exercise.technique)"] = list
            }
            try? store.saveExercises(pool) // a lost file only costs mining again
            mining = nil
        }
    }

    nonisolated private static func exercises(_ difficulty: Difficulty) -> [Exercise] {
        var rng = SystemRandomNumberGenerator()
        guard let puzzle = Generator.make(difficulty, using: &rng, maxAttempts: 20) else { return [] }
        return Exercises.mine(givens: puzzle.givens, solution: puzzle.solution)
    }
}
