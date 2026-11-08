/// Cells whose digits add up to `sum`: a cage, or what the rule of 45 derives from the cages of a row, column or box.
struct SumRule: Sendable {
    enum Origin: Sendable {
        case cage
        /// The cells of group `group` outside the cages that lie wholly in it; those cages add up to `total`.
        case inside(group: Int, total: Int)
        /// The cells outside group `group` of the cages reaching into it; those cages add up to `total`.
        case outside(group: Int, total: Int)
    }

    let cells: [Int]
    let sum: Int
    /// All cells see each other, so no digit repeats among them.
    let distinct: Bool
    let origin: Origin

    var isCage: Bool {
        if case .cage = origin { return true }
        return false
    }

    /// The cages plus every rule of 45 with at most a few cells, for each row, column and box.
    static func all(for variant: Variant, isPeer: [Bool]) -> [SumRule] {
        let cages = variant.cages
        guard !cages.isEmpty else { return [] }
        var rules = cages.map { SumRule(cells: $0.cells, sum: $0.sum, distinct: true, origin: .cage) }
        // Outside cells only add up when the cages cover the whole board.
        let coversBoard = Set(cages.flatMap(\.cells)).count == 81
        let houses = variant.rows + variant.columns + variant.regions
        for (g, house) in houses.enumerated() {
            let cellsOfHouse = Set(house)
            let inner = cages.filter { cellsOfHouse.isSuperset(of: $0.cells) }
            let covered = Set(inner.flatMap(\.cells))
            let rest = house.filter { !covered.contains($0) }
            let innerTotal = inner.reduce(0) { $0 + $1.sum }
            if (1...5).contains(rest.count), !cages.contains(where: { Set($0.cells) == Set(rest) }) {
                rules.append(SumRule(cells: rest, sum: 45 - innerTotal, distinct: true,
                                     origin: .inside(group: g, total: innerTotal)))
            }
            guard coversBoard else { continue }
            let touching = cages.filter { !cellsOfHouse.isDisjoint(with: $0.cells) }
            let outer = touching.flatMap(\.cells).filter { !cellsOfHouse.contains($0) }.sorted()
            if (1...3).contains(outer.count) {
                let total = touching.reduce(0) { $0 + $1.sum }
                let distinct = outer.indices.allSatisfy { i in outer[..<i].allSatisfy { isPeer[$0 * 81 + outer[i]] } }
                rules.append(SumRule(cells: outer, sum: total - 45, distinct: distinct,
                                     origin: .outside(group: g, total: total)))
            }
        }
        return rules
    }
}

/// Killer puzzles: random cages over a random solution, with as few givens as the logic needs.
enum KillerGenerator {
    static func make(_ difficulty: Difficulty, using rng: inout some RandomNumberGenerator, maxAttempts: Int) -> Puzzle? {
        guard Variant.killer.difficulties.contains(difficulty) else { return nil }
        // Bigger cages leave more combinations open, which makes harder puzzles likelier.
        let sizes = switch difficulty {
        case .easy: [2, 2, 2, 3, 3, 3, 4]
        case .medium: [2, 2, 3, 3, 3, 4, 4, 5]
        case .hard, .expert: [2, 3, 3, 4, 4, 5, 5]
        }
        for _ in 0..<maxAttempts {
            let solution = Solver.randomSolution(in: .classic, using: &rng)
            let variant = Variant.killer.with(cages: cages(over: solution, sizes: sizes, using: &rng))
            var givens = givensForLogic(in: variant, solution: solution, using: &rng)
            // A solve without guessing proves the solution unique. Should a fresh solve stall after all, more givens help it on.
            var result = Grader.solve(givens, in: variant)
            while result.difficulty == nil {
                let stalled = result.cells
                guard let cell = (0..<81).filter({ stalled[$0] == 0 }).randomElement(using: &rng) else { break }
                givens.cells[cell] = solution.cells[cell]
                result = Grader.solve(givens, in: variant)
            }
            guard var grade = result.difficulty else { continue }
            // Hard puzzles lose every given the logic can do without; about half of them then need hard steps.
            if difficulty == .hard {
                for cell in (0..<81).filter({ givens.cells[$0] != 0 }).shuffled(using: &rng) {
                    let trial = givens.setting(cell, to: 0)
                    if case let hardest? = Grader.solve(trial, in: variant).difficulty {
                        givens = trial
                        grade = hardest
                    }
                }
            }
            // Easy puzzles get more givens until only easy steps remain.
            while difficulty == .easy && grade != .easy {
                guard let cell = (0..<81).filter({ givens.cells[$0] == 0 }).randomElement(using: &rng),
                      case let hardest? = Grader.solve(givens.setting(cell, to: solution.cells[cell]), in: variant).difficulty
                else { break }
                givens.cells[cell] = solution.cells[cell]
                grade = hardest
            }
            if grade == difficulty {
                return Puzzle(variant: variant, givens: givens, solution: solution, difficulty: difficulty)
            }
        }
        return nil
    }

    /// Solves from an empty grid as far as the techniques go; where they stall, the solution's digit goes into a random
    /// open cell and solving goes on. One pass instead of a fresh solve for every given added.
    static func givensForLogic(in variant: Variant, solution: Grid, using rng: inout some RandomNumberGenerator) -> Grid {
        var givens = Grid(cells: [UInt8](repeating: 0, count: 81))
        var board = Board(givens, in: variant)
        while board.cells.contains(0) {
            if let step = board.nextStep() {
                board.apply(step)
                continue
            }
            let open = (0..<81).filter { board.cells[$0] == 0 }
            guard let cell = open.randomElement(using: &rng) else { break }
            let digit = Int(solution.cells[cell])
            givens.cells[cell] = solution.cells[cell]
            board.apply(Step(technique: .nakedSingle, placement: (cell, digit), eliminations: [], focus: []) { _ in "" })
        }
        return givens
    }

    /// Each cage grows from a free cell through neighbours whose digit it doesn't hold yet, to a size drawn from `sizes`.
    static func cages(over solution: Grid, sizes: [Int], using rng: inout some RandomNumberGenerator) -> [Cage] {
        var owner = [Int](repeating: -1, count: 81)
        var cages: [[Int]] = []
        for start in (0..<81).shuffled(using: &rng) where owner[start] < 0 {
            let target = sizes.randomElement(using: &rng) ?? 3
            var cage = [start]
            var digits: Set<UInt8> = [solution.cells[start]]
            owner[start] = cages.count
            while cage.count < target {
                let options = cage.flatMap(neighbours).filter { owner[$0] < 0 && !digits.contains(solution.cells[$0]) }
                guard let next = options.randomElement(using: &rng) else { break }
                cage.append(next)
                digits.insert(solution.cells[next])
                owner[next] = cages.count
            }
            cages.append(cage)
        }
        // A cage of one cell is a given in disguise: it joins a neighbouring cage that lacks its digit, where there is one.
        for i in cages.indices where cages[i].count == 1 {
            let cell = cages[i][0]
            let options = neighbours(cell).map { owner[$0] }.filter { j in
                j != i && cages[j].count < 5 && !cages[j].contains { solution.cells[$0] == solution.cells[cell] }
            }
            guard let j = options.randomElement(using: &rng) else { continue }
            cages[j].append(cell)
            owner[cell] = j
            cages[i] = []
        }
        return cages.filter { !$0.isEmpty }.map { cage in
            Cage(cells: cage, sum: cage.reduce(0) { $0 + Int(solution.cells[$1]) })
        }
    }
}

extension Grid {
    func setting(_ cell: Int, to digit: UInt8) -> Grid {
        var copy = self
        copy.cells[cell] = digit
        return copy
    }
}

extension Board {
    /// Per cell of `rule`: the digits it takes in at least one way to fill the rule's cells, and the digit sets those ways use.
    func fillings(_ rule: SumRule) -> (possible: [CandidateMask], sets: Set<CandidateMask>) {
        let cellsOfRule = rule.cells
        var possible = [CandidateMask](repeating: 0, count: cellsOfRule.count)
        var sets: Set<CandidateMask> = []
        var chosen = [Int](repeating: 0, count: cellsOfRule.count)
        let options = cellsOfRule.map { cells[$0] == 0 ? cand[$0] : digitBit(Int(cells[$0])) }
        // Fewest options first, so dead ends show early.
        let order = cellsOfRule.indices.sorted { options[$0].nonzeroBitCount < options[$1].nonzeroBitCount }

        func fill(_ j: Int, _ rest: Int, _ used: CandidateMask) {
            let left = order.count - j
            if left == 0 {
                guard rest == 0 else { return }
                for i in chosen.indices { possible[i] |= digitBit(chosen[i]) }
                sets.insert(used)
                return
            }
            let i = order[j]
            for d in digits(options[i]) where rest - d >= left - 1 && rest - d <= 9 * (left - 1) {
                if rule.distinct {
                    if used & digitBit(d) != 0 { continue }
                } else if order[..<j].contains(where: { chosen[$0] == d && layout.isPeer[cellsOfRule[$0] * 81 + cellsOfRule[i]] }) {
                    continue
                }
                chosen[i] = d
                fill(j + 1, rest - d, used | digitBit(d))
            }
        }
        fill(0, rule.sum, 0)
        return (possible, sets)
    }

    /// Cage sums (`.cageSum`) or the rule of 45 (`.rule45`): digits that fit no way of reaching the sum drop out.
    func sumRule(_ technique: Technique, _ visit: Visit) {
        for rule in layout.sumRules {
            guard rule.isCage == (technique == .cageSum), rule.cells.contains(where: { cells[$0] == 0 }) else { continue }
            let (possible, sets) = fillings(rule)
            var eliminations: [(cell: Int, digit: Int)] = []
            for (i, c) in rule.cells.enumerated() where cells[c] == 0 {
                eliminations += digits(cand[c] & ~possible[i]).map { (cell: c, digit: $0) }
            }
            guard !eliminations.isEmpty else { continue }
            // Digit sets are only telling when no digit repeats.
            let combinations = rule.distinct ? sets.sorted().map { digits($0).map(String.init).joined(separator: " + ") } : []
            let step = Step(technique: technique, placement: nil, eliminations: eliminations, focus: rule.cells) { [layout] language in
                let premise = switch rule.origin {
                case .cage:
                    localized("Die markierten Felder ergeben zusammen \(rule.sum).", language)
                case let .inside(g, total):
                    localized("""
                        \(sentenceStart(layout.inGroup(g, language))) ergeben alle Ziffern zusammen 45 und die Käfige ganz darin \(total), \
                        also ergeben die markierten Felder zusammen \(rule.sum).
                        """, language)
                case let .outside(g, total):
                    localized("""
                        \(sentenceStart(layout.inGroup(g, language))) ergeben alle Ziffern zusammen 45 und die Käfige, die hineinreichen, \
                        \(total), also ergeben die markierten Felder außerhalb zusammen \(rule.sum).
                        """, language)
                }
                let conclusion = (1...3).contains(combinations.count)
                    ? localized("Das geht nur noch mit \(alternatives(combinations, language)), also fällt dort weg, was nicht dazu passt.", language)
                    : localized("Also fällt dort weg, was zu keiner möglichen Summe passt.", language)
                return localized("\(premise) \(conclusion)", language)
            }
            if visit(step) { return }
        }
    }
}

/// "3 + 7", "1 + 9 oder 3 + 7"
func alternatives(_ items: [String], _ language: String?) -> String {
    guard let last = items.last, items.count > 1 else { return items.joined() }
    let head = items.dropLast().joined(separator: ", ")
    return localized("\(head) oder \(last)", language)
}
