# Sudoku

iPad-App für Sudoku, gespielt mit dem Apple Pencil: Ziffern und Notizen direkt in die Zellen schreiben, unendlich viele Rätsel in vier Schwierigkeitsgraden, Tipp, Überprüfen und Auswertung. Der Stand wird automatisch gespeichert.

Status: Planung. Design in [`docs/superpowers/specs`](docs/superpowers/specs), Umsetzungsplan in [`docs/superpowers/plans`](docs/superpowers/plans).

## Aufbau

| Verzeichnis | Inhalt |
|---|---|
| `Packages/SudokuEngine` | Reiner Rechenkern: Modell, Löser, Generator, Bewerter, Tipp. Läuft mit `swift test`. |
| `Sudoku` | SwiftUI-App für iPadOS 26. |

Das Xcode-Projekt ist nicht eingecheckt, es entsteht aus `project.yml`:

```bash
brew install xcodegen
xcodegen generate && open Sudoku.xcodeproj
```

## Lizenz

MIT, siehe [LICENSE](LICENSE).
