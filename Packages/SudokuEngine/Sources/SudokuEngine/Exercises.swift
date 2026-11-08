/// A practice position for one technique: the digits and candidates at the moment the grader first needed it while
/// solving a classic puzzle. The grader always takes the easiest technique that applies, so nothing easier helps here.
public struct Exercise: Codable, Hashable, Sendable {
    public let technique: Technique
    /// Digits placed so far, givens included.
    public let cells: Grid
    /// What is still possible in each cell; a filled cell holds only its digit.
    public let candidates: [CandidateMask]
    public let solution: Grid

    public init(technique: Technique, cells: Grid, candidates: [CandidateMask], solution: Grid) {
        self.technique = technique
        self.cells = cells
        self.candidates = candidates
        self.solution = solution
    }

    private enum CodingKeys: String, CodingKey { case technique, cells, candidates, solution }

    /// A corrupt save must throw, never crash later on an out-of-range index.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        technique = try c.decode(Technique.self, forKey: .technique)
        cells = try c.decode(Grid.self, forKey: .cells)
        candidates = try c.decode([CandidateMask].self, forKey: .candidates)
        solution = try c.decode(Grid.self, forKey: .solution)
        guard cells.cells.count == 81, solution.cells.count == 81, candidates.count == 81,
              (cells.cells + solution.cells).allSatisfy({ $0 <= 9 }), candidates.allSatisfy({ $0 <= 0x1FF }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Exercise has wrong sizes"))
        }
    }

    /// Every application of the technique here. Any of them solves the exercise, not just the one the grader picked.
    public var applications: [Step] { board.steps(of: technique) }

    /// The application the grader would show first; stops searching once it is found.
    public var firstApplication: Step? { board.first(technique) }

    private var board: Board { Board(layout: Layout(.classic), cells: cells.cells, cand: candidates) }

    /// The same exercise in disguise: digits renamed, rows swapped within their band and bands swapped, the same for
    /// columns, and maybe mirrored along the diagonal. Every technique works on it just as before.
    public func transformed(using rng: inout some RandomNumberGenerator) -> Exercise {
        let rename = [0] + (1...9).shuffled(using: &rng)
        func lineOrder() -> [Int] {
            (0..<3).shuffled(using: &rng).flatMap { band in (0..<3).shuffled(using: &rng).map { band * 3 + $0 } }
        }
        let rows = lineOrder(), columns = lineOrder()
        let mirrored = Bool.random(using: &rng)
        /// The old cell that lands on `cell`.
        func source(_ cell: Int) -> Int {
            let r = mirrored ? cell % 9 : cell / 9, c = mirrored ? cell / 9 : cell % 9
            return rows[r] * 9 + columns[c]
        }
        func renamed(_ grid: Grid) -> Grid {
            Grid(cells: (0..<81).map { UInt8(rename[Int(grid.cells[source($0)])]) })
        }
        let masks = (0..<81).map { cell in
            digits(candidates[source(cell)]).reduce(CandidateMask(0)) { $0 | digitBit(rename[$1]) }
        }
        return Exercise(technique: technique, cells: renamed(cells), candidates: masks, solution: renamed(solution))
    }
}

public enum Exercises {
    /// The techniques the practice room teaches, in the order it teaches them; each needs only the ones before it.
    public static let techniques: [Technique] = [
        .nakedSingle, .hiddenSingle, .intersection, .nakedPair, .hiddenPair, .nakedTriple, .xWing, .swordfish, .xyWing,
    ]

    /// Boards that need the techniques, from sudokuwiki.org (Andrew Stuart) and the Wikipedia article "Sudoku".
    /// They give each technique page its example and the first exercises, so practice starts without waiting.
    static let starterBoards = [
        "530070000600195000098000060800060003400803001700020006060000280000419005000080079",
        "000000000904607000076804100309701080008000300050308702007502610000403208000000000",
        "010903600000080000900000507002010430000402000064070200701000005000030000005601020",
        "080090030030000069902063158020804590851907046394605870563040987200000015010050020",
        "720408030080000047401076802810739000000851000000264080209680413340000008168943275",
        "001400000000070008600000100300205000500001000000000070070000240080000000000030000",
        "100000569402000008050009040000640801000010000208035000040500010900000402621000005",
        "500010003006003002003200000002300076000050000190007500000009400200800600900040005",
        "034500000802060400600008000003900004050000090900005800000300008001040605000007120",
    ]

    /// The first exercise found for each technique in `starterBoards`.
    public static let starters: [Technique: Exercise] = {
        var found: [Technique: Exercise] = [:]
        for board in starterBoards {
            let givens = Grid(board)
            guard let solution = Solver.solve(givens, in: .classic) else { continue }
            for exercise in mine(givens: givens, solution: solution) where found[exercise.technique] == nil {
                found[exercise.technique] = exercise
            }
        }
        return found
    }()

    /// One exercise for each technique the solve of a classic puzzle needs, at the first step that uses it.
    /// Singles only count before any candidate has been crossed out, so the candidates are what one sees without notes.
    public static func mine(givens: Grid, solution: Grid) -> [Exercise] {
        var board = Board(givens, in: .classic)
        var found: [Technique: Exercise] = [:]
        var crossedOut = false
        while let step = board.nextStep() {
            let technique = step.technique
            let isSingle = technique == .nakedSingle || technique == .hiddenSingle
            if found[technique] == nil, techniques.contains(technique), !(isSingle && crossedOut) {
                found[technique] = Exercise(technique: technique, cells: Grid(cells: board.cells), candidates: board.cand,
                                            solution: solution)
            }
            if step.placement == nil { crossedOut = true }
            board.apply(step)
        }
        return techniques.compactMap { found[$0] }
    }
}

/// Saved by name, so adding or reordering techniques never turns a saved exercise into another technique.
extension Technique: Codable {
    public init(from decoder: any Decoder) throws {
        let name = try decoder.singleValueContainer().decode(String.self)
        guard let technique = Technique.allCases.first(where: { "\($0)" == name }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown technique \(name)"))
        }
        self = technique
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("\(self)")
    }
}

extension Exercise {
    public enum Verdict: Sendable {
        /// Nothing wrong, not done yet.
        case going
        /// A move the technique doesn't back: a digit that isn't one of its placements, or a note crossed out (or added)
        /// that no application of it crosses out. The practice view takes it back right away.
        case wrong(cell: Int, digit: Int, isNote: Bool)
        /// One application is complete: its digit is placed, or all its notes are crossed out.
        case solved(Step)
    }

    /// Naked and hidden singles place a digit; every other technique crosses out notes.
    public var isSingle: Bool { technique == .nakedSingle || technique == .hiddenSingle }

    /// Judges the board after a move: `entries` are the digits, `notes` the candidates still marked in each cell.
    public func judge(entries: Grid, notes: [CandidateMask]) -> Verdict {
        let applications = self.applications
        let placements = Set(applications.compactMap(\.placement).map { $0.cell * 10 + $0.digit })
        var crossable = [CandidateMask](repeating: 0, count: 81)
        for step in applications { for e in step.eliminations { crossable[e.cell] |= digitBit(e.digit) } }
        for cell in 0..<81 where cells.cells[cell] == 0 {
            let digit = Int(entries.cells[cell])
            if digit != 0 {
                if !placements.contains(cell * 10 + digit) { return .wrong(cell: cell, digit: digit, isNote: false) }
                continue
            }
            // Singles are about digits; notes jotted down along the way don't count.
            guard !isSingle else { continue }
            let changed = notes[cell] ^ candidates[cell]
            if let d = digits(changed & ~crossable[cell]).first { return .wrong(cell: cell, digit: d, isNote: true) }
        }
        for step in applications {
            if let p = step.placement, Int(entries.cells[p.cell]) == p.digit { return .solved(step) }
            if step.placement == nil, step.eliminations.allSatisfy({ entries.cells[$0.cell] == 0 && notes[$0.cell] & digitBit($0.digit) == 0 }) {
                return .solved(step)
            }
        }
        return .going
    }

    /// A game on this exercise: its digits as givens, its candidates as notes (none for the singles, which start
    /// from a bare board as in a game).
    public var game: Game {
        let puzzle = Puzzle(variant: .classic, givens: cells, solution: solution, difficulty: technique.difficulty)
        let notes = isSingle ? [CandidateMask](repeating: 0, count: 81)
            : (0..<81).map { cells.cells[$0] == 0 ? candidates[$0] : 0 }
        return Game(puzzle: puzzle, notes: notes)
    }
}
