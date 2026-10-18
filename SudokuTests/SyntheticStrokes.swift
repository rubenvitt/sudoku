import PencilKit

/// Pen strokes along straight segments through `corners`, as if written with a stylus.
/// Each call gets its own creation date, which the canvas uses to tell strokes apart.
@MainActor
func syntheticStroke(_ corners: [CGPoint]) -> PKStroke {
    var locations = [corners[0]]
    for (from, to) in zip(corners, corners.dropFirst()) {
        let steps = max(1, Int(hypot(to.x - from.x, to.y - from.y) / 2))
        locations += (1...steps).map { step in
            let t = CGFloat(step) / CGFloat(steps)
            return CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
        }
    }
    let points = locations.enumerated().map { index, location in
        PKStrokePoint(location: location, timeOffset: Double(index) * 0.01, size: CGSize(width: 4, height: 4),
                      opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
    }
    syntheticStrokeCount += 1
    let date = Date(timeIntervalSinceReferenceDate: TimeInterval(syntheticStrokeCount))
    return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: date))
}

@MainActor private var syntheticStrokeCount = 0

/// A handwritten-looking "7" filling a box at `origin` of `size` points.
@MainActor
func syntheticSeven(at origin: CGPoint, size: CGFloat) -> [PKStroke] {
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x * size, y: origin.y + y * size) }
    return [syntheticStroke([point(0.15, 0.05), point(0.8, 0.05), point(0.35, 0.95)])]
}
