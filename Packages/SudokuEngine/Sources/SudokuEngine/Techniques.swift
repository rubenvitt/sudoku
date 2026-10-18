/// Lookup tables for one variant, built once per `nextStep`/`grade` call.
struct Layout {
    let variant: Variant
    let groups: [[Int]]
    let rowOf: [Int]
    let columnOf: [Int]
    let groupsOf: [UInt64]   // bit g = cell lies in groups[g]
    let isPeer: [Bool]       // [a * 81 + b]

    init(_ variant: Variant) {
        self.variant = variant
        groups = variant.groups
        precondition(groups.count <= 64, "at most 64 groups")
        var row = [Int](repeating: 0, count: 81), column = row
        for (i, line) in variant.rows.enumerated() { for c in line { row[c] = i } }
        for (i, line) in variant.columns.enumerated() { for c in line { column[c] = i } }
        rowOf = row
        columnOf = column
        var member = [UInt64](repeating: 0, count: 81)
        for (g, group) in groups.enumerated() { for c in group { member[c] |= 1 << g } }
        groupsOf = member
        var peer = [Bool](repeating: false, count: 81 * 81)
        for a in 0..<81 { for b in variant.peers(of: a) { peer[a * 81 + b] = true } }
        isPeer = peer
    }

    private static let boxNames = ["oben links", "oben in der Mitte", "oben rechts", "in der Mitte links", "in der Mitte",
                                   "in der Mitte rechts", "unten links", "unten in der Mitte", "unten rechts"]

    /// "in Zeile 4", "im Kasten oben rechts"
    func inGroup(_ g: Int) -> String { groupNames(g).in }

    /// "der Zeile 4", "des Kastens oben rechts"
    func ofGroup(_ g: Int) -> String { groupNames(g).of }

    private func groupNames(_ g: Int) -> (in: String, of: String) {
        var i = g
        for (count, name) in [(variant.rows.count, "Zeile"), (variant.columns.count, "Spalte")] {
            if i < count { return ("in \(name) \(i + 1)", "der \(name) \(i + 1)") }
            i -= count
        }
        if i < variant.regions.count {
            // Named by where its top-left cell sits, so the name never depends on region order.
            let corner = variant.regions[i].min() ?? 0
            let box = Self.boxNames[rowOf[corner] / 3 * 3 + columnOf[corner] / 3]
            return ("im Kasten \(box)", "des Kastens \(box)")
        }
        i -= variant.regions.count
        return ("in Zusatzgruppe \(i + 1)", "der Zusatzgruppe \(i + 1)")
    }

    func cellName(_ c: Int) -> String { "Zeile \(rowOf[c] + 1), Spalte \(columnOf[c] + 1)" }
}

func digitBit(_ d: Int) -> CandidateMask { 1 << (d - 1) }

func digits(_ mask: CandidateMask) -> [Int] { (1...9).filter { mask & digitBit($0) != 0 } }

/// "in Zeile 4" -> "In Zeile 4"
func sentenceStart(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }

/// "3", "3 und 7", "3, 5 und 7"
func list(_ items: [String]) -> String {
    items.count < 2 ? items.joined() : items.dropLast().joined(separator: ", ") + " und " + items.last!
}

func combinations(_ items: [Int], _ k: Int) -> [[Int]] {
    if k == 0 { return [[]] }
    guard items.count >= k else { return [] }
    let rest = Array(items.dropFirst())
    return combinations(rest, k - 1).map { [items[0]] + $0 } + combinations(rest, k)
}

extension Board {
    private func isOpen(_ c: Int) -> Bool { cells[c] == 0 }

    /// Every (cell, digit) in `targets` that is still an open candidate.
    private func removable(_ targets: [Int], _ mask: CandidateMask) -> [(cell: Int, digit: Int)] {
        targets.filter(isOpen).flatMap { c in digits(cand[c] & mask).map { (cell: c, digit: $0) } }
    }

    func nakedSingle() -> Step? {
        guard let c = (0..<81).first(where: { isOpen($0) && cand[$0].nonzeroBitCount == 1 }) else { return nil }
        let d = digits(cand[c])[0]
        return Step(technique: .nakedSingle, placement: (c, d), eliminations: [], focus: [c],
                    explanation: "In \(layout.cellName(c)) ist nur noch die \(d) möglich.")
    }

    func hiddenSingle() -> Step? {
        for (g, group) in layout.groups.enumerated() {
            var once: CandidateMask = 0, twice: CandidateMask = 0, placed: CandidateMask = 0
            for c in group {
                if isOpen(c) { twice |= once & cand[c]; once |= cand[c] } else { placed |= digitBit(Int(cells[c])) }
            }
            guard let d = digits(once & ~twice & ~placed).first,
                  let c = group.first(where: { isOpen($0) && cand[$0] & digitBit(d) != 0 }) else { continue }
            let rows = layout.variant.rows.count, columns = layout.variant.columns.count
            let place = g < rows ? "Spalte \(layout.columnOf[c] + 1)"
                : g < rows + columns ? "Zeile \(layout.rowOf[c] + 1)"
                : layout.cellName(c)
            return Step(technique: .hiddenSingle, placement: (c, d), eliminations: [], focus: [c],
                        explanation: "\(sentenceStart(layout.inGroup(g))) passt die \(d) nur noch in \(place).")
        }
        return nil
    }

    /// Pointing and box/line reduction alike: all d of group A lie in group B, so d leaves B∖A.
    func intersection() -> Step? {
        for (a, groupA) in layout.groups.enumerated() {
            for d in 1...9 {
                let positions = groupA.filter { isOpen($0) && cand[$0] & digitBit(d) != 0 }
                guard positions.count >= 2 else { continue }
                var shared = positions.reduce(~UInt64(0)) { $0 & layout.groupsOf[$1] } & ~(1 << a)
                while shared != 0 {
                    let b = shared.trailingZeroBitCount
                    shared &= shared - 1
                    let outside = layout.groups[b].filter { layout.groupsOf[$0] & 1 << a == 0 }
                    let eliminations = removable(outside, digitBit(d))
                    guard !eliminations.isEmpty else { continue }
                    return Step(technique: .intersection, placement: nil, eliminations: eliminations, focus: positions,
                                explanation: "\(sentenceStart(layout.inGroup(a))) steht die \(d) nur \(layout.inGroup(b)), "
                                    + "also fällt die \(d) im Rest \(layout.ofGroup(b)) weg.")
                }
            }
        }
        return nil
    }

    func nakedSubset(size: Int, _ technique: Technique) -> Step? {
        for (g, group) in layout.groups.enumerated() {
            let small = group.filter { isOpen($0) && (2...size).contains(cand[$0].nonzeroBitCount) }
            for subset in combinations(small, size) {
                let union = subset.reduce(CandidateMask(0)) { $0 | cand[$1] }
                guard union.nonzeroBitCount == size else { continue }
                let eliminations = removable(group.filter { !subset.contains($0) }, union)
                guard !eliminations.isEmpty else { continue }
                let shared = digits(union)
                return Step(technique: technique, placement: nil, eliminations: eliminations, focus: subset,
                            explanation: "\(sentenceStart(layout.inGroup(g))) bleiben für die \(size == 2 ? "zwei" : "drei") markierten Felder "
                                + "nur \(list(shared.map { "die \($0)" })), also fallen \(list(shared.map(String.init))) "
                                + "in den übrigen Feldern \(layout.ofGroup(g)) weg.")
            }
        }
        return nil
    }

    func hiddenPair() -> Step? {
        for (g, group) in layout.groups.enumerated() {
            var positions = [UInt16](repeating: 0, count: 10)
            for (i, c) in group.enumerated() where isOpen(c) {
                for d in digits(cand[c]) { positions[d] |= 1 << i }
            }
            for d1 in 1...8 where positions[d1].nonzeroBitCount == 2 {
                for d2 in (d1 + 1)...9 where positions[d2] == positions[d1] {
                    let pair = group.indices.filter { positions[d1] & 1 << $0 != 0 }.map { group[$0] }
                    let eliminations = removable(pair, ~(digitBit(d1) | digitBit(d2)) & 0x1FF)
                    guard !eliminations.isEmpty else { continue }
                    return Step(technique: .hiddenPair, placement: nil, eliminations: eliminations, focus: pair,
                                explanation: "\(sentenceStart(layout.inGroup(g))) passen die \(d1) und die \(d2) nur in die zwei "
                                    + "markierten Felder, also fallen dort alle anderen Ziffern weg.")
                }
            }
        }
        return nil
    }

    /// X-Wing (size 2) and Swordfish (size 3), rows as base and columns as cover and vice versa.
    func fish(size: Int, _ technique: Technique) -> Step? {
        let orientations = [(layout.variant.rows, layout.variant.columns, layout.rowOf, layout.columnOf, "Zeilen", "Spalten"),
                            (layout.variant.columns, layout.variant.rows, layout.columnOf, layout.rowOf, "Spalten", "Zeilen")]
        for d in 1...9 {
            let bit = digitBit(d)
            for (bases, covers, baseOf, coverOf, baseName, coverName) in orientations {
                var coverMask = [UInt16](repeating: 0, count: bases.count)
                for (i, line) in bases.enumerated() {
                    for c in line where isOpen(c) && cand[c] & bit != 0 { coverMask[i] |= 1 << coverOf[c] }
                }
                let candidatesLines = bases.indices.filter { (2...size).contains(coverMask[$0].nonzeroBitCount) }
                for baseSet in combinations(candidatesLines, size) {
                    let union = baseSet.reduce(UInt16(0)) { $0 | coverMask[$1] }
                    guard union.nonzeroBitCount == size else { continue }
                    let coverSet = covers.indices.filter { union & 1 << $0 != 0 }
                    let outside = coverSet.flatMap { covers[$0] }.filter { !baseSet.contains(baseOf[$0]) }
                    let eliminations = removable(outside, bit)
                    guard !eliminations.isEmpty else { continue }
                    let focus = baseSet.flatMap { bases[$0] }.filter { isOpen($0) && cand[$0] & bit != 0 }
                    return Step(technique: technique, placement: nil, eliminations: eliminations, focus: focus,
                                explanation: "In den \(baseName) \(list(baseSet.map { String($0 + 1) })) passt die \(d) nur in die "
                                    + "\(coverName) \(list(coverSet.map { String($0 + 1) })), also fällt die \(d) im Rest dieser \(coverName) weg.")
                }
            }
        }
        return nil
    }

    /// Pivot {x,y} sees pincers {x,z} and {y,z}: z leaves every cell seeing both pincers.
    func xyWing() -> Step? {
        for pivot in 0..<81 where isOpen(pivot) && cand[pivot].nonzeroBitCount == 2 {
            let p = cand[pivot]
            let pincers = layout.variant.peers(of: pivot).filter {
                isOpen($0) && cand[$0].nonzeroBitCount == 2 && (cand[$0] & p).nonzeroBitCount == 1
            }
            for a in pincers {
                let z = cand[a] & ~p
                for b in pincers where cand[b] & ~p == z && cand[b] & p != cand[a] & p {
                    let seeingBoth = (0..<81).filter {
                        $0 != a && $0 != b && layout.isPeer[$0 * 81 + a] && layout.isPeer[$0 * 81 + b]
                    }
                    let eliminations = removable(seeingBoth, z)
                    guard !eliminations.isEmpty else { continue }
                    let x = digits(cand[a] & p)[0], y = digits(cand[b] & p)[0], zDigit = digits(z)[0]
                    return Step(technique: .xyWing, placement: nil, eliminations: eliminations, focus: [pivot, a, b],
                                explanation: "\(layout.cellName(pivot)) ist \(x) oder \(y), und so oder so wird eines der anderen "
                                    + "markierten Felder zur \(zDigit), also fällt die \(zDigit) in allen Feldern weg, die beide sehen.")
                }
            }
        }
        return nil
    }
}
