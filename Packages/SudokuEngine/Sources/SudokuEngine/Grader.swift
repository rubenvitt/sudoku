public enum Difficulty: String, Codable, CaseIterable, Sendable {
    case easy, medium, hard, expert

    public var title: String {
        switch self {
        case .easy: "Leicht"
        case .medium: "Mittel"
        case .hard: "Schwer"
        case .expert: "Experte"
        }
    }
}

public enum Technique: Int, Comparable, CaseIterable, Sendable {
    case nakedSingle, hiddenSingle, intersection, nakedPair, hiddenPair, nakedTriple, xWing, swordfish, xyWing

    public var title: String {
        switch self {
        case .nakedSingle: "Nackter Einer"
        case .hiddenSingle: "Versteckter Einer"
        case .intersection: "Reihe-Kasten-Check"
        case .nakedPair: "Nacktes Paar"
        case .hiddenPair: "Verstecktes Paar"
        case .nakedTriple: "Nacktes Tripel"
        case .xWing: "X-Wing"
        case .swordfish: "Schwertfisch"
        case .xyWing: "XY-Wing"
        }
    }

    public static func < (a: Technique, b: Technique) -> Bool { a.rawValue < b.rawValue }

    public var difficulty: Difficulty {
        switch self {
        case .nakedSingle, .hiddenSingle: .easy
        case .intersection: .medium
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
    public let explanation: String
}

public enum Grader {
    /// First applicable technique in enum order; `candidates` may be reduced by the caller.
    public static func nextStep(_ grid: Grid, candidates: [CandidateMask], in variant: Variant) -> Step? {
        Board(layout: Layout(variant), cells: grid.cells, cand: candidates).nextStep()
    }

    /// nil = not solvable without guessing.
    public static func grade(_ puzzle: Grid, in variant: Variant) -> Difficulty? {
        var board = Board(puzzle, in: variant)
        var hardest = Technique.nakedSingle
        while board.cells.contains(0) {
            guard let step = board.nextStep() else { return nil }
            hardest = max(hardest, step.technique)
            board.apply(step)
        }
        return hardest.difficulty
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
        nakedSingle() ?? hiddenSingle() ?? intersection()
            ?? nakedSubset(size: 2, .nakedPair) ?? hiddenPair() ?? nakedSubset(size: 3, .nakedTriple)
            ?? fish(size: 2, .xWing) ?? fish(size: 3, .swordfish) ?? xyWing()
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
