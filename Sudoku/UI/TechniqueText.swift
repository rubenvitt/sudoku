import SudokuEngine

/// What the practice room says about each technique: one key sentence, then a few that explain why it holds.
extension Technique {
    /// The technique's name in English, as other apps and websites use it; nil where it reads the same as `title`.
    var englishName: String? {
        let english = title(language: "en")
        return english == title ? nil : english
    }

    var summary: String {
        switch self {
        case .nakedSingle: String(localized: "Ein Feld, in das nur noch eine Ziffer passt.")
        case .hiddenSingle: String(localized: "Eine Ziffer, die in einer Zeile, Spalte oder einem Kasten nur noch in ein Feld passt.")
        case .intersection: String(localized: "Liegt eine Ziffer in einem Kasten nur in einer Zeile, fällt sie im Rest dieser Zeile weg, und umgekehrt.")
        case .nakedPair: String(localized: "Zwei Felder einer Gruppe mit denselben zwei Kandidaten teilen sie unter sich auf.")
        case .hiddenPair: String(localized: "Zwei Ziffern, die in einer Gruppe nur in dieselben zwei Felder passen, belegen diese Felder.")
        case .nakedTriple: String(localized: "Wie das Paar, mit drei Feldern und drei Ziffern.")
        case .xWing: String(localized: "Passt eine Ziffer in zwei Zeilen nur in dieselben zwei Spalten, fällt sie im Rest dieser Spalten weg.")
        case .swordfish: String(localized: "Wie der X-Wing, mit drei Zeilen und drei Spalten.")
        case .xyWing: String(localized: "Ein Feld mit zwei Kandidaten zwingt eines von zwei Partnerfeldern zur selben Ziffer, also fällt sie überall weg, wo beide hinsehen.")
        default: title // the Killer, Thermo and Kropki steps never come up in the practice room
        }
    }

    /// Why the technique holds, for someone who knows only the techniques before it.
    var details: String {
        switch self {
        case .nakedSingle: String(localized: "Schau, welche Ziffern in der Zeile, der Spalte und dem Kasten des Feldes schon stehen. Fehlt nur noch eine, gehört sie hinein.")
        case .hiddenSingle: String(localized: "Jede Zeile, Spalte und jeder Kasten braucht jede Ziffer genau einmal. Sind alle anderen Felder für eine Ziffer gesperrt, muss sie in das letzte.")
        case .intersection: String(localized: "Die Ziffer muss im Kasten irgendwo in dieser Zeile stehen. Damit ist sie in der Zeile vergeben, auch außerhalb des Kastens. Mit Spalten geht es genauso, und ebenso von der Zeile zum Kasten.")
        case .nakedPair: String(localized: "Welche der beiden Ziffern in welches Feld kommt, ist noch offen, aber beide sind vergeben. In den übrigen Feldern der Gruppe fallen sie deshalb weg.")
        case .hiddenPair: String(localized: "Die beiden Ziffern brauchen diese zwei Felder. Für andere Ziffern ist dort kein Platz mehr, also fallen dort alle übrigen Kandidaten weg.")
        case .nakedTriple: String(localized: "Drei Felder einer Gruppe haben zusammen nur drei Kandidaten, auch wenn nicht jedes Feld alle drei hat. Die drei Ziffern verteilen sich auf diese Felder und fallen im Rest der Gruppe weg.")
        case .xWing: String(localized: "In jeder der beiden Zeilen steht die Ziffer in einer der zwei Spalten, also über Kreuz. Damit ist sie in beiden Spalten vergeben. Mit Zeilen und Spalten vertauscht geht es genauso.")
        case .swordfish: String(localized: "Die Ziffer verteilt sich auf drei Felder, in jeder der drei Zeilen und jeder der drei Spalten eines. Im Rest dieser Spalten fällt sie weg. Nicht jede Zeile muss alle drei Spalten berühren.")
        case .xyWing: String(localized: "Das Mittelfeld hat zwei Kandidaten, etwa 1 oder 2. Ein Partner, den es sieht, hat 1 oder 3, der andere 2 oder 3. Wie auch immer das Mittelfeld ausgeht, einer der Partner wird zur 3. Wo beide Partner hinsehen, fällt die 3 weg.")
        default: ""
        }
    }
}
