import Foundation

enum NutritionMode: String, CaseIterable {
    case per100g
    case portion
}

enum NutrientField: CaseIterable, Hashable {
    case calories, protein, carbs, fat
}

/// Eingabezustand der Nährwertfelder. Die Felder zeigen Werte „pro 100 g“ oder „pro Portion“,
/// gespeichert wird immer pro 100 g.
struct NutrientDraft: Equatable {
    var calories = ""
    var protein = ""
    var carbs = ""
    var fat = ""

    static let empty = NutrientDraft()

    subscript(field: NutrientField) -> String {
        get {
            switch field {
            case .calories: return calories
            case .protein: return protein
            case .carbs: return carbs
            case .fat: return fat
            }
        }
        set {
            switch field {
            case .calories: calories = newValue
            case .protein: protein = newValue
            case .carbs: carbs = newValue
            case .fat: fat = newValue
            }
        }
    }
}

enum NutritionDraft {
    static func isUsablePortion(_ grams: Double?) -> Bool {
        guard let grams else { return false }
        return grams.isFinite && grams > 0
    }

    /// Werte für die Felder im gewünschten Modus. Portionen werden wie in der Anzeige gerundet.
    static func draft(from per100g: Nutrients, mode: NutritionMode, grams: Double?) -> NutrientDraft {
        let shown: Nutrients
        if mode == .portion, let grams, isUsablePortion(grams) {
            shown = Nutrition.nutrientsForPortion(per100g, grams: grams)
        } else {
            shown = per100g
        }
        return NutrientDraft(
            calories: Formatting.inputText(shown.calories),
            protein: Formatting.inputText(shown.protein),
            carbs: Formatting.inputText(shown.carbs),
            fat: Formatting.inputText(shown.fat)
        )
    }

    /// Liest die Felder; `nil`, solange ein Feld leer oder keine Zahl ist.
    static func parse(_ draft: NutrientDraft) -> Nutrients? {
        guard let calories = Formatting.parseDecimal(draft.calories),
              let protein = Formatting.parseDecimal(draft.protein),
              let carbs = Formatting.parseDecimal(draft.carbs),
              let fat = Formatting.parseDecimal(draft.fat) else { return nil }
        return Nutrients(calories: calories, protein: protein, carbs: carbs, fat: fat)
    }

    /// Übernimmt nur die vom Nutzer bearbeiteten Felder; alle übrigen behalten ihren gespeicherten Wert,
    /// weil die Felder gerundete Zahlen zeigen und zurückgerechnet Werte verfälschen würden.
    static func mergeEditedFields(base: Nutrients?, parsed: Nutrients, edited: Set<NutrientField>) -> Nutrients {
        guard let base else { return parsed }
        var merged = base
        if edited.contains(.calories) { merged.calories = parsed.calories }
        if edited.contains(.protein) { merged.protein = parsed.protein }
        if edited.contains(.carbs) { merged.carbs = parsed.carbs }
        if edited.contains(.fat) { merged.fat = parsed.fat }
        return merged
    }

    /// Rechnet die Feldwerte auf 100 g um; `nil` bei unvollständigen Feldern oder fehlender Portionsgröße.
    static func per100g(from draft: NutrientDraft, mode: NutritionMode, grams: Double?) -> Nutrients? {
        guard let values = parse(draft) else { return nil }
        if mode == .per100g { return values }
        guard let grams, isUsablePortion(grams) else { return nil }
        return Nutrition.portionToPer100g(values, grams: grams)
    }
}
