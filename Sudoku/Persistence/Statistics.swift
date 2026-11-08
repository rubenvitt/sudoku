import Foundation
import SudokuEngine

/// Every started and solved game, for the statistics sheet. Kept apart from the saved game, so finishing or
/// discarding a game never touches it.
struct Statistics: Codable, Equatable, Sendable {
    struct Solve: Codable, Equatable, Sendable {
        /// The menu entry's id, so every Jigsaw or Killer puzzle counts for its variant.
        let variant: String
        let difficulty: Difficulty
        let elapsed: TimeInterval
        let hints: Int
        let checks: Int
        let errors: Int
        let date: Date
    }

    /// What the sheet shows for one variant and difficulty, or for everything.
    struct Summary: Equatable {
        var started = 0
        var solved = 0
        var best: TimeInterval?
        var average: TimeInterval?
        var withoutHints = 0
        var playTime: TimeInterval = 0
    }

    /// Games started per `key(variant:difficulty:)`.
    private(set) var started: [String: Int] = [:]
    private(set) var solves: [Solve] = []

    var isEmpty: Bool { started.isEmpty && solves.isEmpty }

    private static func key(_ variant: String, _ difficulty: Difficulty) -> String { "\(variant)/\(difficulty.rawValue)" }

    mutating func recordStart(_ puzzle: Puzzle) {
        started[Self.key(puzzle.variant.offered.id, puzzle.difficulty), default: 0] += 1
    }

    /// Records a solved game; true if it beat an earlier best time for its variant and difficulty.
    @discardableResult
    mutating func recordSolve(_ game: Game, on date: Date = .now) -> Bool {
        let variant = game.puzzle.variant.offered.id
        let previousBest = summary(variant: variant, difficulty: game.puzzle.difficulty).best
        solves.append(Solve(variant: variant, difficulty: game.puzzle.difficulty, elapsed: game.elapsed,
                            hints: game.hintsUsed, checks: game.checksUsed, errors: game.errorsFound, date: date))
        return previousBest.map { game.elapsed < $0 } ?? false
    }

    /// Nil arguments match every variant or difficulty.
    func summary(variant: String? = nil, difficulty: Difficulty? = nil) -> Summary {
        let matching = solves.filter { (variant == nil || $0.variant == variant) && (difficulty == nil || $0.difficulty == difficulty) }
        let starts = started.filter { key, _ in
            let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
            return parts.count == 2 && (variant == nil || parts[0] == variant)
                && (difficulty == nil || parts[1] == difficulty?.rawValue)
        }.values.reduce(0, +)
        let times = matching.map(\.elapsed)
        let total = times.reduce(0, +)
        return Summary(
            // Games solved before statistics existed were never counted as started.
            started: max(starts, matching.count),
            solved: matching.count,
            best: times.min(),
            average: times.isEmpty ? nil : total / Double(times.count),
            withoutHints: matching.filter { $0.hints == 0 }.count,
            playTime: total)
    }

    /// The offered variants that have been played, in menu order.
    var playedVariants: [Variant] {
        Variant.all.filter { summary(variant: $0.id).started > 0 }
    }
}
