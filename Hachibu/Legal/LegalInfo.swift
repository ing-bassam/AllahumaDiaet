import Foundation

/// Angaben für das Impressum (§ 5 DDG). Die Webseite nutzt dieselben Daten in docs/impressum.md.
enum Imprint {
    static let name = "Karim Abu Elkheir"
    static let street = "Bergmannstraße 3"
    static let postalCodeAndCity = "10961 Berlin"
    static let country = "Deutschland"
    static let email = AppInfo.contactEmail
    // Telefonnummer bewusst nicht im öffentlichen Repository.
    static let phone: String? = nil
}

enum LegalURLs {
    private static let pagesBase = "https://ing-bassam.github.io/AllahumaDiaet"

    // Werden über GitHub Pages aus dem Ordner docs/ veröffentlicht.
    static let privacyPolicy = URL(string: "\(pagesBase)/datenschutz.html")!
    static let imprint = URL(string: "\(pagesBase)/impressum.html")!
    static let support = URL(string: "\(pagesBase)/support.html")!
    static let openFoodFacts = URL(string: "https://world.openfoodfacts.org")!
    static let openFoodFactsContribute = URL(string: "https://world.openfoodfacts.org/contribute")!
    static let odbl = URL(string: "https://opendatacommons.org/licenses/odbl/1.0/")!
    static let ccBySa = URL(string: "https://creativecommons.org/licenses/by-sa/3.0/deed.de")!
}

struct CalculationSource: Identifiable {
    var title: String
    /// Vollständige Fundstelle, so wie sie in der App steht.
    var detail: String
    var url: URL
    var id: String { title }
}

/// Quellen für die Berechnungen (App-Store-Richtlinie 1.4.1).
enum CalculationInfo {
    static let steps = [
        "Grundumsatz nach Mifflin-St. Jeor: 10 × Gewicht in kg + 6,25 × Größe in cm − 5 × Alter, dann + 5 bei Männern und − 161 bei Frauen.",
        "Gesamtumsatz: Grundumsatz × PAL-Faktor deines Aktivitätslevels (1,4 bis 2,3).",
        "Tagesziel: Gesamtumsatz − 500 kcal beim Abnehmen, + 300 kcal beim Zunehmen, sonst der Gesamtumsatz. Das berechnete Ziel liegt nie unter deinem Grundumsatz.",
        "Eigenes Tagesziel: Statt der Berechnung kannst du ein Ziel zwischen 1.200 und 5.000 kcal festlegen. Liegt es unter deinem Grundumsatz, weist die App darauf hin.",
        "Makronährstoffe: Anteil am Tagesziel, umgerechnet mit 4 kcal je Gramm Protein und Kohlenhydrate und 9 kcal je Gramm Fett.",
    ]

    static let sources: [CalculationSource] = [
        CalculationSource(
            title: "Grundumsatz",
            detail: "Mifflin MD, St Jeor ST, Hill LA, Scott BJ, Daugherty SA, Koh YO: A new predictive equation for resting energy expenditure in healthy individuals. The American Journal of Clinical Nutrition 1990;51(2):241–247.",
            url: URL(string: "https://doi.org/10.1093/ajcn/51.2.241")!
        ),
        CalculationSource(
            title: "Aktivitätsfaktor (PAL)",
            detail: "Deutsche Gesellschaft für Ernährung: Referenzwerte für die Energiezufuhr. PAL-Werte reichen von 1,2 bei ausschließlich sitzender Lebensweise bis 2,4 bei körperlich sehr anstrengender Arbeit.",
            url: URL(string: "https://www.dge.de/wissenschaft/referenzwerte/energie/")!
        ),
        CalculationSource(
            title: "Energiedefizit beim Abnehmen",
            detail: "S3-Leitlinie „Prävention und Therapie der Adipositas“ (Deutsche Adipositas-Gesellschaft und weitere Fachgesellschaften, Fassung 2024, AWMF-Register 050-001): empfohlen wird ein tägliches Defizit von etwa 500 kcal.",
            url: URL(string: "https://register.awmf.org/de/leitlinien/detail/050-001")!
        ),
        CalculationSource(
            title: "Umrechnung der Nährwerte",
            detail: "Verordnung (EU) Nr. 1169/2011 über die Information der Verbraucher über Lebensmittel, Anhang XIV: 4 kcal je Gramm Protein und Kohlenhydrate, 9 kcal je Gramm Fett.",
            url: URL(string: "https://eur-lex.europa.eu/legal-content/DE/TXT/?uri=CELEX:32011R1169")!
        ),
    ]

    static let medicalDisclaimer = "Die Berechnungen sind Richtwerte für gesunde Erwachsene und ersetzen keine ärztliche oder ernährungsfachliche Beratung. Bei Erkrankungen, in Schwangerschaft und Stillzeit oder bei Beschwerden sprich bitte mit deiner Ärztin oder deinem Arzt."
}

struct OpenSourceLicense: Identifiable {
    var name: String
    var version: String
    var license: String
    var url: URL
    var id: String { name }
}

/// Fremdcode in der App. Apples eigene Frameworks gehören nicht dazu.
enum OpenSourceLicenses {
    static let all: [OpenSourceLicense] = [
        OpenSourceLicense(name: "GRDB.swift", version: "7.11.1", license: "MIT", url: URL(string: "https://github.com/groue/GRDB.swift")!),
    ]
}
