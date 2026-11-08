# Sudoku – Übungsraum für Lösungstechniken

**Stand:** 8. November 2026 · Alle Schritte aus §8 gebaut, in einem PR statt
fünf. Texte in allen neun Sprachen der App. Ruben hat die Fragen aus §9 am
8. November mit dreimal Ja beantwortet: gestufter Tipp im Spiel mit Link
„Technik üben“ (§7), drei Übungen = geübt, englischer Name in Klammern in der
Liste und klein unter dem Titel der Technikseite. Die Uhr steht, solange die
Technikseite über dem Spiel liegt. Als Startstellungen dienen die bekannten Beispielbretter je Technik
(`Exercises.starters`), umgeformt bei jedem Aufruf; neue Stellungen kommen im
Hintergrund aus frisch erzeugten Rätseln dazu.

Ein eigener Bereich der App, in dem man jede Lösungstechnik einzeln kennenlernt:
kurz erklärt, an einem Beispiel gezeigt, dann an echten Stellungen selbst
angewandt. Grundlage ist der Bewerter, der die Techniken schon heute erkennt
und für den Tipp in Sätze fasst (`Techniques.swift`, `Grader.swift`).

Markierung wie in `2026-10-18-sudoku-design.md`: **(Ruben)** = von Ruben
entschieden, **(Claude)** = Vorschlag von Claude, gilt, solange Ruben nicht
widerspricht. Offene Fragen an Ruben stehen gesammelt in §9.

## 1. Ziele

- **Jede Technik einzeln lernen (Ruben, 7.11.: „Übungsraum, um die einzelnen
  Taktiken zu erklären“).** Pro Technik: Erklärung, Beispiel, Übung.
- **Üben an echten Stellungen (Claude).** Jede Übung ist eine Stellung, in der
  genau die geübte Technik den nächsten Schritt freischaltet und nichts
  Leichteres hilft. Man kann sich nicht mit einem einfacheren Trick
  vorbeimogeln.
- **Unendlich viele Übungen, auf dem Gerät erzeugt (Claude, folgt aus Rubens
  „keine Rätseldatenbank“).**
- **Gleiche Eingabe wie im Spiel (Claude).** Pencil per Scribble, Finger per
  Ziffernleiste, Notizmodus. Keine neue Geste.
- **Brücke zum Spiel (Claude).** Der Tipp im Spiel kann zuerst nur die Technik
  nennen („Hier hilft ein Nacktes Paar“) und von dort in den Übungsraum führen.

## 2. Nicht-Ziele

- Varianten im Übungsraum. Geübt wird klassisch 9 × 9; die Techniken gelten in
  Diagonal und Windoku genauso, die Erklärtexte müssten dort aber
  Zusatzgruppen mitdenken. Später, wenn gewünscht **(Claude)**.
- Neue Techniken (Unique Rectangle, Ketten, W-Wing …). Erst üben, was der
  Bewerter kann; neue Techniken sind ein eigenes Thema, weil sie auch die
  Stufen verschieben **(Claude)**.
- Kurs mit Freischalten, Punkten, Abzeichen, Streaks **(Claude, aus den
  Anti-Zielen „UI-Ballast“ und „kein Onboarding-Karussell“)**.
- Videos oder Animationen über das Hervorheben von Feldern hinaus.

## 3. Anti-Ziele

- Eine Übung, die sich auch ohne die geübte Technik lösen lässt.
- Ein Erklärtext, der Fachbegriffe voraussetzt, die erst später erklärt werden.
- Ein Übungsraum, der das Menü überfrachtet oder sich beim ersten Start
  aufdrängt.
- Eine Übung, die eine richtige Lösung als falsch wertet, weil der Spieler eine
  andere gültige Stelle für dieselbe Technik gefunden hat.

## 4. Welche Techniken

Genau die neun aus `Technique`, in derselben Reihenfolge und mit denselben
Namen wie im Tipp **(Claude)**. Der Reihe-Kasten-Check (`intersection`) deckt
Pointing und Box-Line-Reduction gemeinsam ab, das bleibt so.

| Stufe | Technik | Art des Schritts | Kernsatz der Erklärung (Entwurf) |
|---|---|---|---|
| Leicht | Nackter Einer | Ziffer setzen | Ein Feld, in das nur noch eine Ziffer passt. |
| Leicht | Versteckter Einer | Ziffer setzen | Eine Ziffer, die in einer Zeile, Spalte oder einem Kasten nur noch in ein Feld passt. |
| Mittel | Reihe-Kasten-Check | Notizen streichen | Liegt eine Ziffer in einem Kasten nur in einer Zeile, fällt sie im Rest dieser Zeile weg (und umgekehrt). |
| Schwer | Nacktes Paar | Notizen streichen | Zwei Felder einer Gruppe mit denselben zwei Kandidaten teilen sie unter sich auf. |
| Schwer | Verstecktes Paar | Notizen streichen | Zwei Ziffern, die in einer Gruppe nur in dieselben zwei Felder passen, belegen diese Felder. |
| Schwer | Nacktes Tripel | Notizen streichen | Wie das Paar, mit drei Feldern und drei Ziffern. |
| Experte | X-Wing | Notizen streichen | Passt eine Ziffer in zwei Zeilen nur in dieselben zwei Spalten, fällt sie im Rest dieser Spalten weg. |
| Experte | Schwertfisch | Notizen streichen | Wie der X-Wing, mit drei Zeilen und drei Spalten. |
| Experte | XY-Wing | Notizen streichen | Ein Feld mit zwei Kandidaten zwingt eines von zwei Partnerfeldern zur selben Ziffer, also fällt sie überall weg, wo beide hinsehen. |

Die Erklärseite übernimmt dieselbe Reihenfolge; jede Technik setzt nur die
davor stehenden voraus. Die Texte werden wie die Tipps in Deutsch geschrieben
und in EN/FR/ES/IT übersetzt (String Catalog der Engine).

## 5. Wie Übungsstellungen entstehen

### 5.1 Idee: beim Bewerten mitschneiden

Der Bewerter löst ein Rätsel Schritt für Schritt und wählt dabei immer die
*erste* anwendbare Technik in der Reihenfolge oben (`Board.nextStep`). Daraus
folgt die gewünschte Eigenschaft gratis: In dem Moment, in dem er zum ersten
Mal Technik T anwendet, hilft keine leichtere Technik mehr. Diese Stellung
(Ziffern + Kandidaten nach allen bisherigen Schritten) ist eine Übung für T
**(Claude)**.

Neu in der Engine:

- `Exercise` (Codable): Variante, Ziffern, Kandidaten, Lösung, Technik T.
- `Exercises.mine(from: Puzzle)`: geht das Rätsel wie `Grader.grade` durch und
  liefert für jede Technik die erste Stellung, an der sie gebraucht wird. Ein
  Rätsel liefert so mehrere Übungen auf einmal, meist eine pro Technik bis zu
  seiner Stufe.
- `Board.steps(of: T)`: alle Anwendungen von T in einer Stellung, nicht nur die
  erste. Die Technikfunktionen geben heute beim ersten Treffer zurück; sie
  bekommen eine Variante, die weitersucht. Das braucht die Prüfung (§6.3),
  damit jede gültige Stelle zählt.

Für die beiden Einer gilt eine Ausnahme: Sie werden nur aus leichten Rätseln
geschnitten, bevor überhaupt eine Notiz gestrichen wurde. So stimmen die
Kandidaten mit dem überein, was man ohne Notizen im Kopf hat **(Claude)**.

### 5.2 Vielfalt und Seltenheit

Leichte Techniken fallen bei jedem Rätsel ab. Schwertfisch und XY-Wing sind
selten; ein Experte-Rätsel braucht oft nur eine der drei Experte-Techniken.
Zwei Mittel dagegen **(Claude)**:

1. **Nichts wegwerfen.** Der Generator verwirft heute jeden Versuch, der die
   Stufe nicht trifft. Diese Versuche werden für den Übungsvorrat mitgeschnitten
   (sie sind eindeutig lösbar, nur eben zu leicht oder zu schwer).
2. **Umformen.** Eine Stellung bleibt eine Übung derselben Technik, wenn man
   die Ziffern umbenennt, Zeilen innerhalb eines Bandes oder ganze Bänder
   tauscht, dasselbe mit Spalten, oder das Gitter spiegelt. Aus einer
   gefundenen Stellung werden so beliebig viele, die man nicht wiedererkennt.

Wie im Spiel hält ein Vorrat pro Technik ein paar fertige Übungen bereit, im
Hintergrund gefüllt und mitgespeichert (wie `PuzzleStock`). Erster Besuch
mit leerem Vorrat: kurzer Ladeindikator nur bei der gewählten Technik.

**Erste Aufgabe im Bau ist eine Messung:** wie viele Generator-Versuche im
Schnitt nötig sind, bis jede Technik einmal vorkommt, auf Rubens iPad. Reicht
das nicht für „sofort spielen“, kommt pro seltener Technik eine Handvoll
Startstellungen fest in die App, die per Umformen variiert werden. Das ist
keine Rätseldatenbank im Sinne von §1 des Hauptdesigns, sondern ein Samen; die
Entscheidung kommt dann trotzdem zu Ruben zurück **(Claude)**.

## 6. Bildschirme

### 6.1 Einstieg im Menü

Unter „Neues Spiel“ ein Abschnitt **„Techniken üben“** mit einer einzigen Zeile
(Symbol, Titel, „9 Techniken · 3 geübt“). Sie öffnet eine Liste der Techniken,
gruppiert nach Stufe, mit Häkchen bei geübten. Keine Pflicht, kein Hinweis beim
ersten Start **(Claude)**.

„Geübt“ heißt: drei Übungen dieser Technik ohne Auflösen geschafft. Gespeichert
als kleine Datei neben dem Spielstand. Es schaltet nichts frei und lässt sich
jederzeit wiederholen **(Claude)**.

### 6.2 Technikseite

Eine Seite pro Technik, von oben nach unten:

1. **Erklärung:** zwei bis vier Sätze, Kernsatz aus §4 vorneweg.
2. **Beispiel:** ein Gitter, auf dem die Technik farbig markiert ist: die
   Felder, die den Schluss tragen (heutiges `focus`, gelb), und die Notizen,
   die wegfallen (rot durchgestrichen) bzw. die Ziffer, die gesetzt wird. Ein
   Knopf „Schritt zeigen“ spielt den Schritt ab. Dazu der Satz, den auch der
   Tipp sagt (`Step.explanation`).
3. **„Selbst probieren“:** startet eine Übung.

Das Beispiel ist eine feste, von Hand ausgesuchte Stellung pro Technik, damit
Text und Bild zusammenpassen und übersetzt werden können. Neun Stellungen als
kleine JSON-Datei in der App, einmalig mit dem Miner aus §5 gefunden
**(Claude)**.

### 6.3 Übung

Dasselbe Spielfeld wie im Spiel (`GridView` mit Scribble-Ebene und
Ziffernleiste), mit drei Unterschieden **(Claude)**:

- **Notizen sind vorbelegt** mit den Kandidaten der Stellung (außer bei den
  Einern, §5.1). Bei Streich-Techniken startet die Übung im Notizmodus.
- **Eingabe wie gewohnt.** Ziffer setzen: in die Zelle schreiben oder Zelle +
  Ziffernleiste. Notiz streichen: im Notizmodus dieselbe Ziffer erneut
  schreiben oder tippen (das bestehende Umschalten). Es braucht keine neue
  Geste.
- **Sofortige Rückmeldung**, anders als im Spiel. Das Anti-Ziel „Fehler poppen
  ungefragt auf“ gilt fürs Spielen, nicht fürs Üben.

Prüfung:

- Gilt als **geschafft**, sobald die gesetzte Ziffer bzw. die gestrichenen
  Notizen eine der gültigen Anwendungen aus `Board.steps(of: T)` vollständig
  enthalten **und** keine Fehleingabe mehr auf dem Feld steht. Eine andere
  gültige Stelle als die des Beispiels zählt genauso.
- Eine **Fehleingabe** (eine gestrichene Notiz, die keine Anwendung von T
  streicht, oder eine falsche Ziffer) wird sofort zurückgenommen: Die Zelle
  blinkt kurz rot, die Notiz bzw. das leere Feld ist wieder da. So kann man
  sich nicht durch Ausprobieren zum Erfolg streichen, und es bleibt nie ein
  Fehler stehen, den man erst suchen müsste. Kein Strafzähler.
- **Gestufte Hilfe** über den Tipp-Knopf: 1. Kernsatz der Technik, 2. die
  Gruppe(n) markieren, in denen es passiert, 3. die tragenden Felder
  markieren, 4. auflösen (Schritt wird gezeigt, Übung zählt nicht als
  geschafft).

Nach dem Schaffen wie nach dem Auflösen: kurze Bestätigung mit dem Tipp-Satz
zur Stelle („Geschafft“ bzw. „So geht es“), Knöpfe „Nächste Übung“ und
„Zurück“ zur Technikseite. Kein Ergebnisbildschirm mit Zeit.

### 6.4 Barrierefreiheit

Übung und Beispiel sagen per VoiceOver dasselbe wie der Tipp (`announce`);
markierte Felder bekommen eine Beschriftung („trägt den Schluss“, „hier fällt
die 7 weg“). Die Ziffernleiste reicht für alle Übungen, Pencil ist nie Pflicht.

Die Rückmeldung zur Eingabe wird ebenfalls angesagt, nicht nur gezeigt: bei
einer Fehleingabe „Passt nicht, die 7 bleibt“ (bzw. „Die 4 passt hier nicht“),
beim Schaffen „Geschafft“ plus Tipp-Satz, beim Auflösen der Tipp-Satz. Dazu
dieselbe Haptik wie im Spiel.

## 7. Brücke zum Spiel (optional, eigener kleiner Schritt)

Der Tipp im Spiel gibt heute sofort den ganzen Satz und markiert die Felder.
Vorschlag **(Claude, Ruben entscheidet, §9)**:

- **Erster Tipp-Druck:** nur die Technik („Hier hilft ein Nacktes Paar.“).
- **Zweiter Druck auf denselben Schritt:** Felder markieren und ganzer Satz,
  wie heute.
- Im Hinweis-Banner ein Link „Technik üben“, der die Technikseite öffnet; der
  Spielstand ist dabei schon gespeichert.
- `hintsUsed` zählt einen Schritt einmal, egal wie oft man drückt.
- **Falsche Ziffer im Gitter:** Liefert `Game.hint()` `.wrongEntry`, bleibt es
  beim heutigen Satz („In Zeile 4 stimmt etwas nicht.“), ohne Stufen und ohne
  Link „Technik üben“.

Wie der halbe Tipp gespeichert wird: Heute trägt `hint()` die Streichungen des
Schritts sofort in `hintEliminations` ein, damit der nächste Tipp darauf
aufbaut. Beim ersten Druck passiert das **nicht**; `Game` merkt sich nur die
genannte Technik (`announcedTechnique`, Codable, optional, damit alte
Spielstände laden) und vergisst sie bei jeder Änderung am Gitter. Erst der
zweite Druck rechnet den Schritt neu aus (`nextStep` ist für denselben Stand
deterministisch), zeigt ihn und trägt die Streichungen ein. So baut ein Tipp
nie auf Streichungen auf, die der Spieler nicht gesehen hat, auch nicht nach
App-Neustart. Sonst liefert die Engine schon alles (`Step.technique`,
`focus`, `explanation`).

## 8. Bau und Aufwand

Eigenes Release **nach** Diagonal/Windoku **(Claude)**.
Der Übungsraum berührt die Varianten nur über `Variant.classic`; die
Engine-Änderungen in §5 sind neue Funktionen neben den bestehenden, sie ändern
weder Bewertung noch Generator-Ergebnis.

| Schritt | Inhalt | Umfang |
|---|---|---|
| 1 | Engine: `Board.steps(of:)`, `Exercise`, Miner, Umformen, Tests; Messung der Trefferquote | ein PR, mittel |
| 2 | App: Menüeintrag, Technikliste, Fortschritt, Übungsvorrat | ein PR, klein bis mittel |
| 3 | App: Übungsansicht mit vorbelegten Notizen, Prüfung, gestufter Hilfe; `GridView` lernt „gestrichene Notiz“ und eine zweite Markierungsfarbe | ein PR, mittel |
| 4 | Technikseiten: neun Beispielstellungen, Texte, Übersetzungen EN/FR/ES/IT | ein PR, mittel (vor allem Text) |
| 5 | Optional: gestufter Tipp im Spiel mit Link | ein PR, klein |

Vier PRs für den Übungsraum, ein fünfter für den Tipp im Spiel. Was Zeit
von Ruben braucht: die Erklärtexte einmal lesen (sind sie verständlich für
jemanden, der die Technik nicht kennt?) und eine Übungsrunde auf dem iPad mit
dem Crayon, um zu sehen, ob das Streichen von Notizen per Scribble angenehm
ist.

**Risiken:**

- Notizen streichen per Scribble ist in kleinen Notizfeldern fummelig, vor
  allem auf dem iPhone. Ausweg: Zelle wählen und Ziffer in der Leiste tippen
  geht immer; falls es trotzdem hakt, später Antippen einer Notiz zum
  Streichen.
- Seltene Techniken (§5.2), siehe Messung.
- Erklärtexte sind der eigentliche Aufwand. Schlechte Texte machen den Raum
  wertlos, auch wenn die Technik stimmt.

## 9. Fragen an Ruben

1. Soll der gestufte Tipp im Spiel (§7) Teil des Releases sein, oder bleibt
   der Tipp wie heute und nur der Link „Technik üben“ kommt dazu?
2. Reichen drei geschaffte Übungen für „geübt“, oder soll es gar keinen
   Fortschritt geben (nur die Liste)?
3. Bleiben die deutschen Namen („Reihe-Kasten-Check“, „Nacktes Paar“), oder
   sollen die verbreiteten englischen Namen (Pointing, Naked Pair) in
   Klammern dazu, damit man sie woanders wiederfindet?
