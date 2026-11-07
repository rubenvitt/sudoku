public struct Puzzle: Codable, Hashable, Sendable {
    public let variant: Variant
    public let givens: Grid
    public let solution: Grid
    public let difficulty: Difficulty

    public init(variant: Variant, givens: Grid, solution: Grid, difficulty: Difficulty) {
        self.variant = variant
        self.givens = givens
        self.solution = solution
        self.difficulty = difficulty
    }
}

public enum Generator {
    public static func make(
        _ difficulty: Difficulty,
        variant: Variant = .classic,
        using rng: inout some RandomNumberGenerator,
        maxAttempts: Int = 200
    ) -> Puzzle? {
        if variant.id == Variant.killer.id {
            return KillerGenerator.make(difficulty, using: &rng, maxAttempts: maxAttempts)
        }
        // Easy keeps more givens so not every easy puzzle is minimal.
        let minGivens = difficulty == .easy ? 36 : 0
        for _ in 0..<maxAttempts {
            // Every Jigsaw puzzle gets its own regions. Some admit no solution at all, so the search may give up on them.
            let isJigsaw = variant.id == Variant.jigsaw.id
            let layout = isJigsaw ? variant.with(regions: JigsawRegions.make(using: &rng)) : variant
            guard let solution = Solver.randomSolution(in: layout, using: &rng, maxNodes: isJigsaw ? 30_000 : .max) else { continue }
            var givens = solution
            var count = 81
            for i in (0...40).shuffled(using: &rng) {
                let pair = Set([i, 80 - i])
                guard count - pair.count >= minGivens else { break }
                var trial = givens
                for cell in pair { trial.cells[cell] = 0 }
                if Solver.countSolutions(trial, in: layout, limit: 2) == 1 {
                    givens = trial
                    count -= pair.count
                }
            }
            if Grader.grade(givens, in: layout) == difficulty {
                return Puzzle(variant: layout, givens: givens, solution: solution, difficulty: difficulty)
            }
        }
        return nil
    }
}
