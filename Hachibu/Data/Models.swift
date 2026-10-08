import Foundation

struct Profile: Equatable {
    var id: String
    var age: Int
    var sex: Sex
    var heightCm: Double
    var weightKg: Double
    var goalWeightKg: Double
    var activityLevel: ActivityLevel
    var dailyCalorieGoal: Int
    /// Das Tagesziel wurde von Hand festgelegt und folgt nicht der Berechnung.
    var calorieGoalIsCustom: Bool
    var macroSplit: MacroSplit

    var goalInput: GoalInput {
        GoalInput(age: age, sex: sex, heightCm: heightCm, weightKg: weightKg, goalWeightKg: goalWeightKg, activityLevel: activityLevel)
    }

    var macroGoals: MacroGrams {
        Nutrition.macroGoalsInGrams(dailyCalories: dailyCalorieGoal, split: macroSplit)
    }
}

enum FoodSource: String, Codable {
    case openfoodfacts
    case manual
}

struct FoodItem: Identifiable, Equatable, NamedFood {
    /// Schlüssel: GTIN oder `custom:<uuid>`.
    var barcode: String
    var name: String
    var brand: String
    var per100g: Nutrients
    var servingSizeG: Double?
    var imageUrl: String?
    var source: FoodSource
    /// true, wenn der Nutzer die Werte korrigiert hat. Solche Datensätze überschreibt Open Food Facts nie.
    var userEdited: Bool
    var favorite: Bool

    var id: String { barcode }
    var isCustom: Bool { FoodKey.isCustom(barcode) }
}

/// Ein Tagebucheintrag samt den Stammdaten seines Lebensmittels. Die Nährwerte sind ein Schnappschuss
/// vom Zeitpunkt des Eintragens – spätere Korrekturen am Lebensmittel ändern alte Tage nicht.
struct LogEntry: Identifiable, Equatable, MealTyped {
    var id: String
    var date: String
    var timestamp: String
    var barcode: String
    var grams: Double
    var mealType: MealType
    var per100g: Nutrients
    var note: String?
    var name: String
    var brand: String
    var servingSizeG: Double?
    var imageUrl: String?
    var source: FoodSource

    var isQuickEntry: Bool { FoodKey.isQuickEntry(barcode) }

    var displayName: String {
        if isQuickEntry {
            let trimmed = (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Schnelleintrag" : trimmed
        }
        return name
    }

    var totals: Nutrients { Nutrition.nutrientsForPortion(per100g, grams: grams) }
}

struct WeightEntry: Identifiable, Equatable {
    var date: String
    var weightKg: Double
    var id: String { date }
}
