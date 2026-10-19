import CoreGraphics

/// Cell geometry of the board. `gridFrame` is the board in the layer's coordinates; cells are exact `side / 9` squares.
struct GridGeometry {
    let gridFrame: CGRect

    private var cellSide: CGFloat { gridFrame.width / 9 }

    /// The cell under `point`; nil off the board.
    func cell(at point: CGPoint) -> Int? {
        let column = Int(((point.x - gridFrame.minX) / cellSide).rounded(.down))
        let row = Int(((point.y - gridFrame.minY) / cellSide).rounded(.down))
        guard (0..<9).contains(column), (0..<9).contains(row) else { return nil }
        return row * 9 + column
    }

    func frame(of cell: Int) -> CGRect {
        CGRect(x: gridFrame.minX + CGFloat(cell % 9) * cellSide, y: gridFrame.minY + CGFloat(cell / 9) * cellSide,
               width: cellSide, height: cellSide)
    }
}
