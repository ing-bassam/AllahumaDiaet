# App Store Connect – Checkliste für Hachibu

> **Arbeitsdokument, keine Rechtsberatung.** Wird nicht über GitHub Pages veröffentlicht (`_config.yml` → `exclude`).
> Alle offenen Punkte sind mit TODO markiert. Stand der Apple-Vorgaben: 15.09.2026 – vor dem Einreichen in App Store Connect gegenprüfen.

Reihenfolge ungefähr so, wie die Schritte aufeinander aufbauen.

## 0. Update auf Version 2.0 (SwiftUI, Oktober 2026)

Version 1.0 (Build 6) ist seit 05.10.2026 im Store. Version 2.0 ist dieselbe App (gleiche Apple-ID, gleiche Bundle-ID, gleiche Datenbank), neu geschrieben in SwiftUI. Was für das Update in App Store Connect zu tun ist:

- [ ] Build hochladen: GitHub → *Actions → „App Store Upload“ → Run workflow* (Secrets vorher anlegen, siehe README). Der Build erscheint in TestFlight; dort auf dem eigenen iPhone testen – besonders, ob das Tagebuch aus 1.0 erhalten bleibt.
- [ ] *Apps → Hachibu → „+“ neben iOS-App* → Version `2.0.0` anlegen, den Build zuordnen.
- [ ] **Neue Screenshots** (Abschnitt 8): Die Oberfläche sieht komplett anders aus, die alten Bilder passen nicht mehr. Mindestens: Tagebuch, Scanner, Eintragen, Suche, Verlauf, Widget auf dem Homescreen.
- [ ] Text „Neue Funktionen in dieser Version“ (Abschnitt 10, Entwurf dort).
- [ ] Beschreibung und Keywords prüfen (Abschnitt 10, aktualisiert um Widgets, Favoriten, Schnelleintrag, Verlauf, Datensicherung).
- [ ] Datenschutzangaben (Abschnitt 4) bleiben inhaltlich gleich; die Datensicherung ist keine Erfassung, weil nur der Nutzer die Datei weitergibt. Datenschutzerklärung ist unter derselben URL aktualisiert (Stand 08.10.2026).
- [ ] Altersfreigabe bleibt unverändert.
- [ ] Prüfnotizen (Abschnitt 9) wurden an die neuen Tabs angepasst – beim Einreichen den aktuellen Text einfügen.
- Android ist mit 2.0 endgültig vom Tisch (SwiftUI läuft nur auf Apple-Geräten); Abschnitt 12 entfällt.

## 1. Apple Developer Program

- [x] Mitgliedschaft im [Apple Developer Program](https://developer.apple.com/programs/) ist bezahlt (deine Angabe, 17.09.2026).
- [ ] Kontotyp im [Developer-Portal](https://developer.apple.com/account) unter *Membership details* nachsehen:
  - **Einzelperson (Individual):** Anbietername im App Store ist dein eigener Name, also Karim Abu Elkheir. So ist Hachibu geplant.
  - **Organisation:** nur mit eingetragener Rechtsform und D-U-N-S-Nummer möglich. Ein Wechsel ist später nur über den Apple-Support möglich, deshalb jetzt bewusst entscheiden.
- [ ] Zwei-Faktor-Authentifizierung für die Apple-ID aktiv.

## 2. App in App Store Connect anlegen

- [x] *Apps → + → Neue App* – angelegt am 26.09.2026, Apple-ID **6816385956**
  - Plattform: iOS
  - Name (App-Store-Name, max. 30 Zeichen): **Hachibu – Kalorienzähler**, siehe *2a. Namensprüfung*. Auf dem Homescreen steht weiter **Hachibu** (`project.yml` → `CFBundleDisplayName`).
  - Primäre Sprache: Deutsch
  - Bundle-ID: **com.abdelkarim.hachibu** (`project.yml` → `PRODUCT_BUNDLE_IDENTIFIER`; existiert seit Version 1.0). **Nach dem ersten Upload nicht mehr änderbar**, siehe *2b. Bundle-ID*.
  - SKU: frei wählbar, z. B. `hachibu-ios`
  - Benutzerzugriff: Vollzugriff
- [x] Apple-ID `6816385956` steht in `Hachibu/App/AppInfo.swift` (`appStoreId`, für den Bewertungslink in der App).
- [ ] Kategorie: **Gesundheit & Fitness** (primär). Sekundär optional, z. B. *Essen & Trinken*.
- [ ] Copyright: `2026 Karim Abu Elkheir` <!-- TODO: bestätigen -->

## 2a. Namensprüfung (Stand 17.09.2026)

- App-Store-Namen sind weltweit eindeutig. Ist ein Name vergeben, lässt App Store Connect ihn nicht mehr reservieren; Groß- und Kleinschreibung macht dabei keinen Unterschied.
- Geprüft über die öffentliche Suchschnittstelle von Apple (`https://itunes.apple.com/search?term=hachibu&entity=software`, Storefronts Deutschland und USA): **kein Treffer**. „Hachibu“ ist als App-Store-Name frei.
- **Nachtrag 26.09.2026:** Beim Anlegen meldete App Store Connect „Hachibu“ als bereits verwendet. Es gibt keine veröffentlichte App dieses Namens – jemand hat ihn reserviert, ohne zu veröffentlichen. Solche Reservierungen sind über die Suchschnittstelle nicht sichtbar; die Prüfung oben war deshalb unvollständig.
- Store-Name deshalb: **`Hachibu – Kalorienzähler`** (24 von 30 Zeichen). Auf dem Homescreen bleibt `Hachibu`. Guideline 2.3.8 ist erfüllt, weil der Gerätename im Store-Namen steckt; 2.3.7 ebenfalls, weil es ein einziger beschreibender Zusatz ist.
- Untertitel: `Barcode scannen, ohne Konto` – „Kalorien“ steht schon im Namen.
- Vorgeschichte: Der frühere Arbeitsname „Halabi“ war im App Store schon von einer anderen App belegt (Anbieter Yaseen Halabi, Social Networking). Das war der Anlass für den Wechsel auf Hachibu.
- [ ] Markenrecherche vor dem Anlegen: [DPMAregister](https://register.dpma.de/DPMAregister/marke/experte), [EUIPO eSearch](https://euipo.europa.eu/eSearch/) und [TMview](https://www.tmdn.org/tmview/) nach „Hachibu“ in Klasse 9 (Software) und 42/44 durchsuchen. Als Fantasiewort ist das Risiko geringer als bei einem Familiennamen, aber die Prüfung bleibt nötig: Bei einer Markenbeschwerde entfernt Apple die App. Die Register lassen sich nur von Hand durchsuchen, und die Bewertung des Ergebnisses ist Rechtsberatung.

## 2b. Bundle-ID (Entscheidung, die bleibt)

- Die Bundle-ID entsteht beim ersten Build und ist danach **dauerhaft**: Sie lässt sich für eine eingereichte App nicht mehr ändern. Ein anderer Wert bedeutet später eine neue App mit neuer Apple-ID – bestehende Installationen bekommen dann keine Updates. Für Android gilt dasselbe für `android.package` ab der ersten Veröffentlichung.
- [x] **Entschieden am 17.09.2026:** `com.abdelkarim.hachibu`. Der alte Wert `com.abdelkarim.allahumadiaet` stammte aus dem früheren Projektnamen und wurde ersetzt, solange noch kein Build hochgeladen war.
- Seit Version 2.0 steht der Wert in `project.yml`; das Widget hat die abgeleitete ID `com.abdelkarim.hachibu.widget` und die App Group heißt `group.com.abdelkarim.hachibu`. Alle drei bleiben unverändert.

## 3. URLs

Die Seiten liegen im Ordner `docs/` und werden über GitHub Pages veröffentlicht.

- [ ] Alle TODOs in `docs/datenschutz.md`, `docs/impressum.md` und `docs/support.md` klären und entfernen.
- [x] GitHub Pages ist für `ing-bassam/AllahumaDiaet` eingeschaltet (Branch `main`, Ordner `/docs`; Repository dafür am 26.09.2026 auf öffentlich gestellt). Jede Änderung in `docs/` auf `main` ist nach ein bis zwei Minuten online.
- [ ] Nach dem Merge prüfen, ob die Seiten erreichbar sind:
  - Datenschutz-URL: `https://ing-bassam.github.io/AllahumaDiaet/datenschutz.html`
  - Support-URL: `https://ing-bassam.github.io/AllahumaDiaet/support.html`
  - Impressum: `https://ing-bassam.github.io/AllahumaDiaet/impressum.html`
- Die alten Adressen unter `abdelabu99-ai.github.io` bleiben erreichbar, bis das alte Konto abgeschaltet wird; sie werden nirgends mehr genannt.
- [ ] Datenschutz-URL unter *App-Datenschutz* und Support-URL in der Versionsseite eintragen. Beide sind für jede App Pflicht. Laut Apple muss die Support-URL zu echten Kontaktinformationen führen.
- [ ] Die gleichen URLs sind in der App hinterlegt (`Hachibu/Legal/LegalInfo.swift`). Ändern sie sich, dort anpassen.

## 4. App-Datenschutzangaben („Privacy Nutrition Label“)

### Vorschlag: „Keine Daten erfasst“

Apple definiert „erfassen“ (collect) als: Daten verlassen das Gerät so, dass du **oder deine Drittanbieter-Partner** länger darauf zugreifen können, als für die Beantwortung der Anfrage in Echtzeit nötig ist.

Warum „Keine Daten erfasst“ in Frage kommt:

- Profil, Gewicht, Tagebuch und selbst angelegte Produkte werden nur lokal in SQLite gespeichert. Es gibt keinen eigenen Server.
- Keine Analyse-, Werbe-, Tracking- oder Crash-Reporting-SDKs. Einzige Fremdbibliothek ist GRDB.swift für SQLite (siehe `project.yml`).
- Barcode-Erkennung läuft vollständig auf dem Gerät (AVFoundation).
- Das Privacy Manifest (`Hachibu/PrivacyInfo.xcprivacy`) meldet `NSPrivacyTracking: false` und keine erfassten Datentypen.
- Widget-Daten liegen in der App Group auf dem Gerät; die Datensicherung (ab 2.0) verlässt das Gerät nur über das Teilen-Menü auf Wunsch des Nutzers. Beides ist keine Erfassung durch den Anbieter.

**Wichtiger Vorbehalt – Open Food Facts:**
Beim Scannen gehen der Barcode und die IP-Adresse an die Open-Food-Facts-API, bei der **Online-Suche der eingegebene Suchbegriff** und die IP-Adresse an deren Suchdienst (search.openfoodfacts.org), beim Anzeigen von Produktbildern die IP-Adresse an deren Bildserver. Open Food Facts speichert IP-Adressen nach eigener Datenschutzerklärung in Server-Logs (dort angegeben: 3 Jahre, für Sicherheit, technische Analysen und Statistik).

- Open Food Facts ist eine öffentliche Datenbank, deren Code nicht in der App steckt. Ob Apple sie als „Drittanbieter-Partner“ wertet, ist nicht eindeutig.
- Für IP-Adressen sagt Apple: je nach Verwendung als *Grobe Position*, *Geräte-ID* oder *Diagnose* angeben.
- **Suchbegriffe** fallen ziemlich direkt unter Apples Datentyp *Suchverlauf* („Informationen über Suchen in der App“). Seit es die Online-Suche gibt, ist „Keine Daten erfasst“ deshalb schwerer zu begründen als vorher, als nur Barcodes übertragen wurden.
- Die lokale Suche, „Zuletzt verwendet“ und „Häufig gegessen“ bleiben auf dem Gerät und sind keine Erfassung.

- [ ] Entscheiden. **Empfehlung: „Suchverlauf“ angeben** – nicht mit der Identität verknüpft, nicht für Tracking, Zweck „App-Funktionalität“. Das ist die vorsichtigere Variante und passt zu Abschnitt 5a der Datenschutzerklärung. Eine zu knappe Angabe ist ein häufiger Ablehnungsgrund nach Guideline 5.1.2, eine zu vorsichtige nicht.
- [ ] Angaben und Datenschutzerklärung müssen dasselbe sagen. Wird eine Stelle geändert, die andere mitziehen.

## 5. Altersfreigabe

- [ ] Fragebogen unter *App-Informationen → Altersfreigabe* ausfüllen. Voraussichtliche Antworten:
  - Nutzergenerierte Inhalte, Messaging/Chat, soziale Medien, Werbung, uneingeschränkter Webzugriff: **Nein**
  - Glücksspiel, Wettbewerbe, Lootboxen: **Keine**
  - Gewalt, Sexualität, Horror, Alkohol/Tabak/Drogen, Obszönitäten: **Keine**
  - **Gesundheits- oder Wellness-Themen:** Apple nennt ausdrücklich „Calorie tracking, dieting advice, or exercise recommendations“. Kalorien-Tracking ist die Kernfunktion → nicht „Keine“ angeben.
  - Medizinische oder Behandlungsinformationen: **Keine** (die App gibt keine Diagnosen, Medikamenten- oder Behandlungshinweise).
- [ ] Ergebnis prüfen. Nach Apples Tabelle führen Gesundheits-/Wellness-Themen voraussichtlich zu mindestens **13+**. <!-- TODO: tatsächliche Einstufung nach dem Ausfüllen notieren. -->
- Passt zur App: Die Berechnung ist ohnehin erst ab 18 Jahren freigegeben (`Nutrition.ageRange` in `Hachibu/Logic/Nutrition.swift`).

## 6. EU-Händlerstatus (Digital Services Act)

Pflicht für jedes Konto, auch ohne Verkauf in der EU: *Business → Vereinbarungen → Compliance → Digital Services Act*.

**Was „Händler“ (Trader) bedeutet:** Wer im Zusammenhang mit seiner gewerblichen, geschäftlichen, handwerklichen oder beruflichen Tätigkeit handelt. Indizien laut EU-Kommission bzw. Apple:

- Einnahmen mit der App (Kaufpreis, In-App-Käufe, Werbung), besonders in größerem Umfang
- Werbung für eigene Produkte oder Dienstleistungen
- Umsatzsteuer-Registrierung
- Entwicklung im Rahmen des eigenen Berufs oder Unternehmens

Eher **kein** Händler: Hobby-Entwickler ohne Absicht, mit der App Geld zu verdienen.

**Folgen:**

- **Als Händler** müssen Anschrift (oder Postfach), Telefonnummer und E-Mail angegeben und von Apple verifiziert werden (Zwei-Faktor-Bestätigung, bei Einzelpersonen ggf. Nachweisdokumente). Apple **veröffentlicht Anschrift, Telefonnummer und E-Mail auf der App-Store-Seite** in allen 27 EU-Ländern.
- **Als Nicht-Händler** werden keine Kontaktdaten veröffentlicht. EU-Kunden wird angezeigt, dass Verbraucherschutzrechte gegenüber dir nicht gelten.
- Der Status lässt sich pro App ändern: *App-Informationen → App Store Regulations and Permits → Digital Services Act*.

**Wichtig, falls Händlerstatus:** Für die veröffentlichte Anschrift akzeptiert Apple auch ein **Postfach**. Deine Wohnadresse muss also nicht auf der App-Store-Seite stehen. Apple selbst braucht trotzdem verifizierbare Daten; Telefonnummer und E-Mail werden per Code bestätigt und bei Händlerstatus mitveröffentlicht.

- [ ] Angabe im Dashboard machen. Ohne Händlerangabe bietet Apple Apps in den EU-Storefronts nicht an – das gilt unabhängig davon, wie die Antwort ausfällt.

<!-- TODO (Einschätzung durch dich, ggf. mit rechtlicher Beratung): Hachibu ist kostenlos, werbefrei, ohne In-App-Käufe und ohne Einnahmen – das spricht gegen Händlerstatus. Apple darf den Status nicht für dich bestimmen. -->

## 7. Häufige Ablehnungsgründe und wie Hachibu sie abdeckt

### Guideline 4.3(a) – Spam in einer überfüllten Kategorie

Kalorienzähler gibt es hunderte. Apple lehnt Apps ab, die sich von vorhandenen kaum unterscheiden, und besonders Apps aus Baukästen oder Vorlagen. Was Hachibu unterscheidet und was deshalb in Beschreibung und Prüfnotizen gehört:

- Kein Konto, keine Anmeldung, kein Abo, keine In-App-Käufe, keine Werbung, kein Tracking – bei den großen Anbietern fast immer anders.
- Alle Daten liegen in einer lokalen SQLite-Datenbank, es gibt keinen Server des Anbieters.
- Einmal gescannte Produkte funktionieren danach offline weiter, inklusive eigener Korrekturen der Nährwerte.
- Deutschsprachige Oberfläche und deutsche Produktdaten aus Open Food Facts.
- Eigener Code, keine Vorlage, keine zweite ähnliche App im Konto.

### Guideline 1.4.1 – Gesundheit: Berechnungen brauchen belegte Quellen

Apple verlangt für Apps, die Gesundheitswerte berechnen, nachvollziehbare medizinische Grundlagen. Das ist abgedeckt:

- `CalculationInfo` in `Hachibu/Legal/LegalInfo.swift` enthält den Rechenweg in fünf Schritten und vier Quellen: Mifflin-St Jeor (Am J Clin Nutr 1990), PAL-Faktoren der Deutschen Gesellschaft für Ernährung, S3-Leitlinie Adipositas (AWMF 050-001) für das Defizit, Verordnung (EU) 1169/2011 Anhang XIV für 4/4/9 kcal je Gramm.
- In der App sichtbar unter *Info & Rechtliches → Berechnung & Quellen* mit Links, außerdem beim Anlegen des Profils.
- Der Hinweis „Richtwerte für gesunde Erwachsene, ersetzt keine ärztliche oder ernährungsfachliche Beratung“ steht an beiden Stellen.
- Keine Diagnosen, keine Behandlungs- oder Medikamentenhinweise, keine Messung von Vitalwerten.
- Das Profil ist erst ab 18 Jahren möglich (`Nutrition.ageRange` in `Hachibu/Logic/Nutrition.swift`), damit keine Kalorienziele für Kinder und Jugendliche berechnet werden.

### Metadaten und Berechtigungen

- [ ] Berechtigungstext prüfen: `NSCameraUsageDescription` steht in `project.yml` und lautet „Die Kamera wird nur zum Scannen von Barcodes auf Lebensmitteln verwendet.“ Ein Text, der den Zweck nicht erklärt, ist ein klassischer Ablehnungsgrund (Guideline 5.1.1). Mikrofon, Fotos oder Standort fragt die App nie ab, dafür gibt es keine Texte.
- [ ] Screenshots ohne echte persönliche Daten, ohne Gerätrahmen mit fremden Marken und ohne Text, der im Store-Text nichts verspricht.
- [ ] Keine Heilversprechen, keine Vergleiche mit anderen Apps, kein „Beta“, kein „Demo“, keine Platzhaltertexte in Store-Texten und in der App.
- [ ] Support- und Datenschutz-URL müssen erreichbar sein, bevor du einreichst. Eine 404-Seite führt zuverlässig zur Ablehnung – GitHub Pages also vorher aktivieren.

## 8. Screenshots

Anforderungen laut Apple (Stand siehe oben):

- 1 bis 10 Screenshots pro Displaygröße, Format `.png` oder `.jpg`, **ohne Alphakanal/Transparenz**.
- **Pflicht:** Screenshots für das **6,5"-Display** (1284 × 2778 px Hochformat), sofern keine 6,9"-Screenshots geliefert werden. Einfacher: direkt **6,9"** liefern (1320 × 2868, 1290 × 2796 oder 1260 × 2736 px) – die kleineren Größen skaliert Apple dann herunter.
- iPad-Screenshots sind nicht nötig, weil `TARGETED_DEVICE_FAMILY: "1"` (nur iPhone) in `project.yml` steht.

Vorschlag für 6–8 Motive (Version 2.0): Tagebuch mit Kalorienring · Scanner · Eintragen mit Mengeneingabe · Suche mit Favoriten und „Zuletzt verwendet“ · Verlauf mit Wochenübersicht und Gewicht · Widget auf dem Homescreen · Profil mit Tagesziel · Datensicherung.
<!-- TODO: Screenshots für 2.0 mit Beispieldaten vom eigenen iPhone (TestFlight-Build) erstellen; Bildschirmfotos des iPhone 15 Pro Max/16 Pro Max haben bereits 1290 × 2796 px. Keine echten persönlichen Daten zeigen. -->

## 9. Notizen für die App-Prüfung

Unter *Versionsinformationen → App Review Information → Notizen* einfügen:

```text
Hachibu ist ein Kalorien- und Makrotracker nach dem Prinzip „Scannen und eintragen“.

- Kein Login erforderlich, keine Konten, keine In-App-Käufe, keine Werbung.
- Alle Nutzerdaten werden ausschließlich lokal auf dem Gerät gespeichert (SQLite).
- Beim ersten Start wird ein Profil (Alter, Größe, Gewicht, Aktivität) abgefragt, um ein Kalorienziel zu berechnen.
- Produktdaten werden über die öffentliche Open-Food-Facts-API anhand des Barcodes abgefragt.

Testen ohne Lebensmittel zur Hand:

Variante A – Nummerneingabe:
Auf dem Startbildschirm „Scannen“ antippen und im Scanner unten „Nummer eintippen“ wählen. Eine der folgenden Barcode-Nummern eingeben:

1. 4000417025005 – Ritter Sport Marzipan
2. 8076800195057 – Barilla Spaghetti Nº5
3. 4001724819806 – Dr. Oetker Ristorante Pizza Mozzarella

Anschließend eine Menge in Gramm eingeben und „Speichern“ antippen.

Variante B – Suche:
Auf dem Startbildschirm die Lupe links neben „Scannen“ antippen, z. B. „Spaghetti“ eingeben und „Online suchen“ antippen. Ein Ergebnis auswählen, Menge eingeben, speichern. Ohne Eingabe zeigt die Suche zuletzt verwendete Lebensmittel.

Weitere Funktionen:
- Unbekannte Barcodes führen zu einem Formular, in dem Nährwerte einmalig manuell erfasst werden.
- Ein Eintrag im Tagebuch lässt sich antippen und bearbeiten (Menge, Mahlzeit, Nährwerte).
- „+“ rechts neben „Scannen“ öffnet den Schnelleintrag (nur Kalorien, z. B. im Restaurant).
- In der Suche kann über „… als eigenes Lebensmittel anlegen“ ein Lebensmittel ohne Barcode angelegt werden; der Stern im Produkt-Screen markiert Favoriten.
- Hat der Vortag Einträge, bietet das Tagebuch unter „Wie gestern eintragen“ an, fehlende Mahlzeiten zu übernehmen.
- Tab „Verlauf“: Kalorien der letzten sieben Tage und Gewichtsverlauf (Gewicht über „Gewicht eintragen“).
- Tab „Mehr“: Profil, Datensicherung (JSON-Datei und CSV über das Teilen-Menü, Einlesen über die Dateiauswahl), Info & Rechtliches.
- Widgets (klein, mittel, Sperrbildschirm) zeigen die übrigen Kalorien; Tippen öffnet den Scanner (URL-Schema hachibu://scan).

Die Kamera-Berechtigung wird nur für das Scannen von Barcodes verwendet.
Daten löschen: Tab „Mehr“ → „Alle Daten löschen“.

Berechnung des Kalorienziels (zu Guideline 1.4.1):
- Grundumsatz nach Mifflin-St Jeor, Am J Clin Nutr 1990;51:241-247 (doi:10.1093/ajcn/51.2.241)
- Gesamtumsatz über die PAL-Faktoren der Deutschen Gesellschaft für Ernährung
- Defizit 500 kcal beim Abnehmen, Überschuss 300 kcal beim Zunehmen, nie unter dem Grundumsatz
- Optional ein eigenes Tagesziel, begrenzt auf 1.200 bis 5.000 kcal; liegt es unter dem Grundumsatz,
  zeigt die App einen sichtbaren Hinweis auf ärztliche oder ernährungsfachliche Beratung
- Makronährstoffe mit 4/4/9 kcal je Gramm nach Verordnung (EU) 1169/2011 Anhang XIV

Methode und Quellen sind in der App sichtbar: Tab „Mehr“ → „Info & Rechtliches“ → „Berechnung & Quellen“,
außerdem beim Anlegen des Profils. Die App stellt keine Diagnosen und gibt keine
Behandlungsempfehlungen. Ein Hinweis auf ärztliche Beratung ist an beiden Stellen sichtbar.
Ein Profil ist erst ab 18 Jahren möglich.
```

Die drei Barcodes wurden am 15.09.2026 (zweimal) über die Open-Food-Facts-API mit der App-eigenen Funktion `fetchProduct`/`parseProduct` geprüft; alle lieferten `status: found` mit vollständigen Nährwerten. Open Food Facts wird von Freiwilligen gepflegt – vor dem Einreichen kurz in der App gegenprüfen.

- [ ] Kontaktdaten für die App-Prüfung (Name, Telefon, E-Mail) ausfüllen. Diese sind nur für Apple sichtbar.
- [ ] Anmeldung erforderlich: **Nein**.

## 10. Store-Texte (Entwurf, Deutsch)

Ohne Heilversprechen und ohne medizinische Aussagen.

**Name** (max. 30 Zeichen, 24 genutzt): `Hachibu – Kalorienzähler`

**Untertitel** (max. 30 Zeichen, 27 genutzt): `Barcode scannen, ohne Konto`

**Keywords** (max. 100 Bytes, Umlaute zählen doppelt; 92 Bytes genutzt):

```text
Kalorien,zählen,Makros,Scanner,Ernährung,Protein,Nährwerte,Lebensmittel,Diät,Tracker,EAN
```

Apple sucht auch in Name und Untertitel. „Kalorienzähler“, „Barcode“, „scannen“ und „Konto“ stehen deshalb nicht in den Keywords. „Kalorien“ und „zählen“ stehen einzeln drin, damit auch getrennte Suchen wie „Kalorien zählen“ greifen.

**Werbetext** (optional, max. 170 Zeichen):

```text
Barcode scannen, Menge eintippen, fertig: Kalorien und Makros in Sekunden erfassen – ohne Konto, ohne Werbung.
```

**Beschreibung** (max. 4000 Zeichen):

```text
Hachibu macht das Erfassen von Kalorien und Makronährstoffen so schnell wie möglich: App öffnen, Barcode scannen, Menge eintippen, speichern. Mehr nicht.

SCANNEN UND EINTRAGEN
• Barcode-Scanner für EAN, UPC und QR-Codes auf Lebensmittelverpackungen
• Taschenlampe für schlechtes Licht und Eingabe der Barcode-Nummer von Hand
• Produktdaten aus der offenen Datenbank Open Food Facts
• Fehlt ein Produkt, trägst du die Nährwerte einmal ein – beim nächsten Scan ist es sofort da, auch ohne Internet
• Schnellauswahl für Packung, 100 g, Esslöffel und Teelöffel
• Nährwerte korrigieren, wenn die Angaben nicht zur Verpackung passen

SUCHEN STATT SCANNEN
• Favoriten, zuletzt verwendete und häufig gegessene Lebensmittel mit einem Tipp – auch offline
• Online-Suche in Open Food Facts, wenn kein Barcode zur Hand ist
• Eigene Lebensmittel ohne Barcode anlegen, z. B. selbst gekochte Gerichte
• Schnelleintrag nur mit Kalorien, wenn es schnell gehen muss

DEIN TAG AUF EINEN BLICK
• Kalorienring mit verbleibenden Kalorien
• Balken für Protein, Kohlenhydrate und Fett
• Einträge nach Frühstück, Mittagessen, Abendessen und Snacks – antippen zum Bearbeiten
• Mahlzeiten vom Vortag mit einem Tipp noch einmal eintragen
• Widgets für Homescreen und Sperrbildschirm

VERLAUF
• Kalorien der letzten sieben Tage im Vergleich zum Tagesziel
• Gewicht eintragen und den Verlauf sehen

DEIN TAGESZIEL
• Berechnung aus Alter, Größe, Gewicht, Zielgewicht und Aktivität
• Oder eigenes Tagesziel festlegen
• Makroverteilung frei einstellbar

OHNE BALLAST
• Kein Konto, keine Anmeldung
• Keine Werbung, kein Tracking
• Alle Einträge bleiben auf deinem Gerät
• Sicherung als Datei, wann und wohin du willst
• Alle Daten mit einem Tipp löschbar

Die berechneten Werte sind Richtwerte und ersetzen keine ärztliche oder ernährungsfachliche Beratung.

Produktdaten und -bilder: Open Food Facts (ODbL / CC BY-SA).
```

**Neue Funktionen in dieser Version** (Version 2.0, max. 4000 Zeichen):

```text
Hachibu ist von Grund auf neu – schneller, schöner und mit allem, was in Version 1 gefehlt hat:

• Widgets für Homescreen und Sperrbildschirm: übrige Kalorien auf einen Blick, Tippen öffnet den Scanner
• Favoriten in der Suche
• Schnelleintrag nur mit Kalorien, z. B. im Restaurant
• Verlauf: die letzten sieben Tage und dein Gewicht
• Datensicherung als Datei und CSV-Export – du entscheidest, wohin
• Kalender zum Springen auf jeden Tag
• „Speichern & weiter scannen“ für den Wocheneinkauf

Dein Tagebuch bleibt beim Update erhalten. Wie immer: kein Konto, keine Werbung, kein Tracking.
```

<!-- TODO: Texte final prüfen. Keine Aussagen wie „hilft beim Abnehmen“, „gesünder leben“ o. Ä. ergänzen. -->

## 11. Build und Einreichen (seit 2.0 über GitHub Actions)

Vorher, ohne Apple-Konto prüfbar:

- [ ] Der Workflow „Bauen und testen“ ist für den Branch grün (Actions-Tab). Er baut die App im Simulator und führt alle Tests aus.
- [x] `TARGETED_DEVICE_FAMILY: "1"` in `project.yml` – nur iPhone, dadurch prüft Apple nicht auf dem iPad und iPad-Screenshots entfallen. Wer später Tablets unterstützen will, braucht ein iPad-taugliches Layout **und** eigene Screenshots.
- [x] `ITSAppUsesNonExemptEncryption: false` in `project.yml` – die Frage zur Exportkontrolle ist damit beantwortet, ohne dass du sie bei jedem Build erneut ausfüllst. Korrekt, weil die App nur HTTPS des Betriebssystems nutzt und keine eigene Verschlüsselung enthält.

Dann der Upload (siehe README, Abschnitt „Veröffentlichen“):

- [ ] Einmalig die drei Secrets `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` im Repository anlegen – **den API-Schlüssel erzeugst und einträgst du selbst**; er gehört nie ins Repository und nie in einen Chat.
- [ ] GitHub → *Actions → „App Store Upload“ → Run workflow* auf `main`. Zertifikat und Provisioning-Profil legt Xcode mit dem Schlüssel selbst an. Die Build-Nummer ist `100 + Laufnummer` und damit immer größer als die 6 der Version 1.0.
- [ ] **TestFlight-Test auf dem eigenen iPhone, bevor du einreichst** (*Internes Testen*, eigene Apple-ID als Tester). Zu prüfen: Tagebuch aus Version 1.0 noch da, Kamera-Dialog samt Berechtigungstext, App-Icon, Widget hinzufügen und Tippen darauf, „Fertig“-Taste über jeder Zahlentastatur, Tageswechsel, Sicherung erstellen und wieder einlesen, „Alle Daten löschen“.
- [ ] Build in App Store Connect der Version zuordnen.
- [ ] *Zur Prüfung einreichen*.

## 12. Android

Entfällt. Seit Version 2.0 ist Hachibu in SwiftUI geschrieben und läuft nur auf dem iPhone. Eine Android-Version wurde nie veröffentlicht.
