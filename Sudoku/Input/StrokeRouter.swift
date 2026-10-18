import CoreGraphics

/// Pure geometry for pencil strokes on the board. `gridFrame` is the board in the strokes' coordinates.
struct StrokeRouter {
    let gridFrame: CGRect
    let givens: Set<Int>

    private var cellSide: CGFloat { gridFrame.width / 9 }

    /// The cell under the center of `strokeBounds`; nil off the board and on givens (read-only).
    func cell(for strokeBounds: CGRect) -> Int? {
        let column = Int(((strokeBounds.midX - gridFrame.minX) / cellSide).rounded(.down))
        let row = Int(((strokeBounds.midY - gridFrame.minY) / cellSide).rounded(.down))
        guard (0..<9).contains(column), (0..<9).contains(row) else { return nil }
        let index = row * 9 + column
        return givens.contains(index) ? nil : index
    }

    func isNote(_ strokeBounds: CGRect) -> Bool {
        strokeBounds.height < 0.5 * gridFrame.height / 9
    }

    /// Too small to be a digit (a dot, a tick); scaled up for recognition it would read as "1".
    func isSpeck(_ strokeBounds: CGRect) -> Bool {
        max(strokeBounds.width, strokeBounds.height) < 0.12 * cellSide
    }

    /// Path longer than 4 × its width with at least 3 reversals in x. Two guards keep digits out:
    /// a reversal only counts past 0.1 × cell width (pen jitter on a "1"), and horizontal travel must
    /// exceed twice the vertical travel (an "8" reverses in x four times, but travels as much in y).
    func isScratchOut(_ points: [CGPoint]) -> Bool {
        guard let first = points.first else { return false }
        let xs = points.map(\.x)
        let width = xs.max()! - xs.min()!
        var length: CGFloat = 0, travelX: CGFloat = 0, travelY: CGFloat = 0
        for (a, b) in zip(points, points.dropFirst()) {
            length += hypot(b.x - a.x, b.y - a.y)
            travelX += abs(b.x - a.x)
            travelY += abs(b.y - a.y)
        }
        var reversals = 0, direction: CGFloat = 0, extreme = first.x
        for x in xs {
            let delta = x - extreme
            if direction * delta > 0 {
                extreme = x
            } else if abs(delta) > 0.1 * cellSide {
                if direction != 0 { reversals += 1 }
                direction = delta > 0 ? 1 : -1
                extreme = x
            }
        }
        return length > 4 * width && reversals >= 3 && travelX > 2 * travelY
    }
}
