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
        randomSolution(in: variant, using: &rng, maxNodes: .max)!
    }

    /// nil when the search gives up after `maxNodes` placements: some Jigsaw regions have no solution,
    /// and proving that can take far longer than trying other regions.
    static func randomSolution(in variant: Variant, using rng: inout some RandomNumberGenerator, maxNodes: Int) -> Grid? {
        var search = Search(Grid(cells: [UInt8](repeating: 0, count: 81)), variant, limit: 1, maxNodes: maxNodes)
        search.run(shuffle: true, using: &rng)
        return search.first
    }
}

/// Digit sets by size and sum: `combinations[k][s]` holds every mask of k distinct digits adding up to s.
let digitCombinations: [[[CandidateMask]]] = {
    var table = [[[CandidateMask]]](repeating: [[CandidateMask]](repeating: [], count: 46), count: 10)
    for mask in CandidateMask(0)..<512 {
        let sum = (1...9).filter { mask & 1 << ($0 - 1) != 0 }.reduce(0, +)
        table[mask.nonzeroBitCount][sum].append(mask)
    }
    return table
}()

/// Whether `count` distinct digits from `available` can add up to `sum`.
func canMake(_ sum: Int, count: Int, from available: CandidateMask) -> Bool {
    guard count >= 0, count <= 9, sum >= 0, sum <= 45 else { return false }
    return digitCombinations[count][sum].contains { $0 & ~available == 0 }
}

/// Per cell: every cell a thermometer or dot ties it to, with the digits that fit here for each digit there (index 1…9).
func relationLinks(_ variant: Variant) -> [[(other: Int, fits: [CandidateMask])]] {
    var links = [[(other: Int, fits: [CandidateMask])]](repeating: [], count: 81)
    func table(_ fits: (Int, Int) -> Bool) -> [CandidateMask] {
        (0...9).map { there in (1...9).filter { fits($0, there) }.reduce(CandidateMask(0)) { $0 | 1 << ($1 - 1) } }
    }
    for thermo in variant.thermos {
        for (low, high) in zip(thermo, thermo.dropFirst()) {
            links[low].append((other: high, fits: table { here, there in here < there }))
            links[high].append((other: low, fits: table { here, there in here > there }))
        }
    }
    for dot in variant.dots {
        let fits = table(dot.allows)
        links[dot.cells[0]].append((other: dot.cells[1], fits: fits))
        links[dot.cells[1]].append((other: dot.cells[0], fits: fits))
    }
    return links
}

/// Per cell: the digits its place on a thermometer leaves room for. The third cell of five holds at least 3 and at most 7.
func thermoBounds(_ variant: Variant) -> [CandidateMask] {
    var bounds = [CandidateMask](repeating: 0x1FF, count: 81)
    for thermo in variant.thermos {
        for (i, cell) in thermo.enumerated() {
            let low = i + 1, high = 9 - (thermo.count - 1 - i)
            bounds[cell] = low <= high ? (low...high).reduce(CandidateMask(0)) { $0 | 1 << ($1 - 1) } : 0
        }
    }
    return bounds
}

private struct Search {
    let limit: Int
    let maxNodes: Int
    var nodes = 0
    var cells: [UInt8]
    var found = 0
    var first: Grid?
    private let cellGroups: [[Int]]
    private var used: [CandidateMask]   // per group
    private let cageOf: [Int]           // -1 = no cage
    private let cageSum: [Int]
    private var cageUsed: [CandidateMask]
    private var cageTotal: [Int]
    private var cageOpen: [Int]
    /// Thermometers and dots as pairs: `links[cell]` lists each other cell with, per digit there, the digits that fit here.
    private let links: [[(other: Int, fits: [CandidateMask])]]
    /// Digits a thermometer leaves room for at the cell's place on it.
    private let bounds: [CandidateMask]
    private var valid = true

    init(_ grid: Grid, _ variant: Variant, limit: Int, maxNodes: Int = .max) {
        self.limit = limit
        self.maxNodes = maxNodes
        cells = grid.cells
        let groups = variant.groups
        var membership = [[Int]](repeating: [], count: 81)
        for (g, group) in groups.enumerated() { for c in group { membership[c].append(g) } }
        cellGroups = membership
        used = [CandidateMask](repeating: 0, count: groups.count)
        var cage = [Int](repeating: -1, count: 81)
        for (k, c) in variant.cages.enumerated() { for cell in c.cells { cage[cell] = k } }
        cageOf = cage
        cageSum = variant.cages.map(\.sum)
        cageUsed = [CandidateMask](repeating: 0, count: variant.cages.count)
        cageTotal = [Int](repeating: 0, count: variant.cages.count)
        cageOpen = variant.cages.map(\.cells.count)
        links = relationLinks(variant)
        bounds = thermoBounds(variant)
        for cell in 0..<81 where cells[cell] != 0 {
            let bit: CandidateMask = 1 << (cells[cell] - 1)
            if groupMask(cell) & bit == 0 || relationMask(cell) & bit == 0 { valid = false }
            for g in cellGroups[cell] { used[g] |= bit }
            let k = cageOf[cell]
            if k >= 0 {
                if cageUsed[k] & bit != 0 { valid = false }
                cageUsed[k] |= bit
                cageTotal[k] += Int(cells[cell])
                cageOpen[k] -= 1
            }
        }
        for k in cageSum.indices where !canMake(cageSum[k] - cageTotal[k], count: cageOpen[k], from: ~cageUsed[k] & 0x1FF) {
            valid = false
        }
    }

    private func groupMask(_ cell: Int) -> CandidateMask {
        // candidates = digits unused in every group containing the cell
        ~cellGroups[cell].reduce(CandidateMask(0)) { $0 | used[$1] } & 0x1FF
    }

    /// Digits that fit the thermometers and dots, given the digits placed in the linked cells.
    private func relationMask(_ cell: Int) -> CandidateMask {
        var m = bounds[cell]
        for link in links[cell] where cells[link.other] != 0 { m &= link.fits[Int(cells[link.other])] }
        return m
    }

    /// Group candidates, minus digits that break a thermometer or dot or leave the cell's cage unable to reach its sum.
    private func mask(_ cell: Int) -> CandidateMask {
        let m = groupMask(cell) & relationMask(cell)
        let k = cageOf[cell]
        guard k >= 0 else { return m }
        let free = ~cageUsed[k] & 0x1FF
        let rest = cageSum[k] - cageTotal[k]
        var result: CandidateMask = 0
        for d in 1...9 where m & free & 1 << (d - 1) != 0 {
            let bit: CandidateMask = 1 << (d - 1)
            if canMake(rest - d, count: cageOpen[k] - 1, from: free & ~bit) { result |= bit }
        }
        return result
    }

    mutating func run(shuffle: Bool, using rng: inout some RandomNumberGenerator) {
        guard valid else { return }
        descend(shuffle: shuffle, using: &rng)
    }

    private mutating func descend(shuffle: Bool, using rng: inout some RandomNumberGenerator) {
        nodes += 1
        guard nodes <= maxNodes else { return }
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
        let k = cageOf[best]
        for d in digits {
            let bit: CandidateMask = 1 << (d - 1)
            cells[best] = UInt8(d)
            for g in cellGroups[best] { used[g] |= bit }
            if k >= 0 { cageUsed[k] |= bit; cageTotal[k] += d; cageOpen[k] -= 1 }
            descend(shuffle: shuffle, using: &rng)
            if k >= 0 { cageUsed[k] &= ~bit; cageTotal[k] -= d; cageOpen[k] += 1 }
            for g in cellGroups[best] { used[g] &= ~bit }
            cells[best] = 0
            if found >= limit || nodes > maxNodes { return }
        }
    }
}
