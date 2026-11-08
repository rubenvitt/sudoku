/// A Killer cage: its digits differ and add up to `sum`.
public struct Cage: Codable, Hashable, Sendable {
    /// Sorted, so the first cell is the top-left one in reading order, where the sum is printed.
    public let cells: [Int]
    public let sum: Int

    public init(cells: [Int], sum: Int) {
        self.cells = cells.sorted()
        self.sum = sum
    }
}

/// A Kropki dot between two cells sharing an edge. White: the digits follow each other (3 and 4).
/// Black: one digit is twice the other (3 and 6). Between 1 and 2 either dot can stand.
public struct Dot: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case white, black }

    /// Sorted: the left or upper cell first.
    public let cells: [Int]
    public let kind: Kind

    public init(_ a: Int, _ b: Int, _ kind: Kind) {
        cells = [min(a, b), max(a, b)]
        self.kind = kind
    }

    /// Whether digits `x` and `y` fit the dot, in either order.
    public func allows(_ x: Int, _ y: Int) -> Bool {
        switch kind {
        case .white: abs(x - y) == 1
        case .black: x == 2 * y || y == 2 * x
        }
    }
}

public struct Variant: Codable, Hashable, Sendable {
    public let id: String
    public let rows: [[Int]]
    public let columns: [[Int]]
    public let regions: [[Int]]
    public let extras: [[Int]]
    /// Killer cages. Not groups: a cage holds fewer than nine digits, so "the 5 fits only here" never holds in one.
    public let cages: [Cage]
    /// Thermometers, bulb first: the digits rise along each one. Cells of a thermometer never repeat a digit,
    /// but they aren't peers either: only the order rules them.
    public let thermos: [[Int]]
    /// Kropki dots. Only the dots shown count; two neighbours without a dot may still follow each other.
    public let dots: [Dot]
    private let peerTable: [[Int]]

    public var groups: [[Int]] { rows + columns + regions + extras }

    public func peers(of cell: Int) -> [Int] { peerTable[cell] }

    public init(id: String, rows: [[Int]], columns: [[Int]], regions: [[Int]], extras: [[Int]], cages: [Cage] = [],
                thermos: [[Int]] = [], dots: [Dot] = []) {
        self.id = id
        self.rows = rows
        self.columns = columns
        self.regions = regions
        self.extras = extras
        self.cages = cages
        self.thermos = thermos
        self.dots = dots
        var sets = [Set<Int>](repeating: [], count: 81)
        for group in rows + columns + regions + extras + cages.map(\.cells) {
            for cell in group { sets[cell].formUnion(group) }
        }
        peerTable = sets.enumerated().map { cell, set in set.subtracting([cell]).sorted() }
    }

    /// The same rules on new regions, cages, thermometers or dots; Jigsaw, Killer, Thermo and Kropki puzzles each bring their own.
    func with(regions: [[Int]]? = nil, cages: [Cage]? = nil, thermos: [[Int]]? = nil, dots: [Dot]? = nil) -> Variant {
        Variant(id: id, rows: rows, columns: columns, regions: regions ?? self.regions, extras: extras, cages: cages ?? self.cages,
                thermos: thermos ?? self.thermos, dots: dots ?? self.dots)
    }

    private enum CodingKeys: String, CodingKey { case id, rows, columns, regions, extras, cages, thermos, dots }

    /// A corrupt save must throw: `init` and the grader index by cell and keep group sets in 64 bits, and the hints name
    /// rows, columns and boxes of a 9×9 board (a tenth row would point past the box names).
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rows = try c.decode([[Int]].self, forKey: .rows)
        let columns = try c.decode([[Int]].self, forKey: .columns)
        let regions = try c.decode([[Int]].self, forKey: .regions)
        let extras = try c.decode([[Int]].self, forKey: .extras)
        // Saves from before Killer have no cages.
        let cages = try c.decodeIfPresent([Cage].self, forKey: .cages) ?? []
        // Saves from before Thermo and Kropki have neither.
        let thermos = try c.decodeIfPresent([[Int]].self, forKey: .thermos) ?? []
        let dots = try c.decodeIfPresent([Dot].self, forKey: .dots) ?? []
        let groups = rows + columns + regions + extras
        /// Nine groups of nine cells that together cover the board once.
        func partitions(_ lines: [[Int]]) -> Bool {
            lines.count == 9 && lines.allSatisfy { $0.count == 9 } && Set(lines.joined()) == Set(0..<81)
        }
        guard groups.count <= 64, groups.joined().allSatisfy((0..<81).contains),
              partitions(rows), partitions(columns), regions.allSatisfy({ $0.count == 9 }), regions.count <= 9,
              cages.allSatisfy({ (1...9).contains($0.cells.count) && Set($0.cells).count == $0.cells.count && (1...45).contains($0.sum) }),
              cages.flatMap(\.cells).allSatisfy((0..<81).contains), Set(cages.flatMap(\.cells)).count == cages.flatMap(\.cells).count,
              thermos.allSatisfy(Self.isThermometer), Set(thermos.joined()).count == thermos.joined().count,
              dots.allSatisfy({ $0.cells.count == 2 && $0.cells.allSatisfy((0..<81).contains) && neighbours($0.cells[0]).contains($0.cells[1]) })
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Variant has invalid groups"))
        }
        self.init(id: try c.decode(String.self, forKey: .id), rows: rows, columns: columns, regions: regions, extras: extras,
                  cages: cages, thermos: thermos, dots: dots)
    }

    /// Two to nine cells on the board, each touching the one before, sideways or diagonally.
    static func isThermometer(_ cells: [Int]) -> Bool {
        guard (2...9).contains(cells.count), cells.allSatisfy((0..<81).contains), Set(cells).count == cells.count else { return false }
        return zip(cells, cells.dropFirst()).allSatisfy { a, b in
            a != b && abs(a / 9 - b / 9) <= 1 && abs(a % 9 - b % 9) <= 1
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(rows, forKey: .rows)
        try c.encode(columns, forKey: .columns)
        try c.encode(regions, forKey: .regions)
        try c.encode(extras, forKey: .extras)
        if !cages.isEmpty { try c.encode(cages, forKey: .cages) }
        if !thermos.isEmpty { try c.encode(thermos, forKey: .thermos) }
        if !dots.isEmpty { try c.encode(dots, forKey: .dots) }
    }

    public static let classic = Variant(
        id: "classic",
        rows: (0..<9).map { r in (0..<9).map { r * 9 + $0 } },
        columns: (0..<9).map { c in (0..<9).map { $0 * 9 + c } },
        regions: (0..<9).map { b in
            (0..<9).map { i in (b / 3 * 3 + i / 3) * 9 + b % 3 * 3 + i % 3 }
        },
        extras: []
    )

    /// Classic plus both main diagonals: top-left to bottom-right, then top-right to bottom-left.
    public static let diagonal = Variant(
        id: "diagonal",
        rows: classic.rows, columns: classic.columns, regions: classic.regions,
        extras: [(0..<9).map { $0 * 10 }, (0..<9).map { ($0 + 1) * 8 }]
    )

    /// Classic plus four shaded 3×3 windows, each one cell in from a corner of the board.
    public static let windoku = Variant(
        id: "windoku",
        rows: classic.rows, columns: classic.columns, regions: classic.regions,
        extras: [(1, 1), (1, 5), (5, 1), (5, 5)].map { top, left in
            (0..<9).map { (top + $0 / 3) * 9 + left + $0 % 3 }
        }
    )

    /// Nine irregular regions instead of boxes. This is the menu's entry; every puzzle gets its own regions.
    public static let jigsaw = Variant(id: "jigsaw", rows: classic.rows, columns: classic.columns, regions: classic.regions, extras: [])

    /// Cages with sums on top of the classic rules. This is the menu's entry; every puzzle gets its own cages.
    public static let killer = Variant(id: "killer", rows: classic.rows, columns: classic.columns, regions: classic.regions, extras: [])

    /// Thermometers whose digits rise from the bulb, on top of the classic rules. The menu's entry; every puzzle gets its own.
    public static let thermo = Variant(id: "thermo", rows: classic.rows, columns: classic.columns, regions: classic.regions, extras: [])

    /// White and black dots between neighbours, on top of the classic rules. The menu's entry; every puzzle gets its own.
    public static let kropki = Variant(id: "kropki", rows: classic.rows, columns: classic.columns, regions: classic.regions, extras: [])

    /// Every variant the app offers, in menu order.
    public static let all: [Variant] = [.classic, .diagonal, .windoku, .jigsaw, .killer, .thermo, .kropki]

    /// The offered variant with this id, if any.
    public static func named(_ id: String) -> Variant? { all.first { $0.id == id } }

    /// The menu entry this puzzle's variant belongs to: a Jigsaw puzzle's own regions lead back to `.jigsaw`.
    public var offered: Variant { Variant.named(id) ?? self }

    /// The difficulties offered for this variant. Killer, Thermo and Kropki stop at hard: cage sums, thermometers and dots
    /// settle what X-Wing and the like would, so expert puzzles of theirs practically never come up.
    public var difficulties: [Difficulty] {
        [Variant.killer.id, Variant.thermo.id, Variant.kropki.id].contains(id) ? [.easy, .medium, .hard] : Difficulty.allCases
    }
}
