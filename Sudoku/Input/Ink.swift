import SwiftUI

/// A digit as the pencil wrote it. Points are in cell units: (0, 0) is the cell's top left, (1, 1) its bottom right.
/// It stays tied to `digit`, so the board shows it only while the cell holds that digit (undo and redo included).
struct Ink: Codable, Equatable, Sendable {
    struct Point: Codable, Equatable, Sendable {
        var x: Float
        var y: Float
    }

    let digit: Int
    let strokes: [[Point]]

    /// Strokes in layer coordinates, mapped into `cell`'s frame. Points closer than a hundredth of a cell are dropped
    /// to keep the save small; nil when nothing is left to draw.
    init?(digit: Int, strokes: [[CGPoint]], in cell: CGRect) {
        let mapped = strokes.map { stroke in
            var points: [Point] = []
            for p in stroke {
                let point = Point(x: Float((p.x - cell.minX) / cell.width), y: Float((p.y - cell.minY) / cell.height))
                if let last = points.last, abs(last.x - point.x) < 0.01 && abs(last.y - point.y) < 0.01 { continue }
                points.append(point)
            }
            return points
        }.filter { !$0.isEmpty }
        guard !mapped.isEmpty else { return nil }
        self.digit = digit
        self.strokes = mapped
    }

    /// The strokes in a `side`-wide cell. Ink that reaches over the cell's edge is scaled down and centered,
    /// so a large digit stays readable inside its own cell.
    func path(side: CGFloat) -> Path {
        let all = strokes.joined()
        let minX = CGFloat(all.map(\.x).min() ?? 0), maxX = CGFloat(all.map(\.x).max() ?? 0)
        let minY = CGFloat(all.map(\.y).min() ?? 0), maxY = CGFloat(all.map(\.y).max() ?? 0)
        let inset: CGFloat = 0.1
        var scale: CGFloat = 1, dx: CGFloat = 0, dy: CGFloat = 0
        if minX < inset || minY < inset || maxX > 1 - inset || maxY > 1 - inset {
            scale = min(1, (1 - 2 * inset) / max(maxX - minX, maxY - minY, 0.01))
            dx = 0.5 - (minX + maxX) / 2 * scale
            dy = 0.5 - (minY + maxY) / 2 * scale
        }
        var path = Path()
        for stroke in strokes {
            let points = stroke.map { CGPoint(x: (CGFloat($0.x) * scale + dx) * side, y: (CGFloat($0.y) * scale + dy) * side) }
            guard let first = points.first else { continue }
            path.move(to: first)
            if points.count == 1 { path.addLine(to: first) } // a dot, e.g. a tiny stroke
            for point in points.dropFirst() { path.addLine(to: point) }
        }
        return path
    }
}
