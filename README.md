# Hachibu

Kalorienzähler für das iPhone nach dem Prinzip „Scan & Go“: öffnen, Barcode scannen, Menge eintippen, fertig.
Seit Version 2.0 komplett in SwiftUI geschrieben (iOS 17 oder neuer).

- Kein Konto, keine Werbung, keine Cloud, kein Tracking: Alle Daten bleiben in einer SQLite-Datenbank auf dem Gerät.
- Produktdaten kommen von [Open Food Facts](https://world.openfoodfacts.org) (ODbL). Unbekannte Produkte werden einmal von Hand erfasst und sind danach auch offline da.
- Suche mit Favoriten, „Zuletzt verwendet“, „Häufig gegessen“, lokalen Treffern und Online-Suche (nur beim Absenden, unter dem Rate Limit von Open Food Facts).
- Schnelleintrag nur mit Kalorien (Restaurant, Kantine) und Mahlzeiten vom Vortag mit einem Tipp übernehmen.
- Widgets für Homescreen und Sperrbildschirm: übrige Kalorien und Makros, Tippen öffnet den Scanner.
- Verlauf: Wochenübersicht mit Tagesziel und Gewichtsverlauf.
- Datensicherung als Datei (JSON) und Tagebuch-Export als CSV – wohin die Datei geht, entscheidet der Nutzer im Teilen-Menü.
- Tagesziel nach Mifflin-St. Jeor × PAL-Faktor oder eigenes Ziel (1.200–5.000 kcal), Makroverteilung frei einstellbar.

Version 1.0 (React Native/Expo) ist seit dem 05.10.2026 im App Store. Version 2.0 nutzt dieselbe Bundle-ID und dieselbe Datenbankdatei, bestehende Tagebücher bleiben beim Update erhalten.

## Bauen und testen – ohne Mac

Swift lässt sich nur auf macOS übersetzen. Deshalb bauen und testen **GitHub Actions** auf einem macOS-Runner von GitHub:

| Workflow | Wann | Was |
| --- | --- | --- |
| „Bauen und testen“ (`.github/workflows/ci.yml`) | bei jedem Push und Pull Request | erzeugt das Xcode-Projekt, baut die App im iPhone-Simulator, führt die Tests aus |
| „App Store Upload“ (`.github/workflows/release.yml`) | von Hand unter *Actions → Run workflow* | baut signiert, lädt zu App Store Connect hoch (erscheint dann in TestFlight) |

Das Ergebnis steht unter *Actions*; das vollständige Protokoll hängt als Artefakt am Lauf. Lokal unter Windows oder Linux gibt es nichts zu starten.

Die Projektdatei `Hachibu.xcodeproj` wird nicht eingecheckt, sondern auf dem Runner mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `project.yml` erzeugt. Wer doch einen Mac hat: `brew install xcodegen && xcodegen generate`, dann `Hachibu.xcodeproj` in Xcode öffnen.

## Veröffentlichen

Einmalig drei Secrets im Repository anlegen (*Settings → Secrets and variables → Actions → New repository secret*):

1. In [App Store Connect](https://appstoreconnect.apple.com/access/integrations/api) → *Benutzer und Zugriff → Integrationen → App-Store-Connect-API → Teamschlüssel* einen Schlüssel erzeugen: Name z. B. „GitHub Actions“, Zugriff **Admin** (nötig, weil der Upload Zertifikate anlegt und widerruft).
2. Die **Key ID** (10 Zeichen) als `ASC_KEY_ID`, die **Issuer ID** (über der Tabelle) als `ASC_ISSUER_ID` eintragen.
3. Die `.p8`-Datei herunterladen (geht nur einmal) und ihren kompletten Inhalt – inklusive der Zeilen `-----BEGIN PRIVATE KEY-----` und `-----END PRIVATE KEY-----` – als `ASC_KEY_P8` eintragen. Die Datei danach sicher aufbewahren oder löschen. **Niemals ins Repository legen.**

### Einmalig im Apple-Entwicklerportal

Das Widget teilt seine Daten mit der App über eine **App Group**. Die lässt sich nicht über die Schnittstelle anlegen, deshalb einmal von Hand unter https://developer.apple.com/account/resources/identifiers/list:

1. **App Group anlegen:** Neben „Identifiers“ auf das blaue **„+“** → **„App Groups“** → Continue → Description `Hachibu`, Identifier `group.com.abdelkarim.hachibu` → Continue → Register.
2. **Bundle-IDs zuordnen:** Für `com.abdelkarim.hachibu` und `com.abdelkarim.hachibu.widget` jeweils: in der Liste anklicken → neben **„App Groups“** auf **„Configure“** bzw. **„Edit“** → Häkchen bei `group.com.abdelkarim.hachibu` → Continue → oben rechts **„Save“** (einen Hinweis zu Profilen mit „Confirm“ bestätigen).

Fehlt die Widget-ID noch in der Liste, legt sie der erste Upload-Lauf selbst an und schaltet „App Groups“ ein; danach Schritt 2 für sie nachholen und den Upload erneut starten. Fehlt die Zuordnung, bricht der Upload mit einem deutschen Hinweis ab, bevor etwas hochgeladen wird.

### Hochladen

*Actions → „App Store Upload“ → Run workflow* (Branch `main`). [fastlane](https://fastlane.tools) (`fastlane/Fastfile`) erzeugt dabei ein Verteilungszertifikat und App-Store-Profile **nur für diesen Lauf**, signiert, lädt hoch, wartet, bis Apple den Build verarbeitet hat, und widerruft das Zertifikat danach wieder. So liegt nirgends ein dauerhaftes Zertifikat, auch nicht verschlüsselt. Apps im App Store und Builds in TestFlight bleiben davon unberührt, weil Apple sie selbst neu signiert. Ein Lauf dauert etwa 20 bis 45 Minuten; danach steht der Build in App Store Connect unter *TestFlight* und kann einer Version zugeordnet werden.

### Versionen

- **Sichtbare Version** (`2.0.0`): `MARKETING_VERSION` in `project.yml`, für jedes Update von Hand erhöhen.
- **Build-Nummer**: setzt der Upload automatisch auf die letzte Nummer in App Store Connect plus 1, mindestens 100 (die Expo-Builds gingen bis 6). Nicht von Hand eintragen.

Alles außerhalb des Codes (Screenshots, Store-Texte, Datenschutzangaben, Altersfreigabe, Prüfnotizen) steht in [`docs/app-store-connect.md`](docs/app-store-connect.md).

## Aufbau

| Ordner | Inhalt |
| --- | --- |
| `project.yml` | Beschreibung des Xcode-Projekts: Targets, Bundle-IDs, Info.plist-Einträge, Berechtigungen, Version |
| `Hachibu/App` | Start der App, `AppModel` (Zustand, Deep Links, Widget-Daten), `AppInfo` (Name, Kontakt, Kennung gegenüber Open Food Facts) |
| `Hachibu/Logic` | Reine Rechenlogik ohne Oberfläche: Nährwerte, Barcodes, Datum, lokale Suche, Mengen |
| `Hachibu/Network` | Anbindung an Open Food Facts (Produktabfrage und Suche) |
| `Hachibu/Data` | Datenbank: Migrationen, Öffnen, alle Abfragen, Sicherung und CSV-Export |
| `Hachibu/Views` | SwiftUI-Screens: Tagebuch, Scanner, Produkt eintragen, Suche, Verlauf, Profil, Mehr |
| `Hachibu/Legal` | Impressum, Links zu den Rechtstexten, Quellen der Berechnung, Lizenzen |
| `Shared` | Code für App **und** Widget: Kalorienring, Zahlenformat, Tages-Schnappschuss |
| `HachibuWidget` | Widget-Erweiterung (liest nur die Schnappschuss-Datei, nie die Datenbank) |
| `HachibuTests` | Tests mit Swift Testing: Rechenlogik, Barcodes, API-Parsing, Datum, Migrationen, Sicherung |
| `fastlane`, `Gemfile` | Signieren und Hochladen im Upload-Workflow |
| `docs` | Datenschutz, Impressum, Support (GitHub Pages) und die App-Store-Connect-Checkliste |
| `assets/source` | Vorlagen der Marke: `icon.png` (Zeichen „H.“ auf Creme `#F7F6F3`) und `wordmark.png` |

Das App-Icon liegt als 1024 × 1024 px ohne Transparenz in `Hachibu/Assets.xcassets/AppIcon.appiconset/icon.png`; iOS erzeugt alle kleineren Größen selbst. Ein neues Icon dort ersetzen.

## Datenbank

Die Datei `allahuma-diaet.db` liegt im Ordner `Documents/SQLite` der App – derselbe Ort wie in Version 1.0, deshalb bleibt das Tagebuch beim Update erhalten. Schema-Versionen 1 bis 3 stammen unverändert aus der ersten Version, Version 4 ergänzt Favoriten, Notizen für Schnelleinträge und den Gewichtsverlauf (`Hachibu/Data/Migrations.swift`). Zugriff über [GRDB.swift](https://github.com/groue/GRDB.swift), die einzige Fremdbibliothek.

## Rechtliches

Datenschutzerklärung, Impressum und Support-Seite liegen in `docs/` und werden über GitHub Pages unter `https://ing-bassam.github.io/AllahumaDiaet/` veröffentlicht. Die Adressen stecken in der App (`Hachibu/Legal/LegalInfo.swift`) und in App Store Connect – die Dateinamen deshalb nicht ändern.
