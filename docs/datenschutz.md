---
title: Datenschutzerklärung – Hachibu
---

# Datenschutzerklärung

> **Entwurf, keine Rechtsberatung.** Alle mit TODO markierten Stellen vor der Veröffentlichung prüfen und die TODO-Hinweise entfernen.

Stand: <!-- TODO: Datum der Veröffentlichung eintragen --> TT.MM.JJJJ

Diese Datenschutzerklärung gilt für die App **Hachibu** für iOS und Android sowie für diese Webseite.

## 1. Verantwortlicher

Karim Abu Elkheir<br>
Nehringstraße 23<br>
14059 Berlin<br>
Deutschland<br>
E-Mail: [abdel.abu99@gmail.com](mailto:abdel.abu99@gmail.com)

Ein Datenschutzbeauftragter ist nicht benannt. Nach Art. 37 DSGVO und § 38 BDSG ist das hier nicht erforderlich, weil keine Beschäftigten ständig mit der Verarbeitung personenbezogener Daten betraut sind.

## 2. Das Wichtigste in Kürze

- Hachibu hat **kein Konto, keine Werbung, kein Tracking und keine eigenen Analyse-Werkzeuge**.
- Alles, was du in der App eingibst – Profil, Gewicht, Tagebuch, selbst angelegte Produkte –, wird **nur auf deinem Gerät** gespeichert. Ich als Anbieter habe darauf keinen Zugriff.
- Nur wenn du ein Produkt scannst, eine Barcode-Nummer eingibst oder aktiv online suchst, fragt die App die Datenbank **Open Food Facts** ab. Dabei werden der Barcode bzw. dein Suchbegriff und technisch bedingt deine IP-Adresse übermittelt.

## 3. Speicherung auf deinem Gerät

Die App speichert folgende Angaben in einer lokalen Datenbank auf deinem Gerät:

- Profil: Alter, Geschlecht, Größe, aktuelles Gewicht, Zielgewicht, Aktivitätslevel, berechnetes Kalorienziel und Makroverteilung
- Tagebuch: gegessene Produkte mit Menge, Mahlzeit, Datum, Uhrzeit und den Nährwerten zum Zeitpunkt des Eintrags
- Produkte und eigene Lebensmittel: Name, Marke, Nährwerte, ggf. Bild-Adresse und ob du die Werte selbst korrigiert hast

Die Vorschläge „Zuletzt verwendet“ und „Häufig gegessen“ in der Suche werden aus diesem Tagebuch auf dem Gerät berechnet. Die lokale Suche verlässt dein Gerät nicht.

Diese Daten verlassen dein Gerät nicht durch die App und werden nicht an mich oder Dritte übermittelt. Da Gewicht und Ernährungsangaben Gesundheitsdaten im Sinne von Art. 9 DSGVO sein können, verarbeitet die App sie ausschließlich lokal.

**Speicherdauer:** Die Daten bleiben so lange auf deinem Gerät, bis du sie selbst löschst – über „Info & Rechtliches → Alle Daten löschen“ oder durch Deinstallieren der App. Eine automatische Löschfrist gibt es nicht, weil ein Tagebuch nur dann nützlich ist, wenn es dauerhaft erhalten bleibt.

Das Speichern auf deinem Gerät ist für die von dir gewünschte Funktion unbedingt erforderlich (§ 25 Abs. 2 Nr. 2 TDDDG).
<!-- TODO (rechtliche Prüfung): Da der Anbieter keinen Zugriff hat, ist fraglich, ob überhaupt eine Verarbeitung durch den Verantwortlichen im Sinne der DSGVO vorliegt. Die Erklärung beschreibt die lokale Speicherung deshalb vorsorglich, ohne eine DSGVO-Rechtsgrundlage für sich zu behaupten. -->

## 4. Kamera

Für das Scannen fragt die App nach der Kamera-Berechtigung. Das Kamerabild wird nur live auf deinem Gerät ausgewertet, um einen Barcode zu erkennen. Es werden **keine Fotos oder Videos gespeichert oder übertragen**. Die Berechtigung kannst du jederzeit in den Einstellungen deines Geräts entziehen; Barcodes lassen sich dann weiterhin von Hand eingeben.

- **iOS:** Die Erkennung erfolgt mit den Systemfunktionen von Apple direkt auf dem Gerät.
- **Android:** Die Erkennung nutzt die Bibliothek Google ML Kit der Google Ireland Limited. Das Kamerabild wird auch hier nur auf dem Gerät ausgewertet. ML Kit sendet jedoch technische Diagnosedaten an Google: Geräteinformationen (Hersteller, Modell, Betriebssystemversion), App-Informationen (Paketname, Version), Leistungswerte sowie Ereignis- und Fehlercodes. Nach Angaben von Google dienen sie der Diagnose und Nutzungsanalyse und werden nicht an Dritte weitergegeben ([Angaben von Google](https://developers.google.com/ml-kit/android-data-disclosure)).
  Rechtsgrundlage für diese technisch notwendige Diagnose ist Art. 6 Abs. 1 lit. f DSGVO; das berechtigte Interesse liegt in einer funktionierenden und fehlerfreien Barcode-Erkennung. Die iOS-Version ist davon nicht betroffen.
  <!-- TODO (rechtliche Prüfung): Rolle von Google (eigener Verantwortlicher oder gemeinsam Verantwortliche) einordnen lassen, bevor die App bei Google Play erscheint. -->

## 5. Produktabfrage bei Open Food Facts

Wenn du einen Barcode scannst oder eintippst und das Produkt noch nicht auf deinem Gerät gespeichert ist, sendet die App eine Anfrage an die Datenbank Open Food Facts. Übermittelt werden:

- der Barcode des Produkts,
- deine IP-Adresse (technisch notwendig, um die Antwort zurückzusenden),
- eine technische Kennung der App (App-Name, Version und Kontakt-E-Mail des Anbieters, kein Bezug zu dir).

Anbieter der Datenbank ist Open Food Facts, eine Vereinigung nach französischem Recht mit Sitz in 21 rue des Iles, 94100 Saint-Maur-des-Fossés, Frankreich. Open Food Facts verarbeitet diese Daten in eigener Verantwortung; Details findest du in der [Datenschutzerklärung von Open Food Facts](https://world.openfoodfacts.org/privacy). Nach deren Angaben werden IP-Adressen in Server-Logs für Sicherheit, technische Analysen und Statistik gespeichert.

Die Übermittlung erfolgt nur, wenn du aktiv ein Produkt suchst, und ist für diese Funktion erforderlich. Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO; das berechtigte Interesse liegt darin, dir die gewünschten Produktdaten anzuzeigen.
Open Food Facts handelt dabei als eigener Verantwortlicher und nicht als Auftragsverarbeiter für mich: Die Vereinigung entscheidet selbst über Zwecke und Mittel und hat eine eigene Datenschutzerklärung. Als Dienstleister nennt Open Food Facts dort nur Mailjet, Brevo und Donorbox für E-Mail, Newsletter und Spenden; diese Funktionen nutzt Hachibu nicht. Dienstleister außerhalb der EU für die Produktabfrage werden dort nicht genannt.
<!-- TODO (rechtliche Prüfung): Ob statt Art. 6 Abs. 1 lit. f zusätzlich lit. b greift (kostenloser Vertrag über digitale Inhalte, § 327 BGB), ist Auslegungsfrage. Die Angabe „lit. f“ ist die vorsichtigere Variante, weil sie dir ein Widerspruchsrecht nach Art. 21 DSGVO einräumt. -->

Wenn du ein gefundenes Produkt einträgst oder seine Werte korrigierst, werden die Produktdaten auf deinem Gerät gespeichert, damit spätere Scans ohne erneute Abfrage funktionieren.

## 5a. Online-Suche bei Open Food Facts

Die Textsuche durchsucht zuerst nur die Lebensmittel auf deinem Gerät. Erst wenn du ausdrücklich „Online suchen“ antippst oder die Suche mit der Eingabetaste abschickst, sendet die App eine Anfrage an den Suchdienst von Open Food Facts (search.openfoodfacts.org). Übermittelt werden:

- dein Suchbegriff sowie die Information, dass bevorzugt Produkte aus Deutschland gesucht werden,
- die gewünschte Ergebnisseite („Mehr laden“),
- deine IP-Adresse und die technische Kennung der App wie in Abschnitt 5.

Suchbegriffe können Rückschlüsse auf deine Ernährung zulassen. Gib daher keine Namen oder anderen persönlichen Angaben in das Suchfeld ein, wenn du online suchst. Suchergebnisse werden nicht dauerhaft gespeichert; erst wenn du ein Produkt auswählst und einträgst, landet es in der lokalen Datenbank. Anbieter, Rechtsgrundlage und Speicherdauer bei Open Food Facts entsprechen Abschnitt 5.
Für den Suchdienst nennt Open Food Facts keine eigenen Fristen; es gilt die allgemeine Angabe aus deren Datenschutzerklärung, nach der IP-Adressen in Server-Logs drei Jahre gespeichert werden (geprüft am 17.09.2026).

Bei „Eigenes Lebensmittel anlegen“ wird nichts übermittelt.

## 6. Produktbilder

Hat ein Produkt bei Open Food Facts ein Bild, lädt die App es von den Servern von Open Food Facts. Dabei wird ebenfalls deine IP-Adresse an Open Food Facts übermittelt. Es gelten die Angaben aus Abschnitt 5.

## 7. Kein Tracking, keine Weitergabe

Die App enthält keine Werbung, keine Analyse- oder Tracking-Werkzeuge und kein Crash-Reporting. Ich gebe keine Daten an Dritte weiter und verkaufe keine Daten. Ausnahmen sind nur die in den Abschnitten 4 bis 6 beschriebenen Übermittlungen, die technisch für das Scannen, die Produktabfrage und die Online-Suche nötig sind.

## 8. Geräte-Backups

Die App selbst synchronisiert nichts. Je nach Einstellungen deines Geräts können die App-Daten aber in Backups des Betriebssystems enthalten sein, zum Beispiel im **iCloud-Backup** (Apple) oder in der **Android-Datensicherung** (Google). Diese Backups richtest du selbst ein; sie unterliegen den Bedingungen von Apple bzw. Google. Ich habe darauf keinen Zugriff.
Backups sind bewusst nicht ausgeschlossen: Andernfalls wäre dein Tagebuch beim Wechsel auf ein neues Gerät verloren, da die App keine eigene Cloud nutzt.

## 9. Daten löschen

Du kannst alle Daten jederzeit in der App unter **Info & Rechtliches → Alle Daten löschen** entfernen. Auch das Deinstallieren der App löscht die lokal gespeicherten Daten. Kopien in Geräte-Backups (Abschnitt 8) werden erst entfernt, wenn du das jeweilige Backup löschst oder es überschrieben wird.

## 10. Kontakt per E-Mail

Wenn du mir eine E-Mail schreibst, verarbeite ich deine E-Mail-Adresse und den Inhalt deiner Nachricht, um deine Anfrage zu beantworten (Art. 6 Abs. 1 lit. f DSGVO). Die Nachricht wird gelöscht, wenn sie erledigt ist und keine gesetzlichen Aufbewahrungspflichten entgegenstehen.
Der E-Mail-Postfachdienst wird von Google Ireland Limited (Gmail) betrieben. Nachrichten werden gelöscht, sobald die Anfrage erledigt ist, spätestens nach zwölf Monaten, sofern keine gesetzlichen Aufbewahrungspflichten entgegenstehen.

## 11. Diese Webseite

Diese Webseite wird über **GitHub Pages** der GitHub, Inc., 88 Colin P. Kelly Jr. Street, San Francisco, CA 94107, USA, bereitgestellt. Beim Aufruf verarbeitet GitHub technisch notwendige Daten wie deine IP-Adresse in Server-Logs, um die Seite auszuliefern und den Betrieb abzusichern. Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO; das berechtigte Interesse liegt in einer sicheren und kostengünstigen Bereitstellung.

Dabei können Daten in die USA übermittelt werden. GitHub ist nach eigenen Angaben unter dem EU-US Data Privacy Framework zertifiziert; Einzelheiten stehen in der [Datenschutzerklärung von GitHub](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement). Die Seite verwendet selbst keine Cookies und kein Tracking.

## 11a. Empfänger deiner Daten

Ich selbst erhalte keine Daten aus der App. Übermittelt wird nur an die in den Abschnitten 4 bis 6 und 11 genannten Stellen:

| Empfänger | Wofür | Sitz |
| --- | --- | --- |
| Open Food Facts | Produktabfrage, Online-Suche, Produktbilder | Frankreich (EU) |
| Google Ireland Limited (ML Kit) | Diagnosedaten der Barcode-Erkennung, nur Android | Irland (EU), Konzern mit Sitz in den USA |
| GitHub, Inc. | Auslieferung dieser Webseite | USA, EU-US Data Privacy Framework |

Eine Weitergabe zu Werbe- oder Analysezwecken findet nicht statt.

## 11b. Freiwilligkeit und automatisierte Entscheidungen

Alle Angaben in der App sind freiwillig. Es besteht keine gesetzliche oder vertragliche Pflicht, sie bereitzustellen. Ohne Alter, Größe, Gewicht und Aktivitätslevel kann die App allerdings kein Kalorienziel berechnen, und ohne Kamera- oder Sucheingabe findet sie keine Produkte.

Die Berechnung des Kalorienziels erfolgt ausschließlich auf deinem Gerät und dient deiner eigenen Orientierung. Eine automatisierte Entscheidungsfindung einschließlich Profiling mit rechtlicher Wirkung oder ähnlich erheblicher Beeinträchtigung im Sinne von Art. 22 DSGVO findet nicht statt.

Da keine Verarbeitung auf einer Einwilligung beruht, gibt es auch kein Widerrufsrecht nach Art. 7 Abs. 3 DSGVO. Die Kamera-Berechtigung ist eine Systemberechtigung deines Geräts und lässt sich dort jederzeit entziehen.

## 12. Deine Rechte

Du hast nach der DSGVO das Recht auf

- Auskunft (Art. 15),
- Berichtigung (Art. 16),
- Löschung (Art. 17),
- Einschränkung der Verarbeitung (Art. 18),
- Datenübertragbarkeit (Art. 20) und
- Widerspruch gegen Verarbeitungen auf Grundlage berechtigter Interessen (Art. 21).

Da die App-Daten nur auf deinem Gerät liegen, kannst du sie dort selbst einsehen, ändern und löschen. Für Daten bei Open Food Facts wende dich an Open Food Facts (privacy@openfoodfacts.org). Für alle anderen Anliegen genügt eine E-Mail an die oben genannte Adresse.

## 13. Beschwerderecht

Du hast das Recht, dich bei einer Datenschutz-Aufsichtsbehörde zu beschweren (Art. 77 DSGVO). Zuständig für den Verantwortlichen ist:

Berliner Beauftragte für Datenschutz und Informationsfreiheit<br>
Alt-Moabit 59–61<br>
10555 Berlin<br>
[www.datenschutz-berlin.de](https://www.datenschutz-berlin.de)

## 14. Änderungen

Ändert sich die App so, dass andere Daten verarbeitet werden, passe ich diese Datenschutzerklärung an.
