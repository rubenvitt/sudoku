# App-Store-Veröffentlichung

Was im Repo vorbereitet ist und was nur in App Store Connect geht.

## Im Repo

| Was | Wo |
|---|---|
| App-Icon hell, dunkel, getönt | `Sudoku/Assets.xcassets/AppIcon.appiconset`, Quellen in `design/` |
| Version 1.0, Kategorie Rätselspiele | `project.yml` |
| Datenschutz-Manifest (keine Daten, kein Tracking) | `Sudoku/PrivacyInfo.xcprivacy` |
| Exportkontrolle: keine Verschlüsselung | `ITSAppUsesNonExemptEncryption = NO` in `project.yml` |
| Texte Deutsch und Englisch (Name, Untertitel, Beschreibung, Schlüsselwörter, Werbetext, URLs) | `fastlane/metadata/de-DE`, `fastlane/metadata/en-US` |
| Notiz an das Prüfteam | `fastlane/metadata/review_information/notes.txt` |
| Screenshots 6,9″ iPhone und 13″ iPad | Workflow **Screenshots**, läuft auch im Workflow **App Store** mit |
| Build | Workflow **TestFlight** bei jedem Push auf `main` |
| Texte und Screenshots hochladen, optional einreichen | Workflow **App Store** (von Hand starten, nur auf `main`) |

## Workflow „App Store"

Startet unter *Actions → App Store → Run workflow* auf `main`:

- **Ohne Eingaben:** macht frische Screenshots und lädt sie mit allen Texten und der Prüfnotiz hoch (`fastlane metadata`). Nichts wird eingereicht.
- **`submit` = `einreichen`:** wie oben, hängt zusätzlich den neuesten verarbeiteten TestFlight-Build an (oder den aus `build_number`) und reicht die Version aus `project.yml` zur Prüfung ein (`fastlane submit`). Nach der Freigabe durch Apple wird die App **nicht** automatisch veröffentlicht; das geschieht von Hand in App Store Connect.

Kontakt für das Prüfteam (Pflicht beim Einreichen, bleibt aus dem öffentlichen Repo heraus), unter *Settings → Secrets and variables → Actions*:

| Name | Art |
|---|---|
| `REVIEW_FIRST_NAME`, `REVIEW_LAST_NAME`, `REVIEW_EMAIL` | Variable |
| `REVIEW_PHONE` | Secret, mit Ländervorwahl, z. B. `+49 …` |

Wer die Felder lieber direkt in App Store Connect pflegt, lässt sie leer; die Lane überschreibt dann nur die Notiz.

## In App Store Connect (einmalig, nur im Browser)

Diese Angaben gibt es nicht über den API-Schlüssel:

1. **App-Datenschutz:** „Keine Daten erhoben" auswählen und veröffentlichen. Datenschutz-URL ist schon in den Texten (`PRIVACY.md`, Repo ist öffentlich).
2. **Altersfreigabe:** Fragebogen überall mit „Nein" bzw. „Keine" → 4+.
3. **Vertrag für bezahlte Apps:** unter *Business* (früher „Verträge, Steuern und Bankverbindungen") den Paid Apps Agreement annehmen, Bankkonto und Steuerformulare (W-8BEN für Deutschland) eintragen. Ohne aktiven Vertrag lässt sich kein Preis über 0 € setzen.
4. **Preis und Verfügbarkeit:** Grundpreis 1,49 € (Deutschland als Basisland, die anderen Länder rechnet Apple um), Länder wählen. Einmalkauf, keine In-App-Käufe.
5. **Name prüfen.** In App Store Connect heißt die App „Griffel Sudoku" (`name.txt` muss dazu passen, sonst benennt der Upload sie um). Auf dem Homescreen heißt die App weiter „Sudoku".
6. Danach Workflow **App Store** mit `submit` = `einreichen` starten, nach der Freigabe **Version veröffentlichen**.

## Hinweise für die Prüfung

Kein Login, keine Demo-Daten nötig. Die Notiz an das Prüfteam steht in `fastlane/metadata/review_information/notes.txt` und wird mit hochgeladen.
