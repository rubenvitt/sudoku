import SwiftUI
import SudokuEngine

/// Lines and outlines that depend on the variant: region borders (boxes or Jigsaw regions) and Killer cages.
extension Variant {
    /// The region each cell lies in; -1 for a cell outside every region.
    var regionOfCell: [Int] {
        var result = [Int](repeating: -1, count: 81)
        for (r, region) in regions.enumerated() { for cell in region { result[cell] = r } }
        return result
    }

    /// Every edge between cells of different regions, on a board `side` points wide: the board's thick lines.
    func regionBorders(side: CGFloat) -> Path {
        let step = side / 9
        let region = regionOfCell
        var path = Path()
        for cell in 0..<81 {
            let row = cell / 9, column = cell % 9
            let x = CGFloat(column) * step, y = CGFloat(row) * step
            if column < 8 && region[cell] != region[cell + 1] {
                path.move(to: CGPoint(x: x + step, y: y))
                path.addLine(to: CGPoint(x: x + step, y: y + step))
            }
            if row < 8 && region[cell] != region[cell + 9] {
                path.move(to: CGPoint(x: x, y: y + step))
                path.addLine(to: CGPoint(x: x + step, y: y + step))
            }
        }
        return path
    }

    /// The cage each cell lies in, if any.
    var cageOfCell: [Int: Cage] {
        var result: [Int: Cage] = [:]
        for cage in cages { for cell in cage.cells { result[cell] = cage } }
        return result
    }
}

extension Cage {
    /// The cell whose corner shows the sum: the first one in reading order.
    var labelCell: Int { cells.min() ?? 0 }

    /// The cage's outline, `inset` inside its cells. In the label cell the outline starts after `label`,
    /// the size of the sum printed in its top-left corner.
    func outline(step: CGFloat, inset: CGFloat, label: CGSize) -> Path {
        let members = Set(cells)
        var path = Path()
        func line(_ from: CGPoint, _ to: CGPoint) {
            guard to.x - from.x > 0.5 || to.y - from.y > 0.5 else { return }
            path.move(to: from)
            path.addLine(to: to)
        }
        for cell in cells {
            let row = cell / 9, column = cell % 9
            /// Whether the cell `dr` rows and `dc` columns away belongs to the cage.
            func has(_ dr: Int, _ dc: Int) -> Bool {
                let r = row + dr, c = column + dc
                return (0..<9).contains(r) && (0..<9).contains(c) && members.contains(r * 9 + c)
            }
            let x0 = CGFloat(column) * step, y0 = CGFloat(row) * step
            let x1 = x0 + step, y1 = y0 + step
            // An open side runs from corner to corner; where the cage turns a corner, it reaches into the neighbour.
            func start(_ sideOpen: Bool, _ diagonal: Bool, _ low: CGFloat) -> CGFloat {
                sideOpen ? low + inset : diagonal ? low - inset : low
            }
            func end(_ sideOpen: Bool, _ diagonal: Bool, _ high: CGFloat) -> CGFloat {
                sideOpen ? high - inset : diagonal ? high + inset : high
            }
            let isLabel = cell == labelCell
            if !has(-1, 0) {
                let from = start(!has(0, -1), has(-1, -1), x0)
                let y = y0 + inset
                line(CGPoint(x: isLabel ? max(from, x0 + label.width) : from, y: y), CGPoint(x: end(!has(0, 1), has(-1, 1), x1), y: y))
            }
            if !has(1, 0) {
                let y = y1 - inset
                line(CGPoint(x: start(!has(0, -1), has(1, -1), x0), y: y), CGPoint(x: end(!has(0, 1), has(1, 1), x1), y: y))
            }
            if !has(0, -1) {
                let from = start(!has(-1, 0), has(-1, -1), y0)
                let x = x0 + inset
                line(CGPoint(x: x, y: isLabel ? max(from, y0 + label.height) : from), CGPoint(x: x, y: end(!has(1, 0), has(1, -1), y1)))
            }
            if !has(0, 1) {
                let x = x1 - inset
                line(CGPoint(x: x, y: start(!has(-1, 0), has(-1, 1), y0)), CGPoint(x: x, y: end(!has(1, 0), has(1, 1), y1)))
            }
        }
        return path
    }
}

/// Thermometers and Kropki dots, shared by the board and the menu's miniatures.
extension Variant {
    /// A bulb on each thermometer's first cell and a tube through the centres of the others, `side` points wide.
    func drawThermos(in context: GraphicsContext, side: CGFloat, color: Color) {
        let step = side / 9
        func centre(_ cell: Int) -> CGPoint {
            CGPoint(x: (CGFloat(cell % 9) + 0.5) * step, y: (CGFloat(cell / 9) + 0.5) * step)
        }
        for thermo in thermos {
            guard let bulb = thermo.first else { continue }
            var tube = Path()
            tube.move(to: centre(bulb))
            for cell in thermo.dropFirst() { tube.addLine(to: centre(cell)) }
            context.stroke(tube, with: .color(color), style: StrokeStyle(lineWidth: step * 0.3, lineCap: .round, lineJoin: .round))
            let radius = step * 0.36
            let middle = centre(bulb)
            context.fill(Path(ellipseIn: CGRect(x: middle.x - radius, y: middle.y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(color))
        }
    }

    /// Each dot on the middle of the edge its two cells share: white ones hollow, black ones filled, both ringed in `ink`
    /// so they show in dark mode too. `size` is the dot's width as a share of a cell.
    func drawDots(in context: GraphicsContext, side: CGFloat, ink: Color, size: CGFloat = 0.24) {
        let step = side / 9
        let radius = step * size / 2
        for dot in dots {
            let a = dot.cells[0], b = dot.cells[1]
            let x = (CGFloat(a % 9 + b % 9) / 2 + 0.5) * step, y = (CGFloat(a / 9 + b / 9) / 2 + 0.5) * step
            let circle = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            context.fill(circle, with: .color(dot.kind == .white ? .white : .black))
            context.stroke(circle, with: .color(ink), lineWidth: max(0.75, step * 0.03))
        }
    }

    /// Where `cell` sits on a thermometer: its place counted from the bulb, and the thermometer's length.
    func thermoPlace(of cell: Int) -> (place: Int, length: Int)? {
        for thermo in thermos {
            if let i = thermo.firstIndex(of: cell) { return (i + 1, thermo.count) }
        }
        return nil
    }
}
