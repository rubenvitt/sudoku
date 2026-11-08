public enum Difficulty: String, Codable, CaseIterable, Sendable {
    case easy, medium, hard, expert

    public var title: String { title(language: nil) }

    /// `language` forces a language, e.g. "de"; nil follows the app.
    public func title(language: String?) -> String {
        switch self {
        case .easy: localized("Leicht", language)
        case .medium: localized("Mittel", language)
        case .hard: localized("Schwer", language)
        case .expert: localized("Experte", language)
        }
    }
}

public enum Technique: Int, Comparable, CaseIterable, Sendable {
    // Ordered by difficulty: grading keeps the hardest technique used, by this order.
    case nakedSingle, hiddenSingle, cageSum, thermo, kropki, intersection, rule45, nakedPair, hiddenPair, nakedTriple, xWing, swordfish, xyWing

    public var title: String { title(language: nil) }

    /// `language` forces a language, e.g. "de"; nil follows the app.
    public func title(language: String?) -> String {
        switch self {
        case .nakedSingle: localized("Nackter Einer", language)
        case .hiddenSingle: localized("Versteckter Einer", language)
        case .cageSum: localized("Käfigsumme", language)
        case .thermo: localized("Thermometer", language)
        case .kropki: localized("Kropki-Punkt", language)
        case .rule45: localized("45er-Regel", language)
        case .intersection: localized("Reihe-Kasten-Check", language)
        case .nakedPair: localized("Nacktes Paar", language)
        case .hiddenPair: localized("Verstecktes Paar", language)
        case .nakedTriple: localized("Nacktes Tripel", language)
        case .xWing: localized("X-Wing", language)
        case .swordfish: localized("Schwertfisch", language)
        case .xyWing: localized("XY-Wing", language)
        }
    }

    public static func < (a: Technique, b: Technique) -> Bool { a.rawValue < b.rawValue }

    public var difficulty: Difficulty {
        switch self {
        case .nakedSingle, .hiddenSingle, .cageSum, .thermo, .kropki: .easy
        case .intersection, .rule45: .medium
        case .nakedPair, .hiddenPair, .nakedTriple: .hard
        case .xWing, .swordfish, .xyWing: .expert
        }
    }
}

public struct Step: Sendable {
    public let technique: Technique
    public let placement: (cell: Int, digit: Int)?
    public let eliminations: [(cell: Int, digit: Int)]
    public let focus: [Int]
    /// Built only when shown, so grading many puzzles never formats text.
    let describe: @Sendable (_ language: String?) -> String

    public var explanation: String { describe(nil) }

    /// `language` forces a language, e.g. "de"; nil follows the app.
    public func explanation(language: String?) -> String { describe(language) }
}

public enum Grader {
    /// First applicable technique in enum order; `candidates` may be reduced by the caller.
    public static func nextStep(_ grid: Grid, candidates: [CandidateMask], in variant: Variant) -> Step? {
        Board(layout: Layout(variant), cells: grid.cells, cand: candidates).nextStep()
    }

    /// nil = not solvable without guessing.
    public static func grade(_ puzzle: Grid, in variant: Variant) -> Difficulty? { solve(puzzle, in: variant).difficulty }

    /// Solves as far as the techniques reach: the difficulty (nil if they stall) and the cells filled by then.
    static func solve(_ puzzle: Grid, in variant: Variant) -> (difficulty: Difficulty?, cells: [UInt8]) {
        var board = Board(puzzle, in: variant)
        var hardest = Technique.nakedSingle
        while board.cells.contains(0) {
            guard let step = board.nextStep() else { return (nil, board.cells) }
            hardest = max(hardest, step.technique)
            board.apply(step)
        }
        return (hardest.difficulty, board.cells)
    }
}

/// Solving state: digits plus the candidates left after all applied steps.
struct Board {
    let layout: Layout
    var cells: [UInt8]
    var cand: [CandidateMask]

    init(layout: Layout, cells: [UInt8], cand: [CandidateMask]) {
        self.layout = layout
        self.cells = cells
        self.cand = cand
    }

    init(_ puzzle: Grid, in variant: Variant) {
        self.init(layout: Layout(variant), cells: puzzle.cells, cand: candidates(for: puzzle, in: variant))
    }

    func nextStep() -> Step? {
        // In enum order; the first that applies wins. Closures keep the type checker from timing out on one long `??` chain.
        let techniques: [() -> Step?] = [
            nakedSingle, hiddenSingle, { sumRule(.cageSum) }, thermo, kropki, intersection, { sumRule(.rule45) },
            { nakedSubset(size: 2, .nakedPair) }, hiddenPair, { nakedSubset(size: 3, .nakedTriple) },
            { fish(size: 2, .xWing) }, { fish(size: 3, .swordfish) }, xyWing,
        ]
        for technique in techniques {
            if let step = technique() { return step }
        }
        return nil
    }

    mutating func apply(_ step: Step) {
        if let p = step.placement {
            let bit = digitBit(p.digit)
            cells[p.cell] = UInt8(p.digit)
            cand[p.cell] = bit
            for peer in layout.variant.peers(of: p.cell) { cand[peer] &= ~bit }
        }
        for e in step.eliminations { cand[e.cell] &= ~digitBit(e.digit) }
    }
}
