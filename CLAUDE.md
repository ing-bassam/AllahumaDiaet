# Hachibu (Repository AllahumaDiaet)

## Zweck
- Hachibu ist ein kostenloser Kalorien- und Nährwertzähler für Erwachsene, ohne Konto, Werbung und Tracking; alle Daten bleiben in SQLite auf dem iPhone.
- Version 1.0 (React Native/Expo) ist seit 05.10.2026 im deutschen App Store. Version 2.0 ist die Neufassung in SwiftUI (nur iPhone, iOS 17+) und übernimmt die Datenbank der 1.0 unverändert. Android gibt es nicht mehr.

## Aufbau
- `project.yml` – beschreibt das Xcode-Projekt; XcodeGen erzeugt daraus auf dem Runner `Hachibu.xcodeproj` (nicht eingecheckt). Version und Build-Nummer stehen hier (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`).
- `Hachibu/App` – Start, `AppModel` (Zustand, Deep Links, Widget-Schnappschuss), `AppInfo` (Name, Kontakt, Kennung gegenüber Open Food Facts).
- `Hachibu/Logic` – reine Rechenlogik ohne UI; `Hachibu/Network` – Open Food Facts; `Hachibu/Data` – Migrationen, Datenbank, Abfragen, Sicherung; `Hachibu/Views` – SwiftUI-Screens; `Hachibu/Legal` – Impressum, Links, Quellen.
- `Shared/` – Code für App und Widget (Ring, Zahlenformat, Tages-Schnappschuss). `HachibuWidget/` – das Widget. `HachibuTests/` – Tests mit Swift Testing.
- `.github/workflows/ci.yml` baut und testet im Simulator bei jedem Push und PR; `release.yml` lädt auf Knopfdruck signiert zu App Store Connect hoch (`ci/ExportOptions.plist` gehört dazu).
- `docs/` – Datenschutz, Impressum, Support; GitHub Pages veröffentlicht den Ordner von `main` unter https://ing-bassam.github.io/AllahumaDiaet/.

## Befehle
- Es gibt keinen Mac: Bauen und Testen laufen nur auf GitHub Actions (macOS-Runner). Unter Windows lässt sich Swift nicht übersetzen – also pushen und den Lauf lesen: `gh run list --workflow ci.yml`, `gh run view <id> --log-failed`.
- Die Tests laufen im Workflow mit `xcodebuild test -scheme Hachibu -destination 'platform=iOS Simulator,name=iPhone 17'` (siehe `ci.yml`).
- Upload in den App Store: Actions → „App Store Upload“ → Run workflow. Braucht die Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (App-Store-Connect-API-Schlüssel, Rolle App Manager) – nicht geprüft, bis die Secrets angelegt sind.
- Für ein Update nur `MARKETING_VERSION` in `project.yml` erhöhen; die Build-Nummer setzt der Workflow (100 + Laufnummer).

## Regeln
- Kommentare, UI-Texte, Commit-Nachrichten und PR-Beschreibungen auf Deutsch, verständlich ohne IT-Hintergrund.
- DSGVO hat Vorrang: keine Konten, keine Cloud, keine Dienste für Analyse, Werbung, Tracking oder Absturzberichte. Jeder neue Datenfluss nach außen nur nach Rückfrage – dann auch `docs/datenschutz.md`, `Hachibu/PrivacyInfo.xcprivacy` und die Datenschutzangaben in App Store Connect anpassen (`docs/app-store-connect.md`, Abschnitt 4).
- Das Repository ist öffentlich: keine Geheimnisse und keine privaten Daten committen – keine Telefonnummer, keine Zertifikate oder Schlüssel (`.p8`, `.p12`, `.mobileprovision`), keine Tokens. Der API-Schlüssel liegt nur in den GitHub-Secrets.
- Nie direkt auf `main` pushen: immer Branch und Pull Request; der CI-Lauf muss grün sein.
- Nie ändern: Bundle-ID `com.abdelkarim.hachibu` (Widget: `.widget`), URL-Schema `hachibu`, App Group `group.com.abdelkarim.hachibu`, Datenbankname `allahuma-diaet.db` samt Ordner `Documents/SQLite` (Nutzer verlören ihr Tagebuch), `apiClientName = "AllahumaDiaet"` in `AppInfo.swift`, die Dateinamen in `docs/`.
- Bestehende Migrationen (`schemaV1` bis `migrationV4` in `Migrations.swift`) nie bearbeiten. Neue Version: neues SQL, das am Ende `PRAGMA user_version` setzt, `latestVersion` erhöhen, eigener Schritt in `AppDatabase.migrate`, Test in `DatabaseTests.swift`.
- Grenzen nicht ohne Rückfrage lockern: Profil ab 18 Jahren, eigenes Tagesziel 1.200–5.000 kcal (App-Store-Richtlinie 1.4.1).
- Sprachmodus Swift 5 (`SWIFT_VERSION: "5.0"`) beibehalten; nicht auf Swift 6 umstellen, ohne den CI-Lauf abzuwarten.
- Bei Fragen zu SwiftUI, WidgetKit, GRDB oder xcodebuild zuerst Context7 nutzen (aktuelle Doku statt Trainingswissen).

## Stolperfallen
- Tests importieren `GRDB` nicht; sie gehen über `AppDatabase.openInMemory()` und `Repository`.
- Datumslogik rechnet mit `Calendar.current`; die Tests nutzen den festen Berliner Kalender `TestCalendar.berlin`. Zeitstempel in Tests mittags wählen, damit der Kalendertag in jeder Zeitzone des Runners gleich bleibt.
- Das Widget liest nie die Datenbank, nur `today.json` im App-Group-Ordner (`TodaySnapshot`); die App schreibt die Datei nach jeder Änderung und ruft `reloadAllTimelines` auf.
- Name und Anschrift stehen in `Hachibu/Legal/LegalInfo.swift`, `docs/impressum.md` und `docs/datenschutz.md` (dort auch „Stand:“), die E-Mail zusätzlich in `AppInfo.swift` und `docs/support.md` – immer alle zusammen ändern. Die App erreicht Nutzer erst mit einem neuen Build, `docs/` ist 1–2 Minuten nach dem Merge online.
- Nach außen gehen nur Barcode, Suchbegriff und die Abrufe der Produktbilder an Open Food Facts. Die Sicherungsdatei verlässt das Gerät nur, wenn der Nutzer sie selbst im Teilen-Menü weitergibt.
- Einheiten: Nährwerte pro 100 g, Mengen in Gramm, 1 ml = 1 g (`OpenFoodFacts.parseProduct`). Eingabefelder mit Komma (`Formatting.parseDecimal`, `Formatting.inputText`); `NumberFormat.jsRound` rundet wie die 1.0, damit alte Werte gleich bleiben.
- Zahlentastaturen haben keine Eingabetaste: `.keyboardDoneButton()` oder eine eigene „Fertig“-Taste je Screen, nie doppelt im selben Navigationsstapel.
- Das frühere Konto `abdelabu99-ai` wird nicht mehr benutzt; sein altes Repository nicht löschen, ohne vorher zu fragen.

## Verweise
- `README.md` – Workflows, Secrets für den Upload, Versionen, Ordnerübersicht
- `docs/app-store-connect.md` – Store-Einträge, Datenschutzangaben, Altersfreigabe, Prüfnotizen
- `docs/datenschutz.md`, `docs/impressum.md`, `docs/support.md` – die veröffentlichten Rechtstexte
