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

    private static func boxName(_ position: Int, _ language: String?) -> String {
        switch position {
        case 0: localized("oben links", language)
        case 1: localized("oben in der Mitte", language)
        case 2: localized("oben rechts", language)
        case 3: localized("in der Mitte links", language)
        case 4: localized("in der Mitte", language)
        case 5: localized("in der Mitte rechts", language)
        case 6: localized("unten links", language)
        case 7: localized("unten in der Mitte", language)
        default: localized("unten rechts", language)
        }
    }

    /// "in Zeile 4", "im Kasten oben rechts"
    func inGroup(_ g: Int, _ language: String?) -> String {
        switch kind(of: g) {
        case let .row(n): localized("in Zeile \(n)", language)
        case let .column(n): localized("in Spalte \(n)", language)
        case let .box(position): localized("im Kasten \(Self.boxName(position, language))", language)
        case let .extra(n): localized("in Zusatzgruppe \(n)", language)
        }
    }

    /// "der Zeile 4", "des Kastens oben rechts"
    func ofGroup(_ g: Int, _ language: String?) -> String {
        switch kind(of: g) {
        case let .row(n): localized("der Zeile \(n)", language)
        case let .column(n): localized("der Spalte \(n)", language)
        case let .box(position): localized("des Kastens \(Self.boxName(position, language))", language)
        case let .extra(n): localized("der Zusatzgruppe \(n)", language)
        }
    }

    /// Rows, columns and extra groups count from 1; a box is named by its position 0…8 on the board.
    private enum GroupKind { case row(Int), column(Int), box(Int), extra(Int) }

    private func kind(of g: Int) -> GroupKind {
        var i = g
        if i < variant.rows.count { return .row(i + 1) }
        i -= variant.rows.count
        if i < variant.columns.count { return .column(i + 1) }
        i -= variant.columns.count
        if i < variant.regions.count {
            // Named by where its top-left cell sits, so the name never depends on region order.
            let corner = variant.regions[i].min() ?? 0
            return .box(rowOf[corner] / 3 * 3 + columnOf[corner] / 3)
        }
        return .extra(i - variant.regions.count + 1)
    }

    func cellName(_ c: Int, _ language: String?) -> String {
        localized("Zeile \(rowOf[c] + 1), Spalte \(columnOf[c] + 1)", language)
    }
}

func digitBit(_ d: Int) -> CandidateMask { 1 << (d - 1) }

func digits(_ mask: CandidateMask) -> [Int] { (1...9).filter { mask & digitBit($0) != 0 } }

/// "in Zeile 4" -> "In Zeile 4"
func sentenceStart(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }

/// "3", "3 und 7", "3, 5 und 7"
func list(_ items: [String], _ language: String?) -> String {
    guard let last = items.last, items.count > 1 else { return items.joined() }
    let head = items.dropLast().joined(separator: ", ")
    return localized("\(head) und \(last)", language)
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
        return Step(technique: .nakedSingle, placement: (c, d), eliminations: [], focus: [c]) { [layout] language in
            localized("In \(layout.cellName(c, language)) ist nur noch die \(d) möglich.", language)
        }
    }

    func hiddenSingle() -> Step? {
        for (g, group) in layout.groups.enumerated() {
            var once: CandidateMask = 0, twice: CandidateMask = 0, placed: CandidateMask = 0
            for c in group {
                if isOpen(c) { twice |= once & cand[c]; once |= cand[c] } else { placed |= digitBit(Int(cells[c])) }
            }
            guard let d = digits(once & ~twice & ~placed).first,
                  let c = group.first(where: { isOpen($0) && cand[$0] & digitBit(d) != 0 }) else { continue }
            return Step(technique: .hiddenSingle, placement: (c, d), eliminations: [], focus: [c]) { [layout] language in
                let rows = layout.variant.rows.count, columns = layout.variant.columns.count
                let place = g < rows ? localized("Spalte \(layout.columnOf[c] + 1)", language)
                    : g < rows + columns ? localized("Zeile \(layout.rowOf[c] + 1)", language)
                    : layout.cellName(c, language)
                return localized("\(sentenceStart(layout.inGroup(g, language))) passt die \(d) nur noch in \(place).", language)
            }
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
                    return Step(technique: .intersection, placement: nil, eliminations: eliminations, focus: positions) { [layout] language in
                        localized("""
                            \(sentenceStart(layout.inGroup(a, language))) steht die \(d) nur \(layout.inGroup(b, language)), \
                            also fällt die \(d) im Rest \(layout.ofGroup(b, language)) weg.
                            """, language)
                    }
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
                return Step(technique: technique, placement: nil, eliminations: eliminations, focus: subset) { [layout] language in
                    let group = sentenceStart(layout.inGroup(g, language)), rest = layout.ofGroup(g, language)
                    let options = list(shared.map { localized("die \($0)", language) }, language)
                    let removed = list(shared.map(String.init), language)
                    return size == 2
                        ? localized("""
                            \(group) bleiben für die zwei markierten Felder nur \(options), \
                            also fallen \(removed) in den übrigen Feldern \(rest) weg.
                            """, language)
                        : localized("""
                            \(group) bleiben für die drei markierten Felder nur \(options), \
                            also fallen \(removed) in den übrigen Feldern \(rest) weg.
                            """, language)
                }
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
                    return Step(technique: .hiddenPair, placement: nil, eliminations: eliminations, focus: pair) { [layout] language in
                        localized("""
                            \(sentenceStart(layout.inGroup(g, language))) passen die \(d1) und die \(d2) nur in die zwei \
                            markierten Felder, also fallen dort alle anderen Ziffern weg.
                            """, language)
                    }
                }
            }
        }
        return nil
    }

    /// X-Wing (size 2) and Swordfish (size 3), rows as base and columns as cover and vice versa.
    func fish(size: Int, _ technique: Technique) -> Step? {
        let orientations = [(layout.variant.rows, layout.variant.columns, layout.rowOf, layout.columnOf, true),
                            (layout.variant.columns, layout.variant.rows, layout.columnOf, layout.rowOf, false)]
        for d in 1...9 {
            let bit = digitBit(d)
            for (bases, covers, baseOf, coverOf, rowsAreBases) in orientations {
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
                    return Step(technique: technique, placement: nil, eliminations: eliminations, focus: focus) { language in
                        let baseList = list(baseSet.map { String($0 + 1) }, language)
                        let coverList = list(coverSet.map { String($0 + 1) }, language)
                        return rowsAreBases
                            ? localized("""
                                In den Zeilen \(baseList) passt die \(d) nur in die Spalten \(coverList), \
                                also fällt die \(d) im Rest dieser Spalten weg.
                                """, language)
                            : localized("""
                                In den Spalten \(baseList) passt die \(d) nur in die Zeilen \(coverList), \
                                also fällt die \(d) im Rest dieser Zeilen weg.
                                """, language)
                    }
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
                    return Step(technique: .xyWing, placement: nil, eliminations: eliminations, focus: [pivot, a, b]) { [layout] language in
                        localized("""
                            \(layout.cellName(pivot, language)) ist \(x) oder \(y), und so oder so wird eines der anderen \
                            markierten Felder zur \(zDigit), also fällt die \(zDigit) in allen Feldern weg, die beide sehen.
                            """, language)
                    }
                }
            }
        }
        return nil
    }
}
