public struct Variant: Codable, Hashable, Sendable {
    public let id: String
    public let rows: [[Int]]
    public let columns: [[Int]]
    public let regions: [[Int]]
    public let extras: [[Int]]
    private let peerTable: [[Int]]

    public var groups: [[Int]] { rows + columns + regions + extras }

    public func peers(of cell: Int) -> [Int] { peerTable[cell] }

    public init(id: String, rows: [[Int]], columns: [[Int]], regions: [[Int]], extras: [[Int]]) {
        self.id = id
        self.rows = rows
        self.columns = columns
        self.regions = regions
        self.extras = extras
        var sets = [Set<Int>](repeating: [], count: 81)
        for group in rows + columns + regions + extras {
            for cell in group { sets[cell].formUnion(group) }
        }
        peerTable = sets.enumerated().map { cell, set in set.subtracting([cell]).sorted() }
    }

    private enum CodingKeys: String, CodingKey { case id, rows, columns, regions, extras }

    /// A corrupt save must throw: `init` and the grader index by cell and keep group sets in 64 bits, and the hints name
    /// rows, columns and boxes of a 9×9 board (a tenth row would point past the box names).
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rows = try c.decode([[Int]].self, forKey: .rows)
        let columns = try c.decode([[Int]].self, forKey: .columns)
        let regions = try c.decode([[Int]].self, forKey: .regions)
        let extras = try c.decode([[Int]].self, forKey: .extras)
        let groups = rows + columns + regions + extras
        /// Nine groups of nine cells that together cover the board once.
        func partitions(_ lines: [[Int]]) -> Bool {
            lines.count == 9 && lines.allSatisfy { $0.count == 9 } && Set(lines.joined()) == Set(0..<81)
        }
        guard groups.count <= 64, groups.joined().allSatisfy((0..<81).contains),
              partitions(rows), partitions(columns), regions.allSatisfy({ $0.count == 9 }), regions.count <= 9 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Variant has invalid groups"))
        }
        self.init(id: try c.decode(String.self, forKey: .id), rows: rows, columns: columns, regions: regions, extras: extras)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(rows, forKey: .rows)
        try c.encode(columns, forKey: .columns)
        try c.encode(regions, forKey: .regions)
        try c.encode(extras, forKey: .extras)
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
}
