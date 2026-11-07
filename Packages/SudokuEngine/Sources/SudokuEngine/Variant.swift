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

public struct Variant: Codable, Hashable, Sendable {
    public let id: String
    public let rows: [[Int]]
    public let columns: [[Int]]
    public let regions: [[Int]]
    public let extras: [[Int]]
    /// Killer cages. Not groups: a cage holds fewer than nine digits, so "the 5 fits only here" never holds in one.
    public let cages: [Cage]
    private let peerTable: [[Int]]

    public var groups: [[Int]] { rows + columns + regions + extras }

    public func peers(of cell: Int) -> [Int] { peerTable[cell] }

    public init(id: String, rows: [[Int]], columns: [[Int]], regions: [[Int]], extras: [[Int]], cages: [Cage] = []) {
        self.id = id
        self.rows = rows
        self.columns = columns
        self.regions = regions
        self.extras = extras
        self.cages = cages
        var sets = [Set<Int>](repeating: [], count: 81)
        for group in rows + columns + regions + extras + cages.map(\.cells) {
            for cell in group { sets[cell].formUnion(group) }
        }
        peerTable = sets.enumerated().map { cell, set in set.subtracting([cell]).sorted() }
    }

    /// The same rules on new regions or with new cages; Jigsaw and Killer puzzles each bring their own.
    func with(regions: [[Int]]? = nil, cages: [Cage]? = nil) -> Variant {
        Variant(id: id, rows: rows, columns: columns, regions: regions ?? self.regions, extras: extras, cages: cages ?? self.cages)
    }

    private enum CodingKeys: String, CodingKey { case id, rows, columns, regions, extras, cages }

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
        let groups = rows + columns + regions + extras
        /// Nine groups of nine cells that together cover the board once.
        func partitions(_ lines: [[Int]]) -> Bool {
            lines.count == 9 && lines.allSatisfy { $0.count == 9 } && Set(lines.joined()) == Set(0..<81)
        }
        guard groups.count <= 64, groups.joined().allSatisfy((0..<81).contains),
              partitions(rows), partitions(columns), regions.allSatisfy({ $0.count == 9 }), regions.count <= 9,
              cages.allSatisfy({ (1...9).contains($0.cells.count) && Set($0.cells).count == $0.cells.count && (1...45).contains($0.sum) }),
              cages.flatMap(\.cells).allSatisfy((0..<81).contains), Set(cages.flatMap(\.cells)).count == cages.flatMap(\.cells).count else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Variant has invalid groups"))
        }
        self.init(id: try c.decode(String.self, forKey: .id), rows: rows, columns: columns, regions: regions, extras: extras,
                  cages: cages)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(rows, forKey: .rows)
        try c.encode(columns, forKey: .columns)
        try c.encode(regions, forKey: .regions)
        try c.encode(extras, forKey: .extras)
        if !cages.isEmpty { try c.encode(cages, forKey: .cages) }
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

    /// Every variant the app offers, in menu order.
    public static let all: [Variant] = [.classic, .diagonal, .windoku, .jigsaw, .killer]

    /// The offered variant with this id, if any.
    public static func named(_ id: String) -> Variant? { all.first { $0.id == id } }

    /// The menu entry this puzzle's variant belongs to: a Jigsaw puzzle's own regions lead back to `.jigsaw`.
    public var offered: Variant { Variant.named(id) ?? self }
}
