public enum Solver {
    public static func countSolutions(_ grid: Grid, in variant: Variant, limit: Int) -> Int {
        var search = Search(grid, variant, limit: limit)
        var rng = SplitMix64(seed: 0)
        search.run(shuffle: false, using: &rng)
        return search.found
    }

    public static func solve(_ grid: Grid, in variant: Variant) -> Grid? {
        var search = Search(grid, variant, limit: 1)
        var rng = SplitMix64(seed: 0)
        search.run(shuffle: false, using: &rng)
        return search.first
    }

    public static func randomSolution(in variant: Variant, using rng: inout some RandomNumberGenerator) -> Grid {
        var search = Search(Grid(cells: [UInt8](repeating: 0, count: 81)), variant, limit: 1)
        search.run(shuffle: true, using: &rng)
        return search.first!
    }
}

private struct Search {
    let limit: Int
    var cells: [UInt8]
    var found = 0
    var first: Grid?
    private let cellGroups: [[Int]]
    private var used: [CandidateMask]   // per group
    private var valid = true

    init(_ grid: Grid, _ variant: Variant, limit: Int) {
        self.limit = limit
        cells = grid.cells
        let groups = variant.groups
        var membership = [[Int]](repeating: [], count: 81)
        for (g, group) in groups.enumerated() { for c in group { membership[c].append(g) } }
        cellGroups = membership
        used = [CandidateMask](repeating: 0, count: groups.count)
        for cell in 0..<81 where cells[cell] != 0 {
            let bit: CandidateMask = 1 << (cells[cell] - 1)
            if mask(cell) & bit == 0 { valid = false }
            for g in cellGroups[cell] { used[g] |= bit }
        }
    }

    private func mask(_ cell: Int) -> CandidateMask {
        // candidates = digits unused in every group containing the cell
        ~cellGroups[cell].reduce(CandidateMask(0)) { $0 | used[$1] } & 0x1FF
    }

    mutating func run(shuffle: Bool, using rng: inout some RandomNumberGenerator) {
        guard valid else { return }
        descend(shuffle: shuffle, using: &rng)
    }

    private mutating func descend(shuffle: Bool, using rng: inout some RandomNumberGenerator) {
        var best = -1, bestMask: CandidateMask = 0, bestCount = 10
        for cell in 0..<81 where cells[cell] == 0 {
            let m = mask(cell)
            let n = m.nonzeroBitCount
            if n < bestCount {
                best = cell; bestMask = m; bestCount = n
                if n <= 1 { break }
            }
        }
        if best < 0 {
            found += 1
            if first == nil { first = Grid(cells: cells) }
            return
        }
        var digits = (1...9).filter { bestMask & 1 << ($0 - 1) != 0 }
        if shuffle { digits.shuffle(using: &rng) }
        for d in digits {
            let bit: CandidateMask = 1 << (d - 1)
            cells[best] = UInt8(d)
            for g in cellGroups[best] { used[g] |= bit }
            descend(shuffle: shuffle, using: &rng)
            for g in cellGroups[best] { used[g] &= ~bit }
            cells[best] = 0
            if found >= limit { return }
        }
    }
}
