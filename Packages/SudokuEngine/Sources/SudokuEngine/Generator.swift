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
        guard variant.difficulties.contains(difficulty) else { return nil }
        // Easy keeps more givens so not every easy puzzle is minimal.
        let minGivens = difficulty == .easy ? 36 : 0
        // Jigsaw puzzles get their own regions. Some admit no solution at all, so the search gives up on them early;
        // regions that work serve a few attempts, since finding them costs more than one attempt.
        let isJigsaw = variant.id == Variant.jigsaw.id
        // Thermometers and dots are laid over a finished solution, so it comes first.
        let isOverSolution = variant.id == Variant.thermo.id || variant.id == Variant.kropki.id
        var layout = variant
        var attemptsLeftOnLayout = 0
        for _ in 0..<maxAttempts {
            if isJigsaw && attemptsLeftOnLayout == 0 {
                layout = variant.with(regions: JigsawRegions.make(using: &rng))
                attemptsLeftOnLayout = 8
            }
            attemptsLeftOnLayout -= 1
            guard let solution = Solver.randomSolution(in: isOverSolution ? .classic : layout, using: &rng,
                                                       maxNodes: isJigsaw ? 30_000 : .max) else {
                attemptsLeftOnLayout = 0
                continue
            }
            if variant.id == Variant.thermo.id {
                layout = variant.with(thermos: Thermometers.make(over: solution, using: &rng))
            } else if variant.id == Variant.kropki.id {
                layout = variant.with(dots: KropkiDots.make(over: solution, using: &rng))
            }
            var givens = solution
            var count = 81
            for i in (0...40).shuffled(using: &rng) {
                let pair = Set([i, 80 - i])
                guard count - pair.count >= minGivens else { break }
                var trial = givens
                for cell in pair { trial.cells[cell] = 0 }
                // Jigsaw, Thermo and Kropki keep only puzzles the techniques solve, which proves them unique too: removal
                // down to a bare unique grid would leave most of them needing guesses, and counting solutions takes long there.
                let keeps = isJigsaw || isOverSolution
                    ? Grader.solve(trial, in: layout).difficulty != nil
                    : Solver.countSolutions(trial, in: layout, limit: 2) == 1
                if keeps {
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
