/// Bit d-1 set = digit d possible.
public typealias CandidateMask = UInt16

/// A filled cell yields only its own digit.
public func candidates(for grid: Grid, in variant: Variant) -> [CandidateMask] {
    (0..<81).map { cell in
        let d = grid.cells[cell]
        if d != 0 { return 1 << (d - 1) }
        let used = variant.peers(of: cell).reduce(CandidateMask(0)) { acc, p in
            let v = grid.cells[p]
            return v == 0 ? acc : acc | 1 << (v - 1)
        }
        return ~used & 0x1FF
    }
}
