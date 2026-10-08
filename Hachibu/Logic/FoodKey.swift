import Foundation

/// Schlüssel für food_item.barcode: echte GTINs oder `custom:<uuid>` für Lebensmittel ohne Barcode.
enum FoodKey {
    static let customPrefix = "custom:"

    /// Ein festes Pseudo-Lebensmittel, an dem Schnelleinträge (nur kcal) hängen.
    static let quickEntryKey = "custom:00000000-0000-4000-8000-000000000001"

    static func isCustom(_ key: String) -> Bool {
        guard key.hasPrefix(customPrefix) else { return false }
        let suffix = String(key.dropFirst(customPrefix.count))
        return suffix.count == 36 && UUID(uuidString: suffix) != nil
    }

    static func isQuickEntry(_ key: String) -> Bool { key == quickEntryKey }

    /// Gültig sind eigene Schlüssel und bereits normalisierte Barcodes (so, wie sie in der Datenbank stehen).
    static func isValid(_ key: String) -> Bool {
        isCustom(key) || Barcode.normalize(key) == key
    }

    static func newCustomKey(_ uuid: UUID = UUID()) -> String {
        customPrefix + uuid.uuidString.lowercased()
    }

    /// Eigener Schlüssel unverändert (kleingeschrieben), Barcodes normalisiert, sonst `nil`.
    static func parse(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = value.lowercased()
        if isCustom(lowered) { return lowered }
        return Barcode.normalize(value)
    }
}
