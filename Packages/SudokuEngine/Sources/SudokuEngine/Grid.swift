public struct Grid: Codable, Hashable, Sendable {
    /// 81 cells, row-major, 0 = empty.
    public var cells: [UInt8]

    public init(_ string: String) {
        precondition(string.count == 81, "Grid needs 81 characters")
        cells = string.map { $0.wholeNumberValue.map(UInt8.init) ?? 0 }
    }

    init(cells: [UInt8]) { self.cells = cells }

    public var isComplete: Bool { !cells.contains(0) }
}
