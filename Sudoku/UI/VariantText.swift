import SudokuEngine

extension Variant {
    var title: String {
        switch id {
        case "diagonal": String(localized: "Diagonal")
        case "windoku": String(localized: "Windoku")
        case "jigsaw": String(localized: "Jigsaw")
        case "killer": String(localized: "Killer")
        default: String(localized: "Klassisch")
        }
    }

    /// The extra rule on top of rows, columns and boxes, as the menu explains it.
    var rule: String {
        switch id {
        case "diagonal": String(localized: "Auch beide Diagonalen enthalten 1 bis 9.")
        case "windoku": String(localized: "Auch die vier grauen Fenster enthalten 1 bis 9.")
        case "jigsaw": String(localized: "Statt Kästen gibt es neun verwinkelte Gebiete, jedes enthält 1 bis 9.")
        case "killer": String(localized: "Die Ziffern jedes Käfigs ergeben seine kleine Zahl und wiederholen sich darin nicht.")
        default: String(localized: "Jede Zeile, Spalte und jeder Kasten enthält 1 bis 9.")
        }
    }
}

extension Puzzle {
    /// "Schwer", or "Diagonal · Schwer" for every variant but the classic one.
    var label: String {
        variant == .classic ? difficulty.title : "\(variant.title) · \(difficulty.title)"
    }
}
