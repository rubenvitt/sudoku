# Sudoku – Design

**Stand:** 18. Oktober 2026

Eine iPad-App für Sudoku, die man mit dem Apple Pencil spielt wie auf Papier:
Ziffern und Notizen werden direkt in die Zellen geschrieben. Menü auf, Art und
Schwierigkeit wählen, los. Unendlich viele Rätsel, der Stand wird laufend
gespeichert, am Ende gibt es eine Auswertung.

Markierung: **(Ruben)** = von Ruben entschieden, **(Claude)** = Annahme bzw.
Entscheidung von Claude, die Ruben gesehen und nicht widersprochen hat oder die
ein Builder ohne Rückfrage treffen durfte.

## 1. Ziele

- **Pencil-first (Ruben).** Ziffern werden mit dem Apple Pencil direkt in die
  Zelle geschrieben und erkannt. Das ist die Kernfunktion; alles andere ist
  Beiwerk.
- **Sofort spielen (Ruben).** Startbildschirm = einfaches Menü: Art wählen,
  Schwierigkeit wählen, Spiel startet ohne Wartezeit.
- **Unendliche Rätsel (Ruben).** Rätsel werden auf dem Gerät erzeugt, jedes mit
  genau einer Lösung. Keine Rätseldatenbank.
- **Schwierigkeitsgrade (Ruben):** Leicht, Mittel, Schwer, Experte **(Claude:
  Namen und Anzahl)**.
- **Notizen (Ruben).** Kandidaten in der Zelle, ebenfalls per Pencil.
- **Tipp (Ruben).** Auf Wunsch zeigt die App den nächsten logischen Schritt.
- **Überprüfen + Auswertung (Ruben).** Fehler werden erst auf Anfrage
  angezeigt. Am Ende eine Auswertung.
- **Automatisch speichern (Ruben).** Jeder Zug wird sofort persistiert; App
  schließen und wieder öffnen setzt genau dort fort.
- **Modern und nativ (Ruben).** Swift, SwiftUI, iPadOS-Designsprache.
- **Weitergeben per TestFlight (Ruben).** CI baut und lädt nach TestFlight hoch;
  eine externe Gruppe mit öffentlichem Link.

## 2. Nicht-Ziele (v1)

- **Varianten.** Perspektivisch alle (Diagonal, Hyper, Jigsaw, Killer, Thermo,
  Arrow, Kropki, XV, Sandwich, Anti-Knight, 6×6, 16×16 …) **(Ruben)**, v1 nur
  klassisches 9×9 **(Ruben)**. Der Kern wird so geschnitten, dass eine
  Regionen-Variante (Diagonal, Hyper, Jigsaw) nur neue Regionen bedeutet
  (§4.1). Hinweis-Varianten (Killer usw.) brauchen später eigene
  Constraint-Typen und Grafik — das wird jetzt **nicht** vorgebaut.
- Mac **(Claude)**. iPhone war hier zunächst ausgeschlossen; seit 18.10. gibt es
  eine iPhone-Variante **(Ruben)**: nur Hochformat, eigenes kompaktes Layout
  (Aktionen über den Zifferntasten, Tasten in zwei Reihen; seit 20.10. in einer Reihe), Eingabe per Finger.
  Das iPad-Layout bleibt unverändert; das kompakte Layout greift nur bei
  kompakter Breite (iPhone, schmale iPad-Fenster in Split View/Slide Over).
- **Update 20.10. (Ruben: „moderner, mehr iOS-Stil“):** Navigation über
  `NavigationStack` (großer Titel im Menü, Zurück-Wischen aus dem Spiel, Zeit
  in der Navigationsleiste). Aktionen auf allen Geräten als Symbol mit
  Beschriftung über den Zifferntasten, Löschen ist eine Aktion. Zifferntasten
  zeigen, wie oft eine Ziffer noch fehlt. Neues Icon, Akzentfarbe Indigo.
- iCloud-Sync, Konto, Game Center, Statistik-Historie, Tagesrätsel,
  Werbung/Käufe **(Claude)**.
- Mehrere parallele Spielstände: ein laufendes Spiel **(Claude)**.

## 3. Anti-Ziele

Was es zum Fehlschlag macht, auch wenn es technisch läuft:

- Erkennung, die spürbar hängt oder still falsche Ziffern einträgt, ohne dass
  man es sofort sieht und mit einer Geste korrigieren kann.
- Fehler, die ungefragt während des Spiels aufpoppen.
- Startbildschirm, der vor dem Spielen Entscheidungen oder Ladezeit verlangt.
- UI-Ballast: Einstellungsseiten, Onboarding-Karussell, Popups.

## 4. Aufbau

Wie Rudel: **(Claude)**

- `Packages/SudokuEngine` — reines Swift-Package, kein SwiftUI, kein UIKit.
  Modell, Löser, Generator, Bewerter, Tipp. Läuft mit `swift test`.
- `Sudoku/` — SwiftUI-App (iPadOS 18.0 — Ruben, 18.10.: Gerät evtl. noch nicht auf 26; Swift 6, strict concurrency).
- Xcode-Projekt per **xcodegen** aus `project.yml`, nicht eingecheckt.
- Bundle-ID **`dev.rubeen.sudoku`** (Ruben: Präfix `dev.rubeen`, Name
  „Sudoku"). Anzeigename auf dem Homescreen: **Sudoku**.

### 4.1 Engine

- **Gitter:** 81 Zellen, Werte 1–9, Kandidaten als 9-Bit-Maske.
- **Regionen:** Eine Variante ist eine Liste von „alle verschieden"-Gruppen
  (Zellindizes). Klassisch = 9 Zeilen + 9 Spalten + 9 Kästen. Löser, Bewerter
  und Prüfung arbeiten nur gegen diese Liste, nie gegen „Zeile/Spalte/Kasten"
  hart verdrahtet. Mehr Abstraktion gibt es nicht — Größe bleibt 9×9.
- **Löser:** Backtracking mit Bitmasken, Zellwahl nach wenigsten Kandidaten.
  `countSolutions(limit: 2)` für den Eindeutigkeitstest.
- **Generator:** zufällige volle Lösung → Givens in zufälliger, punktsymmetrischer
  Reihenfolge entfernen, solange die Lösung eindeutig bleibt → Bewerter
  entscheidet, ob das Ergebnis die gewünschte Stufe trifft; sonst neuer Versuch.
- **Bewerter (menschliche Techniken):** löst nur mit Logik, in dieser Ordnung;
  die schwerste nötige Technik bestimmt die Stufe **(Claude: Zuordnung)**:

  | Stufe | Benötigt höchstens |
  |---|---|
  | Leicht | Naked Single, Hidden Single |
  | Mittel | + Pointing / Box-Line-Reduction |
  | Schwer | + Naked/Hidden Pair, Naked Triple |
  | Experte | + X-Wing, Swordfish, XY-Wing; löst der Bewerter nicht vollständig, wird verworfen |

  Rätsel, die nur mit Raten lösbar sind, werden nie ausgeliefert.
- **Tipp:** derselbe Bewerter, angewandt auf den aktuellen Stand des Spielers
  (Ziffern, nicht seine Notizen): liefert den ersten anwendbaren Schritt —
  Zelle(n), Technik, ein Satz Begründung auf Deutsch. Hat der Spieler eine
  falsche Ziffer eingetragen, sagt der Tipp das zuerst („In Zeile 4 stimmt
  etwas nicht"), ohne die Zelle zu verraten **(Claude)**.

### 4.2 Sofort spielen

Generieren dauert für Experte bis zu Sekunden. Deshalb hält die App pro Stufe
ein fertiges Rätsel vorrätig (im Hintergrund erzeugt, mit gespeichert); Start
nimmt es aus dem Vorrat und füllt nach **(Claude)**. Erster App-Start: Vorrat
leer → kurzer Ladeindikator nur in diesem einen Fall.

### 4.3 Spielstand

Ein `Codable`-Spielstand (Rätsel, Lösung, Einträge, Notizen, Zeit, Tipps,
Prüfungen, Undo-Verlauf) als JSON-Datei in Application Support, nach jedem Zug
atomar geschrieben **(Claude: JSON statt SwiftData — ein Dokument, keine
Abfragen)**. Timer pausiert im Hintergrund.

## 5. Pencil-Eingabe

**Zielhardware (Ruben):** Logitech Crayon („Logi Pen") auf einem iPad von
2020/21, das bei iPadOS 26 endet. Folgen **(Claude)**:

- Kein Hover, kein Doppeltipp, kein Squeeze, kein Druck → nichts davon in v1.
  Die Eingabe darf nur Position, Neigung und Strichverlauf voraussetzen.
- Der Crayon meldet sich als `UITouch.TouchType.pencil` → Pencil- und
  Fingereingabe sind trennbar wie mit einem Apple Pencil.
- Deployment-Target iPadOS 18.0; Messlatte für Latenz ist dieses
  Gerät (A12–A14), nicht ein aktuelles iPad.

**Das größte Risiko.** Ruben hat die Probefahrt am 18.10. gestrichen: Start direkt mit Vision (a), Abnahme auf dem Gerät, Core ML (b) nur als Plan B nach Rückfrage. Der Spike-Text unten bleibt als Begründung stehen.

**Update 19.10.:** Vision ist auf dem Gerät durchgefallen (einzelne Ziffern kaum erkannt). Ruben hat Scribble (c) gewählt: `UIIndirectScribbleInteraction` über dem Raster, jede nicht vorgegebene Zelle ist ein Schreibfeld. Die Größenerkennung für Notizen ist gestrichen, Notizen nur noch über den Umschalter. Tinte und Wartezeit bis zur Übernahme bestimmt das System; Scribble muss in den Einstellungen an sein (Standard).

Soll-Verhalten **(Claude, Ruben ohne Widerspruch)**:

- Mit dem Pencil in eine Zelle schreiben → Ziffer erscheint gesetzt, sobald
  Scribble den Text übernimmt.
- ~~Klein geschrieben → Notiz~~ (gestrichen 19.10.): Notizen über den
  **Notizmodus-Umschalter**. Die Kandidaten werden immer an fester Position
  (3×3-Raster in der Zelle) angezeigt.
- ~~Durchkritzeln löscht~~ (gestrichen 19.10., stört mit Scribble das Überschreiben): Dieselbe Ziffer
  erneut schreiben löscht sie, sonst Löschen-Taste. Eine bereits gesetzte Notiz-Ziffer
  erneut schreiben entfernt sie (Toggle).
- **Finger:** tippen wählt eine Zelle; eine schmale Ziffernleiste erlaubt
  Eingabe ohne Pencil (auch Barrierefreiheit/VoiceOver).
- **Undo/Redo** per Zwei-Finger-Tipp bzw. Buttons.
- Givens sind schreibgeschützt; Striche dort werden verworfen.

Der Spike vergleicht mindestens: **(a)** Vision-Texterkennung auf den
gerasterten Strichen einer Zelle, **(b)** ein kleines Core-ML-Ziffernmodell
(z. B. per Create ML auf MNIST-artigen Daten), **(c)** UIKit Scribble
(`UIIndirectScribbleInteraction`). Abbruchkriterium: einzelne Ziffern 1–9 in
Rubens Handschrift ≥ 95 % richtig, Latenz nach Abheben < 300 ms auf einem
echten iPad, Notiz-/Ziffer-Unterscheidung verlässlich. Gewinner wird übernommen,
der Rest weggeworfen. Erfüllt keiner das Kriterium, kommt die Entscheidung zu
Ruben zurück.

Spike-Details **(Claude)**:

- **Teilerfolg:** Ziffern ≥ 95 %, aber Größen-Unterscheidung Notiz/Ziffer
  < 90 % richtig → Größenerkennung fliegt raus, Notizen nur über den
  Modus-Umschalter in der Leiste. Das ist akzeptabel und
  blockiert nichts.
- **Parallelität:** Nur die Eingabeschicht der App wartet auf den Spike.
  Engine, App-Gerüst, CI und App-Store-Connect-Einrichtung laufen parallel.
- **Messung:** Ruben schreibt auf seinem iPad je Ziffer 20 Proben in die
  Spike-App, die App zählt Treffer und Latenz und zeigt das Ergebnis an.
- **Handschrift bleibt privat:** Proben von Ruben landen nie im (öffentlichen)
  Repo. Ein eigenes Modell wird nur auf öffentlichen Daten (MNIST/EMNIST o. ä.)
  trainiert; im Repo stehen nur Trainingsskript, Modell und Messzahlen.

## 6. Bildschirme

1. **Menü:** „Weiterspielen" (wenn ein Spiel läuft, mit Stufe + Zeit), darunter
   Art (v1 nur „Klassisch", Liste bereits als Liste gebaut) und die vier Stufen
   als große Buttons. Ein Tipp auf eine Stufe startet sofort. Läuft schon ein
   Spiel, kurze Rückfrage „aktuelles Spiel verwerfen?".
2. **Spiel:** Gitter so groß wie möglich, schlanke Leiste mit Zeit, Undo/Redo,
   Notizmodus, Tipp, Überprüfen, Menü. Gleiche Ziffern und die Zeile/Spalte/
   Kasten der gewählten Zelle dezent hervorgehoben. Hoch- und Querformat.
3. **Überprüfen** (jederzeit): falsche Einträge rot markiert, bis zur nächsten
   Änderung an der Zelle. Zählt mit.
4. **Auswertung** (automatisch, sobald alle Zellen richtig gefüllt sind; ist das
   Gitter voll aber falsch, erscheinen stattdessen die Fehler): Stufe, Zeit,
   Anzahl Tipps, Anzahl Prüfungen, Fehler beim Prüfen. Buttons „Neues Spiel"
   (gleiche Stufe) und „Menü".

Haptik bei gesetzter Ziffer und beim Abschluss **(Claude)**.

## 7. Auslieferung

- **Repo öffentlich** auf GitHub (`rubenvitt/sudoku`) **(Ruben)**, MIT-Lizenz
  **(Claude)**. Keine Secrets im Repo; die Team-ID in `project.yml` ist
  unkritisch.
- **CI: GitHub Actions** (macOS-Runner): `swift test` für die Engine,
  `xcodebuild test` für die App bei jedem Push/PR; auf `main` zusätzlich
  Archive → Upload nach TestFlight → Build an die externe Gruppe verteilen.
  Signierung automatisch über einen App-Store-Connect-API-Key
  (`-allowProvisioningUpdates` + `-authenticationKey…`), Build-Nummer =
  `GITHUB_RUN_NUMBER`. Upload/Verteilung per `fastlane pilot` (auf den Runnern
  vorinstalliert) **(Claude)**. `ITSAppUsesNonExemptEncryption = NO`.
- **Einmalige Schritte in App Store Connect** macht Claude per Browser
  (Chrome DevTools MCP), Ruben loggt sich nur ein (2FA) **(Ruben)**:
  App-Eintrag anlegen, API-Key erzeugen und als Repo-Secrets hinterlegen,
  externe Gruppe mit öffentlichem Link, Testinformationen, erster Build durch
  die Beta-Review.
- **App-Store-Connect-Name:** „Sudoku" allein ist im Store vergeben; der
  ASC-Name braucht einen Zusatz (Vorschlag „Griffel Sudoku"), der
  Homescreen-Name bleibt „Sudoku" **(Claude)**.
- **Datenschutzerklärung:** `PRIVACY.md` im Repo („erhebt keine Daten"), als URL
  für TestFlight **(Claude)**.

## 8. Tests

- Engine: Löser findet Lösung und erkennt Mehrdeutigkeit; generierte Rätsel
  sind eindeutig und treffen ihre Stufe; jede Bewerter-Technik an einem
  bekannten Fixture-Rätsel; Tipp-Ausgabe; Spielstand-Roundtrip (Codable).
- App: ein UI-Smoke-Test (Menü → Spiel startet → Ziffer per Ziffernleiste →
  Überprüfen). Pencil-Erkennung wird im Spike manuell auf echter Hardware
  gemessen, nicht in CI.

## 9. Dem Builder überlassen

Farben/Typo im Rahmen der Systemoptik, genaue Debounce-Zeit, Aufteilung in
Dateien, Generator-Tuning (Givens-Zahl, Versuche), Formulierung der
Tipp-Texte, Xcode-Version auf dem Runner (muss eine für TestFlight zugelassene
Release-Version sein).
