# Sudoku

iPad- und iPhone-App für Sudoku. Auf dem iPad mit dem Apple Pencil: Ziffern und Notizen direkt in die Zellen schreiben; auf dem iPhone per Zifferntasten. Dazu unendlich viele Rätsel in vier Schwierigkeitsgraden, Tipp, Überprüfen und Auswertung. Der Stand wird automatisch gespeichert. Sprachen: Deutsch, Englisch, Französisch, Spanisch, Italienisch.

Status: bereit für den App Store, siehe [`docs/app-store.md`](docs/app-store.md). Design in [`docs/superpowers/specs`](docs/superpowers/specs), Umsetzungsplan in [`docs/superpowers/plans`](docs/superpowers/plans).

## Aufbau

| Verzeichnis | Inhalt |
|---|---|
| `Packages/SudokuEngine` | Reiner Rechenkern: Modell, Löser, Generator, Bewerter, Tipp. Läuft mit `swift test`. |
| `Sudoku` | SwiftUI-App für iPadOS und iOS 18+. |

Das Xcode-Projekt ist nicht eingecheckt, es entsteht aus `project.yml`:

```bash
brew install xcodegen
xcodegen generate && open Sudoku.xcodeproj
```

## Lizenz

MIT, siehe [LICENSE](LICENSE).
