# App Store Connect – Checkliste für Hachibu

> **Arbeitsdokument, keine Rechtsberatung.** Wird nicht über GitHub Pages veröffentlicht (`_config.yml` → `exclude`).
> Alle offenen Punkte sind mit TODO markiert. Stand der Apple-Vorgaben: 15.09.2026 – vor dem Einreichen in App Store Connect gegenprüfen.

Reihenfolge ungefähr so, wie die Schritte aufeinander aufbauen.

## 1. Apple Developer Program

- [x] Mitgliedschaft im [Apple Developer Program](https://developer.apple.com/programs/) ist bezahlt (deine Angabe, 17.09.2026).
- [ ] Kontotyp im [Developer-Portal](https://developer.apple.com/account) unter *Membership details* nachsehen:
  - **Einzelperson (Individual):** Anbietername im App Store ist dein eigener Name, also Karim Abu Elkheir. So ist Hachibu geplant.
  - **Organisation:** nur mit eingetragener Rechtsform und D-U-N-S-Nummer möglich. Ein Wechsel ist später nur über den Apple-Support möglich, deshalb jetzt bewusst entscheiden.
- [ ] Zwei-Faktor-Authentifizierung für die Apple-ID aktiv.

## 2. App in App Store Connect anlegen

- [ ] *Apps → + → Neue App*
  - Plattform: iOS
  - Name (App-Store-Name, max. 30 Zeichen): **Hachibu** – geprüft und frei, siehe *2a. Namensprüfung*. Derselbe Name steht auf dem Homescreen (`app.json` → `name`).
  - Primäre Sprache: Deutsch
  - Bundle-ID: **com.abdelkarim.hachibu** (`app.json` → `ios.bundleIdentifier`; muss zuerst unter *Certificates, Identifiers & Profiles* existieren – `eas build` legt sie beim ersten Build an). **Nach dem ersten Upload nicht mehr änderbar**, siehe *2b. Bundle-ID*.
  - SKU: frei wählbar, z. B. `hachibu-ios`
  - Benutzerzugriff: Vollzugriff
- [ ] Unter *App-Informationen → Allgemeine Informationen* die **Apple-ID** (nur Ziffern) ablesen und in `eas.json` bei `submit.production.ios.ascAppId` statt `TODO_ASC_APP_ID` eintragen.
- [ ] Kategorie: **Gesundheit & Fitness** (primär). Sekundär optional, z. B. *Essen & Trinken*.
- [ ] Copyright: `2026 Karim Abu Elkheir` <!-- TODO: bestätigen -->

## 2a. Namensprüfung (Stand 17.09.2026)

- App-Store-Namen sind weltweit eindeutig. Ist ein Name vergeben, lässt App Store Connect ihn nicht mehr reservieren; Groß- und Kleinschreibung macht dabei keinen Unterschied.
- Geprüft über die öffentliche Suchschnittstelle von Apple (`https://itunes.apple.com/search?term=hachibu&entity=software`, Storefronts Deutschland und USA): **kein Treffer**. „Hachibu“ ist als App-Store-Name frei.
- Name: **`Hachibu`** (7 von 30 Zeichen), Untertitel `Kalorien scannen & zählen`. Ein beschreibender Zusatz im Namen ist nicht nötig, weil Apple den Untertitel ohnehin mit indexiert. Guideline 2.3.7 (kein Keyword-Stapeln) ist damit unproblematisch, Guideline 2.3.8 ebenfalls, weil der Name auf dem Gerät identisch ist.
- Vorgeschichte: Der frühere Arbeitsname „Halabi“ war im App Store schon von einer anderen App belegt (Anbieter Yaseen Halabi, Social Networking). Das war der Anlass für den Wechsel auf Hachibu.
- [ ] Markenrecherche vor dem Anlegen: [DPMAregister](https://register.dpma.de/DPMAregister/marke/experte), [EUIPO eSearch](https://euipo.europa.eu/eSearch/) und [TMview](https://www.tmdn.org/tmview/) nach „Hachibu“ in Klasse 9 (Software) und 42/44 durchsuchen. Als Fantasiewort ist das Risiko geringer als bei einem Familiennamen, aber die Prüfung bleibt nötig: Bei einer Markenbeschwerde entfernt Apple die App. Die Register lassen sich nur von Hand durchsuchen, und die Bewertung des Ergebnisses ist Rechtsberatung.

## 2b. Bundle-ID (Entscheidung, die bleibt)

- Die Bundle-ID entsteht beim ersten Build und ist danach **dauerhaft**: Sie lässt sich für eine eingereichte App nicht mehr ändern. Ein anderer Wert bedeutet später eine neue App mit neuer Apple-ID – bestehende Installationen bekommen dann keine Updates. Für Android gilt dasselbe für `android.package` ab der ersten Veröffentlichung.
- [x] **Entschieden am 17.09.2026:** `com.abdelkarim.hachibu`, eingetragen in `app.json` unter `ios.bundleIdentifier` **und** `android.package`. Der alte Wert `com.abdelkarim.allahumadiaet` stammte aus dem früheren Projektnamen und ist ersetzt, solange noch kein Build hochgeladen war.
- Ab dem ersten `eas build` bleibt dieser Wert unverändert.

## 3. URLs

Die Seiten liegen im Ordner `docs/` und werden über GitHub Pages veröffentlicht.

- [ ] Alle TODOs in `docs/datenschutz.md`, `docs/impressum.md` und `docs/support.md` klären und entfernen.
- [ ] GitHub → Repository → *Settings → Pages* → *Deploy from a branch* → Branch `main`, Ordner `/docs` → *Save*.
- [ ] Nach ein paar Minuten prüfen, ob die Seiten erreichbar sind:
  - Datenschutz-URL: `https://abdelabu99-ai.github.io/AllahumaDiaet/datenschutz.html`
  - Support-URL: `https://abdelabu99-ai.github.io/AllahumaDiaet/support.html`
  - Impressum: `https://abdelabu99-ai.github.io/AllahumaDiaet/impressum.html`
- [ ] Datenschutz-URL unter *App-Datenschutz* und Support-URL in der Versionsseite eintragen. Beide sind für jede App Pflicht. Laut Apple muss die Support-URL zu echten Kontaktinformationen führen.
- [ ] Die gleichen URLs sind in der App hinterlegt (`src/legal/imprint.ts`). Ändern sie sich, dort anpassen.

## 4. App-Datenschutzangaben („Privacy Nutrition Label“)

### Vorschlag: „Keine Daten erfasst“

Apple definiert „erfassen“ (collect) als: Daten verlassen das Gerät so, dass du **oder deine Drittanbieter-Partner** länger darauf zugreifen können, als für die Beantwortung der Anfrage in Echtzeit nötig ist.

Warum „Keine Daten erfasst“ in Frage kommt:

- Profil, Gewicht, Tagebuch und selbst angelegte Produkte werden nur lokal in SQLite gespeichert. Es gibt keinen eigenen Server.
- Keine Analyse-, Werbe-, Tracking- oder Crash-Reporting-SDKs (siehe `package.json`).
- Barcode-Erkennung auf iOS läuft vollständig auf dem Gerät (AVFoundation/ZXing in `expo-camera`).
- Das Privacy Manifest (`app.json` → `ios.privacyManifests`) meldet `NSPrivacyTracking: false` und keine erfassten Datentypen.

**Wichtiger Vorbehalt – Open Food Facts:**
Beim Scannen gehen der Barcode und die IP-Adresse an die Open-Food-Facts-API, bei der **Online-Suche der eingegebene Suchbegriff** und die IP-Adresse an deren Suchdienst (search.openfoodfacts.org), beim Anzeigen von Produktbildern die IP-Adresse an deren Bildserver. Open Food Facts speichert IP-Adressen nach eigener Datenschutzerklärung in Server-Logs (dort angegeben: 3 Jahre, für Sicherheit, technische Analysen und Statistik).

- Open Food Facts ist eine öffentliche Datenbank, deren Code nicht in der App steckt. Ob Apple sie als „Drittanbieter-Partner“ wertet, ist nicht eindeutig.
- Für IP-Adressen sagt Apple: je nach Verwendung als *Grobe Position*, *Geräte-ID* oder *Diagnose* angeben.
- **Suchbegriffe** fallen ziemlich direkt unter Apples Datentyp *Suchverlauf* („Informationen über Suchen in der App“). Seit es die Online-Suche gibt, ist „Keine Daten erfasst“ deshalb schwerer zu begründen als vorher, als nur Barcodes übertragen wurden.
- Die lokale Suche, „Zuletzt verwendet“ und „Häufig gegessen“ bleiben auf dem Gerät und sind keine Erfassung.

- [ ] Entscheiden. **Empfehlung: „Suchverlauf“ angeben** – nicht mit der Identität verknüpft, nicht für Tracking, Zweck „App-Funktionalität“. Das ist die vorsichtigere Variante und passt zu Abschnitt 5a der Datenschutzerklärung. Eine zu knappe Angabe ist ein häufiger Ablehnungsgrund nach Guideline 5.1.2, eine zu vorsichtige nicht.
- [ ] Angaben, Datenschutzerklärung und (später) das Datensicherheits-Formular bei Google Play müssen dasselbe sagen. Wird eine Stelle geändert, die anderen mitziehen.

## 5. Altersfreigabe

- [ ] Fragebogen unter *App-Informationen → Altersfreigabe* ausfüllen. Voraussichtliche Antworten:
  - Nutzergenerierte Inhalte, Messaging/Chat, soziale Medien, Werbung, uneingeschränkter Webzugriff: **Nein**
  - Glücksspiel, Wettbewerbe, Lootboxen: **Keine**
  - Gewalt, Sexualität, Horror, Alkohol/Tabak/Drogen, Obszönitäten: **Keine**
  - **Gesundheits- oder Wellness-Themen:** Apple nennt ausdrücklich „Calorie tracking, dieting advice, or exercise recommendations“. Kalorien-Tracking ist die Kernfunktion → nicht „Keine“ angeben.
  - Medizinische oder Behandlungsinformationen: **Keine** (die App gibt keine Diagnosen, Medikamenten- oder Behandlungshinweise).
- [ ] Ergebnis prüfen. Nach Apples Tabelle führen Gesundheits-/Wellness-Themen voraussichtlich zu mindestens **13+**. <!-- TODO: tatsächliche Einstufung nach dem Ausfüllen notieren. -->
- Passt zur App: Die Berechnung ist ohnehin erst ab 18 Jahren freigegeben (`LIMITS.age` in `src/lib/nutrition.ts`).

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

- `src/legal/sources.ts` enthält den Rechenweg in vier Schritten und vier Quellen: Mifflin-St Jeor (Am J Clin Nutr 1990), PAL-Faktoren der Deutschen Gesellschaft für Ernährung, S3-Leitlinie Adipositas (AWMF 050-001) für das Defizit, Verordnung (EU) 1169/2011 Anhang XIV für 4/4/9 kcal je Gramm.
- In der App sichtbar unter *Info & Rechtliches → Berechnung & Quellen* mit Links, außerdem beim Anlegen des Profils.
- Der Hinweis „Richtwerte für gesunde Erwachsene, ersetzt keine ärztliche oder ernährungsfachliche Beratung“ steht an beiden Stellen.
- Keine Diagnosen, keine Behandlungs- oder Medikamentenhinweise, keine Messung von Vitalwerten.
- Das Profil ist erst ab 18 Jahren möglich (`LIMITS.age` in `src/lib/nutrition.ts`), damit keine Kalorienziele für Kinder und Jugendliche berechnet werden.

### Metadaten und Berechtigungen

- [ ] Berechtigungstext prüfen: `NSCameraUsageDescription` entsteht aus dem `expo-camera`-Plugin in `app.json` und lautet „Die Kamera wird nur zum Scannen von Barcodes auf Lebensmitteln verwendet.“ Ein Text, der den Zweck nicht erklärt, ist ein klassischer Ablehnungsgrund (Guideline 5.1.1). Das Mikrofon ist im Plugin ausdrücklich abgeschaltet, deshalb fragt die App es nie ab.
- [ ] Screenshots ohne echte persönliche Daten, ohne Gerätrahmen mit fremden Marken und ohne Text, der im Store-Text nichts verspricht.
- [ ] Keine Heilversprechen, keine Vergleiche mit anderen Apps, kein „Beta“, kein „Demo“, keine Platzhaltertexte in Store-Texten und in der App.
- [ ] Support- und Datenschutz-URL müssen erreichbar sein, bevor du einreichst. Eine 404-Seite führt zuverlässig zur Ablehnung – GitHub Pages also vorher aktivieren.

## 8. Screenshots

Anforderungen laut Apple (Stand siehe oben):

- 1 bis 10 Screenshots pro Displaygröße, Format `.png` oder `.jpg`, **ohne Alphakanal/Transparenz**.
- **Pflicht:** Screenshots für das **6,5"-Display** (1284 × 2778 px Hochformat), sofern keine 6,9"-Screenshots geliefert werden. Einfacher: direkt **6,9"** liefern (1320 × 2868, 1290 × 2796 oder 1260 × 2736 px) – die kleineren Größen skaliert Apple dann herunter.
- iPad-Screenshots sind nicht nötig, weil `ios.supportsTablet` auf `false` steht.

Vorschlag für 5–6 Motive: Dashboard mit Kalorienring · Scanner · Eintragen mit Mengeneingabe · Suche mit „Zuletzt verwendet“ · Eintrag bearbeiten · Profil mit Tagesziel.
<!-- TODO: Screenshots mit Beispieldaten erstellen (z. B. im iOS-Simulator über einen Mac-Dienst oder vom eigenen iPhone). Keine echten persönlichen Daten zeigen. -->

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
- Ein Eintrag auf dem Startbildschirm lässt sich antippen und bearbeiten (Menge, Mahlzeit, Nährwerte).
- In der Suche kann über „… als eigenes Lebensmittel anlegen“ ein Lebensmittel ohne Barcode angelegt werden.

Die Kamera-Berechtigung wird nur für das Scannen von Barcodes verwendet.
Daten löschen: Startbildschirm → „Info & Rechtliches“ → „Alle Daten löschen“.

Berechnung des Kalorienziels (zu Guideline 1.4.1):
- Grundumsatz nach Mifflin-St Jeor, Am J Clin Nutr 1990;51:241-247 (doi:10.1093/ajcn/51.2.241)
- Gesamtumsatz über die PAL-Faktoren der Deutschen Gesellschaft für Ernährung
- Defizit 500 kcal beim Abnehmen, Überschuss 300 kcal beim Zunehmen, nie unter dem Grundumsatz
- Makronährstoffe mit 4/4/9 kcal je Gramm nach Verordnung (EU) 1169/2011 Anhang XIV

Methode und Quellen sind in der App sichtbar: „Info & Rechtliches“ → „Berechnung & Quellen“,
außerdem beim Anlegen des Profils. Die App stellt keine Diagnosen und gibt keine
Behandlungsempfehlungen. Ein Hinweis auf ärztliche Beratung ist an beiden Stellen sichtbar.
Ein Profil ist erst ab 18 Jahren möglich.
```

Die drei Barcodes wurden am 15.09.2026 (zweimal) über die Open-Food-Facts-API mit der App-eigenen Funktion `fetchProduct`/`parseProduct` geprüft; alle lieferten `status: found` mit vollständigen Nährwerten. Open Food Facts wird von Freiwilligen gepflegt – vor dem Einreichen kurz in der App gegenprüfen.

- [ ] Kontaktdaten für die App-Prüfung (Name, Telefon, E-Mail) ausfüllen. Diese sind nur für Apple sichtbar.
- [ ] Anmeldung erforderlich: **Nein**.

## 10. Store-Texte (Entwurf, Deutsch)

Ohne Heilversprechen und ohne medizinische Aussagen.

**Name** (max. 30 Zeichen, 7 genutzt): `Hachibu`

**Untertitel** (max. 30 Zeichen, 25 genutzt): `Kalorien scannen & zählen`

**Keywords** (max. 100 Bytes, Umlaute zählen doppelt; 95 Bytes genutzt):

```text
Kalorienzähler,Makros,Barcode,Scanner,Ernährung,Protein,Nährwerte,Lebensmittel,Diät,Tracker
```

Apple sucht auch in Name und Untertitel. „Kalorien“, „scannen“ und „zählen“ stehen deshalb nicht in den Keywords – der Untertitel deckt sie ab. Weil der Name selbst kein beschreibendes Wort enthält, steht „Tracker“ hier.

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
• Zuletzt verwendete und häufig gegessene Lebensmittel mit einem Tipp – auch offline
• Online-Suche in Open Food Facts, wenn kein Barcode zur Hand ist
• Eigene Lebensmittel ohne Barcode anlegen, z. B. selbst gekochte Gerichte

DEIN TAG AUF EINEN BLICK
• Kalorienring mit verbleibenden Kalorien
• Balken für Protein, Kohlenhydrate und Fett
• Einträge nach Frühstück, Mittagessen, Abendessen und Snacks – antippen zum Bearbeiten

DEIN TAGESZIEL
• Berechnung aus Alter, Größe, Gewicht, Zielgewicht und Aktivität
• Makroverteilung frei einstellbar

OHNE BALLAST
• Kein Konto, keine Anmeldung
• Keine Werbung, kein Tracking
• Alle Einträge bleiben auf deinem Gerät
• Alle Daten mit einem Tipp löschbar

Die berechneten Werte sind Richtwerte und ersetzen keine ärztliche oder ernährungsfachliche Beratung.

Produktdaten und -bilder: Open Food Facts (ODbL / CC BY-SA).
```

<!-- TODO: Texte final prüfen. Keine Aussagen wie „hilft beim Abnehmen“, „gesünder leben“ o. Ä. ergänzen. -->

## 11. Build und Einreichen

Vorher, alles ohne Apple-Konto prüfbar:

- [ ] `npm test` und `npm run typecheck` laufen durch.
- [ ] `npx expo-doctor` ohne Beanstandung.
- [ ] `npx expo export --platform ios` baut das JS-Bundle fehlerfrei.
- [x] `ios.supportsTablet: false` – dadurch prüft Apple nicht auf dem iPad und iPad-Screenshots entfallen. Wer später Tablets unterstützen will, braucht ein iPad-taugliches Layout **und** eigene Screenshots.
- [x] `ios.config.usesNonExemptEncryption: false` – daraus wird `ITSAppUsesNonExemptEncryption` in der Info.plist. Die Frage zur Exportkontrolle ist damit beantwortet, ohne dass du sie bei jedem Build erneut ausfüllst. Korrekt, weil die App nur HTTPS des Betriebssystems nutzt und keine eigene Verschlüsselung enthält.

Dann EAS (siehe README, Abschnitt „Veröffentlichen“):

- [ ] `eas login` – **braucht deinen eigenen Expo-Zugang**, den ich nicht anlege und nicht eingebe.
- [ ] `eas init` (`eas.json` liegt schon vor, `eas build:configure` entfällt). Danach den `slug` in `app.json` nicht mehr ändern.
- [ ] `eas build --platform ios --profile production` – legt beim ersten Lauf Bundle-ID, Zertifikat und Provisioning-Profil an. Vorher Abschnitt 2b entscheiden.
- [ ] **TestFlight-Test auf dem eigenen iPhone, bevor du einreichst** (*Internes Testen*, eigene Apple-ID als Tester). Zu prüfen: Kamera-Dialog samt Berechtigungstext, Splash-Screen, App-Icon auf dem Homescreen, Tastatur beim Ändern der Nährwerte, Tageswechsel, „Alle Daten löschen“. Ein Debug-Build im Expo Go verhält sich beim Splash-Screen und bei Berechtigungen anders als ein Release-Build – dieser Test ersetzt keine Ablehnung, verhindert aber die häufigsten.
- [ ] `eas submit --platform ios --profile production`
- [ ] Build in App Store Connect der Version zuordnen.
- [ ] *Zur Prüfung einreichen*.

## 12. Später: Google Play

- [ ] `android.package` ist ab der ersten Veröffentlichung dauerhaft – dieselbe Entscheidung wie in Abschnitt 2b.
- [ ] Das **Datensicherheits-Formular** muss die ML-Kit-Diagnosedaten von Google abbilden (siehe `docs/datenschutz.md`, Abschnitt 4) und zur Datenschutzerklärung passen.
- [ ] Google verlangt für neue Entwicklerkonten einen Identitätsnachweis und bei Einzelpersonen einen Test mit mindestens zwölf Testern über zwei Wochen. Das ist ein eigener Vorgang nach dem App Store.
