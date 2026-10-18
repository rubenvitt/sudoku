import Foundation

public enum Hint: Sendable {
    /// 1-based row of the first wrong entry.
    case wrongEntry(row: Int)
    case step(Step)
}

public struct Game: Codable, Sendable {
    private struct Snapshot: Codable, Sendable {
        var entries: Grid
        var notes: [CandidateMask]
    }

    public let puzzle: Puzzle
    public private(set) var entries: Grid
    public private(set) var notes: [CandidateMask]
    public private(set) var errorMarks: Set<Int> = []
    public var elapsed: TimeInterval = 0
    public private(set) var hintsUsed = 0
    public private(set) var checksUsed = 0
    public private(set) var errorsFound = 0
    /// Candidates already ruled out by shown hints; kept outside the undo history so repeated hints advance.
    public private(set) var hintEliminations = [CandidateMask](repeating: 0, count: 81)
    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []

    private enum CodingKeys: String, CodingKey {
        case puzzle, entries, notes, errorMarks, elapsed, hintsUsed, checksUsed, errorsFound
        case hintEliminations, undoStack, redoStack
    }

    /// A corrupt save must throw, never crash later on an out-of-range index.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        puzzle = try c.decode(Puzzle.self, forKey: .puzzle)
        entries = try c.decode(Grid.self, forKey: .entries)
        notes = try c.decode([CandidateMask].self, forKey: .notes)
        errorMarks = try c.decode(Set<Int>.self, forKey: .errorMarks)
        elapsed = try c.decode(TimeInterval.self, forKey: .elapsed)
        hintsUsed = try c.decode(Int.self, forKey: .hintsUsed)
        checksUsed = try c.decode(Int.self, forKey: .checksUsed)
        errorsFound = try c.decode(Int.self, forKey: .errorsFound)
        hintEliminations = try c.decode([CandidateMask].self, forKey: .hintEliminations)
        undoStack = try c.decode([Snapshot].self, forKey: .undoStack)
        redoStack = try c.decode([Snapshot].self, forKey: .redoStack)
        let snapshots = undoStack + redoStack
        let sizesOK = [puzzle.givens.cells.count, puzzle.solution.cells.count, entries.cells.count,
                       notes.count, hintEliminations.count].allSatisfy { $0 == 81 }
            && snapshots.allSatisfy { $0.entries.cells.count == 81 && $0.notes.count == 81 }
            && errorMarks.allSatisfy { (0..<81).contains($0) }
        guard sizesOK else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Game state has wrong sizes"))
        }
    }

    public init(puzzle: Puzzle) {
        self.puzzle = puzzle
        entries = puzzle.givens
        notes = [CandidateMask](repeating: 0, count: 81)
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var isFull: Bool { entries.isComplete }
    public var isSolved: Bool { entries == puzzle.solution }

    private func isGiven(_ cell: Int) -> Bool { puzzle.givens.cells[cell] != 0 }

    /// Runs `change`, recording an undo snapshot only if something actually changed.
    private mutating func edit(_ cell: Int, _ change: (inout Game) -> Void) {
        guard !isGiven(cell) else { return }
        let before = Snapshot(entries: entries, notes: notes)
        change(&self)
        guard entries != before.entries || notes != before.notes else { return }
        errorMarks.remove(cell)
        undoStack.append(before)
        redoStack.removeAll()
    }

    public mutating func setDigit(_ d: Int, at cell: Int) {
        edit(cell) { g in
            if g.entries.cells[cell] == UInt8(d) {
                g.entries.cells[cell] = 0
            } else {
                g.entries.cells[cell] = UInt8(d)
                g.notes[cell] = 0
                for peer in g.puzzle.variant.peers(of: cell) { g.notes[peer] &= ~digitBit(d) }
            }
        }
    }

    public mutating func toggleNote(_ d: Int, at cell: Int) {
        edit(cell) { g in
            guard g.entries.cells[cell] == 0 else { return }
            g.notes[cell] ^= digitBit(d)
        }
    }

    public mutating func clear(_ cell: Int) {
        edit(cell) { g in
            g.entries.cells[cell] = 0
            g.notes[cell] = 0
        }
    }

    public mutating func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(Snapshot(entries: entries, notes: notes))
        restore(previous)
    }

    public mutating func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(Snapshot(entries: entries, notes: notes))
        restore(next)
    }

    private mutating func restore(_ s: Snapshot) {
        for cell in 0..<81 where entries.cells[cell] != s.entries.cells[cell] || notes[cell] != s.notes[cell] {
            errorMarks.remove(cell)
        }
        entries = s.entries
        notes = s.notes
    }

    private var wrongCells: [Int] {
        (0..<81).filter { !isGiven($0) && entries.cells[$0] != 0 && entries.cells[$0] != puzzle.solution.cells[$0] }
    }

    /// Marks wrong entries without counting a check — for the automatic marking of a full grid.
    public mutating func markErrors() {
        errorMarks = Set(wrongCells)
    }

    public mutating func check() -> Set<Int> {
        markErrors()
        checksUsed += 1
        errorsFound += errorMarks.count
        return errorMarks
    }

    public mutating func hint() -> Hint? {
        guard !isSolved else { return nil }
        if let first = wrongCells.first {
            hintsUsed += 1
            return .wrongEntry(row: first / 9 + 1)
        }
        let masks = candidates(for: entries, in: puzzle.variant).enumerated().map { $0.element & ~hintEliminations[$0.offset] }
        guard let step = Grader.nextStep(entries, candidates: masks, in: puzzle.variant) else { return nil }
        for e in step.eliminations { hintEliminations[e.cell] |= digitBit(e.digit) }
        hintsUsed += 1
        return .step(step)
    }
}
