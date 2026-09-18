# Hachibu

Kalorientracker-App für iPhone und Android nach dem Prinzip „Scan & Go“: öffnen, Barcode scannen, Menge eintippen, fertig.

- Keine Werbung, kein Konto, keine Cloud: Alle Daten bleiben auf dem Gerät (SQLite).
- Produktdaten kommen von [Open Food Facts](https://world.openfoodfacts.org) (ODbL). Unbekannte Produkte werden einmalig manuell erfasst und lokal gespeichert.
- Alternativ zum Scanner: Suche mit „Zuletzt verwendet“, „Häufig gegessen“, lokalen Treffern, Online-Suche (nur beim Absenden, unter dem Rate Limit von Open Food Facts) und eigenen Lebensmitteln ohne Barcode.
- Nährwerte lassen sich pro Produkt korrigieren; jeder Tagebucheintrag speichert einen eigenen Nährwert-Schnappschuss und kann einzeln bearbeitet werden.
- Kalorienziel nach Mifflin-St. Jeor × PAL-Faktor, Makroverteilung frei einstellbar (Standard 50 % KH / 30 % Protein / 20 % Fett).

## Auf dem Handy testen

1. Die App **Expo Go** installieren ([iOS](https://apps.apple.com/app/expo-go/id982107779) / [Android](https://play.google.com/store/apps/details?id=host.exp.exponent)).
2. Im Projektordner:

   ```bash
   npm install
   npx expo start --go
   ```

   `--go` ist nötig, weil das Projekt `expo-dev-client` enthält und `expo start` sonst einen Development Build erwartet.

3. Den QR-Code im Terminal scannen – auf dem iPhone mit der Kamera-App, auf Android in Expo Go.
   Handy und PC müssen im selben WLAN sein. Klappt das nicht, `npx expo start --go --tunnel` verwenden.

## Marke

Die Vorlagen liegen in `assets/source/`: `icon.png` (Zeichen „H.“ auf Creme `#F7F6F3`) und `wordmark.png` (Schriftzug „Hachibu.“, transparent).
`npm run icons` erzeugt daraus alle App-Icons und das Startbild und prüft Größe, Farbmodus, Alphakanal und die Android-Safe-Zone.
Neue Vorlagen einfach dort ersetzen und das Skript erneut ausführen.

## Entwicklung

```bash
npm test          # Rechenlogik, Barcode- und API-Parsing
npm run typecheck # TypeScript
```

| Ordner | Inhalt |
| --- | --- |
| `src/app` | Screens (Expo Router): Dashboard, Profil, Scanner, Produkt eintragen |
| `src/db` | SQLite-Schema und Abfragen |
| `src/lib` | Reine Logik: Nährwerte, Barcodes, Open Food Facts, Formatierung |
| `src/components` | UI-Bausteine |
| `src/legal` | Impressum, rechtliche Links, generierte Lizenzliste |
| `tests` | Tests mit dem eingebauten Node-Testrunner |
| `scripts` | `npm run icons` (Icons und Startbild aus `assets/source/`), `npm run licenses` (Lizenzliste) |
| `docs` | Datenschutz, Impressum, Support (GitHub Pages) und die App-Store-Connect-Checkliste |

Nach dem Hinzufügen oder Aktualisieren von Paketen `npm run licenses` ausführen, damit die Liste unter *Info & Rechtliches* aktuell bleibt.

## Veröffentlichen

Gebaut und hochgeladen wird mit [EAS](https://docs.expo.dev/eas/) in der Cloud – ein Mac ist nicht nötig.
Die Profile stehen in `eas.json`:

| Profil | Zweck |
| --- | --- |
| `development` | Development Build mit `expo-dev-client` zum Testen nativer Änderungen, interne Verteilung |
| `preview` | Release-Build zum Testen auf registrierten Geräten, interne Verteilung |
| `production` | Build für den App Store; die Build-Nummer wird automatisch erhöht |

### Versionen

- **Sichtbare Version** (`1.0.0`): steht in `app.json` unter `version` und wird für jedes Update von Hand erhöht.
- **Build-Nummer**: verwaltet EAS auf seinen Servern (`cli.appVersionSource: "remote"`), das Profil `production` erhöht sie bei jedem Build automatisch (`autoIncrement`). Ein `ios.buildNumber` oder `android.versionCode` in `app.json` wird deshalb **ignoriert** – bitte dort nicht eintragen.

### Befehle in Reihenfolge

```bash
# 1. EAS CLI installieren und anmelden (einmalig)
npm install -g eas-cli
eas login

# 2. Projekt bei Expo anlegen; trägt extra.eas.projectId in app.json ein (danach slug nicht mehr ändern)
eas init

# 3. Nur falls eas.json fehlt: erzeugt die Datei. Hier liegt sie schon im Repository, der Schritt entfällt.
eas build:configure

# 4. Optional: letzte Build-Nummer übernehmen, falls die App schon einmal ohne EAS hochgeladen wurde
eas build:version:set --platform ios

# 5. Build für den App Store in der Cloud erstellen
eas build --platform ios --profile production

# 6. ascAppId in eas.json eintragen (siehe unten), dann zu App Store Connect hochladen
eas submit --platform ios --profile production
```

Beim ersten Build fragt EAS nach dem Apple-Konto und erstellt Zertifikat und Provisioning Profile selbst. Nichts davon gehört ins Repository.

**`ascAppId` eintragen:** In `eas.json` steht unter `submit.production.ios.ascAppId` der Platzhalter `TODO_ASC_APP_ID`. Nachdem die App in App Store Connect angelegt ist, dort unter *App-Informationen → Apple-ID* die Nummer ablesen (nur Ziffern) und den Platzhalter damit ersetzen. Bis dahin fragt bzw. scheitert `eas submit`.

### Auf eigenen Geräten testen (optional)

```bash
eas device:create
eas build --platform ios --profile preview
```

iPhones müssen für interne Builds vorher mit `eas device:create` registriert werden.

Weitere Schritte außerhalb des Codes (Datenschutzangaben, Screenshots, Altersfreigabe …) stehen in [`docs/app-store-connect.md`](docs/app-store-connect.md).
