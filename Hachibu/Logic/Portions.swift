import Foundation

struct PortionPreset: Identifiable, Equatable {
    var label: String
    var grams: Double
    var id: String { label }
}

/// Schnellauswahl für Mengen, gemeinsam genutzt von Produkt-Screen und Eintrag-Bearbeitung.
enum Portions {
    static let maxGrams = 5000.0

    /// Gültige Menge in Gramm oder `nil`.
    static func valid(_ grams: Double?) -> Double? {
        guard let grams, grams.isFinite, grams > 0, grams <= maxGrams else { return nil }
        return grams
    }

    static func presets(servingSizeG: Double?, lastAmount: Double? = nil) -> [PortionPreset] {
        var list: [PortionPreset] = []
        if let last = valid(lastAmount) {
            list.append(PortionPreset(label: "Wie zuletzt (\(NumberFormat.decimal(last)) g)", grams: last))
        }
        // Nur anbieten, was sich auch speichern lässt – ein Großgebinde über der Obergrenze nicht.
        if let package = valid(servingSizeG), package != list.first?.grams {
            list.append(PortionPreset(label: "1 Packung (\(NumberFormat.decimal(package)) g)", grams: package))
        }
        list.append(PortionPreset(label: "100 g", grams: 100))
        list.append(PortionPreset(label: "1 Esslöffel (15 g)", grams: 15))
        list.append(PortionPreset(label: "1 Teelöffel (5 g)", grams: 5))
        return list
    }
}
