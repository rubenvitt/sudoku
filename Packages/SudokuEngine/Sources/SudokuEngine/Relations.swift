/// Thermo and Kropki: thermometers whose digits rise from the bulb, and dots between neighbours.
extension Board {
    /// The digit placed in `cell`, or its candidates.
    private func options(_ cell: Int) -> CandidateMask { cells[cell] == 0 ? cand[cell] : digitBit(Int(cells[cell])) }

    /// Along a thermometer every cell holds more than the one before it, so it can't be smaller than the smallest digit
    /// left there plus one, nor larger than the largest digit left in the next cell minus one.
    func thermo(_ visit: Visit) {
        for thermo in layout.variant.thermos {
            var low = thermo.map { digits(options($0)).first ?? 10 }
            var high = thermo.map { digits(options($0)).last ?? 0 }
            for i in thermo.indices.dropFirst() { low[i] = max(low[i], low[i - 1] + 1) }
            for i in thermo.indices.dropLast().reversed() { high[i] = min(high[i], high[i + 1] - 1) }
            var eliminations: [(cell: Int, digit: Int)] = []
            for (i, c) in thermo.enumerated() where cells[c] == 0 {
                eliminations += digits(cand[c]).filter { $0 < low[i] || $0 > high[i] }.map { (cell: c, digit: $0) }
            }
            guard !eliminations.isEmpty else { continue }
            let step = Step(technique: .thermo, placement: nil, eliminations: eliminations, focus: thermo) { language in
                localized("""
                    Auf dem markierten Thermometer steigen die Ziffern vom Kolben aus an, \
                    also fällt in seinen Feldern weg, was dafür zu klein oder zu groß ist.
                    """, language)
            }
            if visit(step) { return }
        }
    }

    /// A digit next to a dot needs a partner on the other side: one more or less at a white dot, half or double at a black one.
    func kropki(_ visit: Visit) {
        for dot in layout.variant.dots {
            let a = dot.cells[0], b = dot.cells[1]
            var eliminations: [(cell: Int, digit: Int)] = []
            for (here, there) in [(a, b), (b, a)] where cells[here] == 0 {
                let partners = digits(options(there))
                eliminations += digits(cand[here]).filter { d in !partners.contains { dot.allows(d, $0) } }.map { (cell: here, digit: $0) }
            }
            guard !eliminations.isEmpty else { continue }
            let step = Step(technique: .kropki, placement: nil, eliminations: eliminations, focus: [a, b]) { language in
                switch dot.kind {
                case .white:
                    localized("""
                        Am weißen Punkt folgen die Ziffern der beiden markierten Felder aufeinander, \
                        also fällt weg, was auf der anderen Seite keinen Nachbarn hat.
                        """, language)
                case .black:
                    localized("""
                        Am schwarzen Punkt ist eine Ziffer der beiden markierten Felder doppelt so groß wie die andere, \
                        also fällt weg, was auf der anderen Seite keinen Partner hat.
                        """, language)
                }
            }
            if visit(step) { return }
        }
    }
}

/// Random thermometers laid over a solution, each along cells whose digits rise.
enum Thermometers {
    static func make(over solution: Grid, using rng: inout some RandomNumberGenerator,
                     count: Int = 8, lengths: ClosedRange<Int> = 3...6) -> [[Int]] {
        var used = Set<Int>()
        var thermos: [[Int]] = []
        var tries = 0
        while thermos.count < count && tries < 2_000 {
            tries += 1
            let start = Int.random(in: 0..<81, using: &rng)
            guard !used.contains(start) else { continue }
            let length = Int.random(in: lengths, using: &rng)
            var path = [start]
            while path.count < length, let last = path.last {
                // The next cell holds a larger digit; the smallest steps up leave room for a long thermometer.
                let options = touching(last)
                    .filter { !used.contains($0) && !path.contains($0) && solution.cells[$0] > solution.cells[last] }
                    .filter { !crosses(last, $0, thermos + [path]) }
                    .sorted { solution.cells[$0] < solution.cells[$1] }
                guard let next = options.prefix(2).randomElement(using: &rng) else { break }
                path.append(next)
            }
            guard path.count >= lengths.lowerBound else { continue }
            thermos.append(path)
            used.formUnion(path)
        }
        return thermos
    }

    /// The up to eight cells around `cell`, diagonals included.
    static func touching(_ cell: Int) -> [Int] {
        let row = cell / 9, column = cell % 9
        var result: [Int] = []
        for dr in -1...1 {
            for dc in -1...1 where dr != 0 || dc != 0 {
                let r = row + dr, c = column + dc
                if (0..<9).contains(r) && (0..<9).contains(c) { result.append(r * 9 + c) }
            }
        }
        return result
    }

    /// Whether a diagonal step from `a` to `b` crosses a diagonal step of `paths` through the other two cells of their square.
    private static func crosses(_ a: Int, _ b: Int, _ paths: [[Int]]) -> Bool {
        guard a / 9 != b / 9 && a % 9 != b % 9 else { return false }
        let other: Set = [a / 9 * 9 + b % 9, b / 9 * 9 + a % 9]
        return paths.contains { path in zip(path, path.dropFirst()).contains { Set([$0, $1]) == other } }
    }
}

/// Kropki dots over a solution: about half of the neighbours that follow each other or where one is double the other.
enum KropkiDots {
    static func make(over solution: Grid, using rng: inout some RandomNumberGenerator, share: Double = 0.5) -> [Dot] {
        var dots: [Dot] = []
        for cell in 0..<81 {
            for next in [cell + 1, cell + 9] where next < 81 && (next == cell + 9 || cell % 9 < 8) {
                let x = Int(solution.cells[cell]), y = Int(solution.cells[next])
                let white = abs(x - y) == 1, black = x == 2 * y || y == 2 * x
                guard white || black, Double.random(in: 0..<1, using: &rng) < share else { continue }
                // 1 and 2 fit both dots.
                let kind: Dot.Kind = white && black ? (Bool.random(using: &rng) ? .white : .black) : white ? .white : .black
                dots.append(Dot(cell, next, kind))
            }
        }
        return dots
    }
}
