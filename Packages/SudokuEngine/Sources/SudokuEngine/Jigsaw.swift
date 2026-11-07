/// The up to four cells sharing an edge with `cell`.
func neighbours(_ cell: Int) -> [Int] {
    let row = cell / 9, column = cell % 9
    var result: [Int] = []
    if row > 0 { result.append(cell - 9) }
    if row < 8 { result.append(cell + 9) }
    if column > 0 { result.append(cell - 1) }
    if column < 8 { result.append(cell + 1) }
    return result
}

/// Random Jigsaw regions: the boxes, reshaped by many swaps of cells along their borders.
enum JigsawRegions {
    static func make(using rng: inout some RandomNumberGenerator, swaps: Int = 150) -> [[Int]] {
        var region = (0..<81).map { $0 / 27 * 3 + $0 % 9 / 3 }
        var done = 0, tries = 0
        while done < swaps && tries < swaps * 50 {
            tries += 1
            // Cell a moves into a neighbouring region; a cell of that region along the border moves back.
            let a = Int.random(in: 0..<81, using: &rng)
            let from = region[a]
            guard let b = neighbours(a).filter({ region[$0] != from }).randomElement(using: &rng) else { continue }
            let to = region[b]
            let returning = (0..<81).filter { c in region[c] == to && neighbours(c).contains { region[$0] == from } }
            guard let c = returning.randomElement(using: &rng) else { continue }
            region[a] = to
            region[c] = from
            if isConnected(from, in: region) && isConnected(to, in: region) {
                done += 1
            } else {
                region[a] = from
                region[c] = to
            }
        }
        return (0..<9).map { r in (0..<81).filter { region[$0] == r } }
    }

    /// Whether the cells of region `r` form one piece.
    private static func isConnected(_ r: Int, in region: [Int]) -> Bool {
        guard let start = region.firstIndex(of: r) else { return false }
        var seen: Set<Int> = [start], stack = [start]
        while let cell = stack.popLast() {
            for n in neighbours(cell) where region[n] == r && !seen.contains(n) {
                seen.insert(n)
                stack.append(n)
            }
        }
        return seen.count == region.filter { $0 == r }.count
    }
}
