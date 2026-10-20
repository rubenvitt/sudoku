# App-Store-Veröffentlichung

Was im Repo vorbereitet ist und was nur in App Store Connect geht.

## Im Repo

| Was | Wo |
|---|---|
| App-Icon hell, dunkel, getönt | `Sudoku/Assets.xcassets/AppIcon.appiconset`, Quellen in `design/` |
| Version 1.0, Kategorie Rätselspiele | `project.yml` |
| Datenschutz-Manifest (keine Daten, kein Tracking) | `Sudoku/PrivacyInfo.xcprivacy` |
| Exportkontrolle: keine Verschlüsselung | `ITSAppUsesNonExemptEncryption = NO` in `project.yml` |
| Texte (Name, Untertitel, Beschreibung, Schlüsselwörter, URLs) | `fastlane/metadata/de-DE` |
| Screenshots 6,9″ iPhone und 13″ iPad | Workflow **Screenshots** (von Hand starten), Ergebnis als Artefakt |
| Build | Workflow **TestFlight** bei jedem Push auf `main` |

## In App Store Connect (einmalig)

1. **Name prüfen.** „Sudoku" allein ist vergeben; Vorschlag in `fastlane/metadata/de-DE/name.txt`. Auf dem Homescreen heißt die App weiter „Sudoku".
2. **Datenschutz-URL erreichbar machen.** `privacy_url.txt` zeigt auf `PRIVACY.md` im Repo — dafür muss das Repo öffentlich sein (sonst z. B. auf GitHub Pages oder rubeen.dev legen und die URL anpassen).
3. **App-Datenschutz:** „Keine Daten erhoben" auswählen.
4. **Altersfreigabe:** Fragebogen überall mit „Nein" → 4+.
5. **Preis und Verfügbarkeit:** kostenlos, Länder wählen.
6. **Texte hochladen:** `fastlane metadata` (braucht `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` wie die TestFlight-Lane) oder von Hand aus `fastlane/metadata` kopieren.
7. **Screenshots:** Workflow „Screenshots" starten, Artefakte herunterladen, unter 6,9″ (iPhone) und 13″ (iPad) hochladen.
8. **Build wählen** (letzter TestFlight-Build mit Version 1.0), **Zur Prüfung einreichen.**

## Hinweise für die Prüfung

Kein Login, keine Demo-Daten nötig. Notiz an das Review-Team (optional):

> Ziffern lassen sich auf dem iPad mit dem Apple Pencil direkt in die Zellen schreiben (iPadOS Scribble) oder auf allen Geräten über die Zifferntasten eingeben.
