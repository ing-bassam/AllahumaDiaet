@AGENTS.md

# Hachibu (Repository AllahumaDiaet)

## Zweck
- Hachibu ist ein kostenloser Kalorien- und Nährwertzähler für Erwachsene, die ohne Konto, Werbung und Tracking zählen wollen; alle Tagebuchdaten bleiben in SQLite auf dem Gerät.
- Version 1.0 ist seit 05.10.2026 im deutschen App Store (nur iPhone), Android ist noch nicht veröffentlicht.

## Aufbau
- `src/app/` – Bildschirme (Expo Router); `_layout.tsx` öffnet die Datenbank und startet die Migration.
- `src/db/migrations.ts` – SQL je Schema-Version (aktuell v3); `schema.ts` führt sie aus, `repository.ts` enthält alle Abfragen.
- `src/lib/` – reine Logik ohne React Native; `tests/` lädt sie direkt unter Node (Einschränkungen siehe Stolperfallen).
- `src/legal/imprint.ts` – Impressum und Links zu den Rechtstexten, wie sie in der App erscheinen.
- `docs/` – Datenschutz, Impressum, Support; GitHub Pages veröffentlicht den Ordner von `main` unter https://ing-bassam.github.io/AllahumaDiaet/.
- `app.json`, `eas.json` – App-Konfiguration, Datenschutz-Manifest (`ios.privacyManifests`) und Build-Profile.

## Befehle (am 07.10.2026 unter Windows mit Node 24 ausgeführt; die Tests brauchen Node 24, weil sie `.ts` und `node:sqlite` direkt nutzen)
- Installieren: `npm ci`
- Testen: `npm test` (alle Tests müssen bestehen) und `npm run typecheck`
- Abhängigkeiten prüfen: `npx expo-doctor` – meldet am 07.10.2026 sechs kleine Versionsabweichungen (expo, expo-camera, expo-constants, expo-linking, expo-router, expo-sqlite)
- Abweichungen beheben: nur auf eigenem Branch `npx expo install --fix`, danach `npm run licenses`, `npm test` und ein neuer TestFlight-Build – nicht geprüft
- iOS-Paket probeweise erzeugen (ohne Upload): `npx expo export --platform ios` (Ausgabe in `dist/`, von Git ignoriert)
- Lizenzliste: `npm run licenses`, danach `src/legal/licenses.json` mitcommitten
- Icons und Startbild aus `assets/source/`: `npm run icons`
- Entwicklungsserver: `npx expo start --go` – nicht `npm start` oder `npm run ios`, die ohne `--go` einen Development Build erwarten (Metro startet; der Test in Expo Go auf dem Handy ist nicht geprüft)
- Build für den App Store: `eas build --platform ios --profile production` – nicht geprüft (verbraucht Build-Kontingent, braucht Apple-Login)
- Hochladen zu App Store Connect: `eas submit --platform ios --profile production --latest` – nicht geprüft

## Regeln
- Kommentare, UI-Texte, Commit-Nachrichten und PR-Beschreibungen auf Deutsch, verständlich ohne IT-Hintergrund.
- DSGVO hat Vorrang: keine Konten, keine Cloud, keine Dienste für Analyse, Werbung, Tracking oder Absturzberichte. Jeder neue Datenfluss nach außen nur nach Rückfrage – dann auch `docs/datenschutz.md`, `ios.privacyManifests` in `app.json` und die Datenschutzangaben in App Store Connect anpassen (Checkliste: `docs/app-store-connect.md`, Abschnitt 4).
- Das Repository ist öffentlich: keine Geheimnisse und keine privaten Daten committen – keine Telefonnummer, keine Zertifikate oder Schlüssel (`.p8`, `.p12`, `.mobileprovision`), keine Tokens.
- Nie direkt auf `main` pushen (der Branch ist technisch nicht geschützt): immer Branch und Pull Request; vor jedem Commit `npm test` und `npm run typecheck`.
- Nie ändern: Bundle-ID und Android-Paketname `com.abdelkarim.hachibu`, `slug`, `scheme`, `extra.eas.projectId` (`app.json`), `ascAppId` (`eas.json`), den Datenbanknamen `allahuma-diaet.db` (Nutzer verlören ihr Tagebuch), `API_CLIENT_NAME = 'AllahumaDiaet'` in `src/appInfo.ts` und die Dateinamen `docs/datenschutz.md`, `docs/impressum.md`, `docs/support.md` (ihre Adressen stecken in der App und in App Store Connect).
- Bestehende Migrationen (`SCHEMA_V1_SQL` bis `MIGRATION_V3_SQL`) nie bearbeiten. Eine neue Version braucht: neues SQL, das am Ende `PRAGMA user_version` selbst setzt, `LATEST_DATABASE_VERSION` erhöhen, einen eigenen Schritt in `src/db/schema.ts` mit `withExclusiveTransactionAsync` und einen Test in `tests/migrations.test.ts`.
- Grenzen der Berechnung nicht ohne Rückfrage lockern: Profil ab 18 Jahren, eigenes Tagesziel 1.200–5.000 kcal (App-Store-Richtlinie 1.4.1).
- Bei Fragen zu Bibliotheken und Frameworks zuerst Context7 nutzen (aktuelle Doku statt Trainingswissen).

## Stolperfallen
- Kein Mac: iOS wird nur mit EAS in der Cloud gebaut und per TestFlight auf dem eigenen iPhone getestet.
- Für ein Update nur `version` in `app.json` erhöhen, nie `buildNumber` oder `versionCode` (Begründung: README, Abschnitt „Versionen“).
- Name und Anschrift stehen in `src/legal/imprint.ts`, `docs/impressum.md` und `docs/datenschutz.md` (dort auch „Stand:“ anpassen), die E-Mail-Adresse zusätzlich in `src/appInfo.ts` und `docs/support.md` – immer alle zusammen ändern. `imprint.ts` erreicht Nutzer erst mit einem neuen Build, `docs/` ist 1–2 Minuten nach dem Merge online.
- Nach außen gehen Barcode, Suchbegriff und die Abrufe der Produktbilder an Open Food Facts; unter Android sendet die Barcode-Erkennung (Google ML Kit) zusätzlich Diagnosedaten an Google (`docs/datenschutz.md`, Abschnitt 4).
- `src/lib/*` und `src/db/migrations.ts`: nichts aus `react-native` oder `expo-*` importieren, untereinander mit Endung `.ts` importieren, kein `enum` und kein `namespace` – sonst brechen die Node-Tests, auch wenn `npm run typecheck` grün ist.
- Datumslogik rechnet in lokaler Zeit (`src/lib/date.ts`). Nach Änderungen daran in PowerShell zusätzlich `$env:TZ='UTC'; npm test` und `$env:TZ='Pacific/Auckland'; npm test`, danach `Remove-Item Env:TZ`. Git Bash gibt `TZ=Pacific/Auckland` nicht an Node weiter, der Test läuft dann unbemerkt in deutscher Zeit.
- Einheiten: Nährwerte gelten pro 100 g, Mengen sind immer Gramm. Getränke werden mit 1 ml = 1 g gerechnet (`parseProduct` in `src/lib/openFoodFacts.ts`); eine echte Umrechnung gibt es nicht.
- Zahlen in Eingabefeldern: Komma als Dezimalzeichen, kein Tausenderpunkt (`toInputText`, `parseDecimal`).
- Windows: Git wandelt Zeilenenden um; `licenses.json` erscheint dadurch geändert, ohne es zu sein – mit `git diff --ignore-cr-at-eol` prüfen.
- Das Repository auf GitHub ist `ing-bassam/AllahumaDiaet`. Das frühere Konto `abdelabu99-ai` wird nicht mehr benutzt, seine alten Rechtsseiten sind aber noch online – das alte Repository nicht löschen, ohne vorher zu fragen.
- README, Abschnitt „ascAppId eintragen“, ist veraltet: Die ID `6816385956` steht schon in `eas.json`.

## Verweise
- `README.md` – Einrichtung, Test mit Expo Go, Veröffentlichen mit EAS
- `docs/app-store-connect.md` – Store-Einträge, Datenschutzangaben, Altersfreigabe, Prüfnotizen
- `docs/datenschutz.md`, `docs/impressum.md`, `docs/support.md` – die veröffentlichten Rechtstexte
