import Foundation

// Reine Rechenlogik ohne UI, damit sie sich mit Unit-Tests prüfen lässt.

enum Sex: String, Codable, CaseIterable {
    case male
    case female

    var label: String { self == .male ? "Männlich" : "Weiblich" }
}

/// PAL-Werte angelehnt an die Referenzwerte der DGE.
enum ActivityLevel: String, Codable, CaseIterable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive = "very_active"

    var label: String {
        switch self {
        case .sedentary: return "Sitzend"
        case .light: return "Leicht aktiv"
        case .moderate: return "Aktiv"
        case .active: return "Sehr aktiv"
        case .veryActive: return "Schwerstarbeit"
        }
    }

    var description: String {
        switch self {
        case .sedentary: return "Bürojob, kaum Bewegung"
        case .light: return "Sitzend, zeitweise gehend oder stehend"
        case .moderate: return "Überwiegend gehend oder stehend"
        case .active: return "Körperlich anstrengender Beruf oder viel Sport"
        case .veryActive: return "z. B. Bau, Landwirtschaft, Leistungssport"
        }
    }

    var pal: Double {
        switch self {
        case .sedentary: return 1.4
        case .light: return 1.6
        case .moderate: return 1.8
        case .active: return 2.0
        case .veryActive: return 2.3
        }
    }
}

struct MacroSplit: Codable, Equatable {
    var protein: Double
    var carbs: Double
    var fat: Double

    static let standard = MacroSplit(protein: 0.3, carbs: 0.5, fat: 0.2)
}

enum Nutrition {
    static let kcalPerGramProtein = 4.0
    static let kcalPerGramCarbs = 4.0
    static let kcalPerGramFat = 9.0

    /// Tagesdefizit bzw. -überschuss, wenn das Zielgewicht vom aktuellen Gewicht abweicht.
    static let loseWeightAdjustment = -500
    static let gainWeightAdjustment = 300

    static let ageRange = 18.0...100.0
    static let heightRange = 120.0...230.0
    static let weightRange = 30.0...300.0

    /// Grenzen für ein selbst gewähltes Tagesziel.
    static let customGoalRange = 1200...5000

    static let maxKcalPer100g = 900.0
    static let maxMacrosPer100g = 100.0

    /// Ab dieser relativen Abweichung zwischen kcal und 4·P + 4·K + 9·F wird gewarnt.
    static let plausibilityTolerance = 0.2
    static let plausibilityMinDiffKcal = 15.0

    /// Grundumsatz nach Mifflin-St. Jeor in kcal/Tag.
    static func bmrMifflinStJeor(age: Int, sex: Sex, heightCm: Double, weightKg: Double) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    static func calculateCalorieGoal(_ input: GoalInput) -> CalorieGoal {
        let bmr = bmrMifflinStJeor(age: input.age, sex: input.sex, heightCm: input.heightCm, weightKg: input.weightKg)
        let tdee = bmr * input.activityLevel.pal
        // Auf 0,01 kg runden: 63.1 - 64.1 ergibt sonst -0.9999999999999929 und verfehlt die 1-kg-Schwelle.
        let weightDiff = roundTo(input.goalWeightKg - input.weightKg, 0.01)

        var adjustment = 0
        if weightDiff <= -1 {
            adjustment = loseWeightAdjustment
        } else if weightDiff >= 1 {
            adjustment = gainWeightAdjustment
        }

        let target = tdee + Double(adjustment)
        // Nie unter den Grundumsatz gehen – auch nicht durch das Runden auf 10 kcal.
        let floorGoal = (NumberFormat.jsRound(bmr) / 10).rounded(.up) * 10
        let dailyGoal = max(roundTo(target, 10), floorGoal)
        // Greift die Untergrenze, das tatsächliche Defizit ausweisen statt der nominellen 500 kcal.
        let effectiveAdjustment = target < bmr ? Int(NumberFormat.jsRound(bmr - tdee)) : adjustment
        return CalorieGoal(
            bmr: Int(NumberFormat.jsRound(bmr)),
            tdee: Int(NumberFormat.jsRound(tdee)),
            adjustment: effectiveAdjustment,
            dailyGoal: Int(dailyGoal)
        )
    }

    /// Tagesziel aus der Berechnung oder aus dem eigenen Wert. `nil`, wenn ein eigenes Ziel gewählt ist,
    /// aber fehlt oder außerhalb der Grenzen liegt.
    static func chooseDailyGoal(_ goal: CalorieGoal, customEnabled: Bool, customKcal: Double?) -> DailyGoalChoice? {
        if !customEnabled {
            return DailyGoalChoice(dailyGoal: goal.dailyGoal, isCustom: false, belowBmr: false)
        }
        guard let customKcal, customKcal.isFinite else { return nil }
        let kcal = Int(NumberFormat.jsRound(customKcal))
        guard customGoalRange.contains(kcal) else { return nil }
        return DailyGoalChoice(dailyGoal: kcal, isCustom: true, belowBmr: kcal < goal.bmr)
    }

    static func macroGoalsInGrams(dailyCalories: Int, split: MacroSplit) -> MacroGrams {
        let kcal = Double(dailyCalories)
        return MacroGrams(
            protein: Int(NumberFormat.jsRound(kcal * split.protein / kcalPerGramProtein)),
            carbs: Int(NumberFormat.jsRound(kcal * split.carbs / kcalPerGramCarbs)),
            fat: Int(NumberFormat.jsRound(kcal * split.fat / kcalPerGramFat))
        )
    }

    static func isValidMacroSplit(_ split: MacroSplit) -> Bool {
        let parts = [split.protein, split.carbs, split.fat]
        if parts.contains(where: { !$0.isFinite || $0 < 0 || $0 > 1 }) { return false }
        return Int(NumberFormat.jsRound((split.protein + split.carbs + split.fat) * 100)) == 100
    }

    /// Rechnet Nährwerte pro 100 g auf die gegessene Menge um.
    static func nutrientsForPortion(_ per100g: Nutrients, grams: Double) -> Nutrients {
        let factor = grams / 100
        return Nutrients(
            calories: NumberFormat.jsRound(per100g.calories * factor),
            protein: roundTo(per100g.protein * factor, 0.1),
            carbs: roundTo(per100g.carbs * factor, 0.1),
            fat: roundTo(per100g.fat * factor, 0.1)
        )
    }

    /// Gegenstück: rechnet Nährwerte einer Portion auf 100 g hoch. Bewusst fein gerundet.
    static func portionToPer100g(_ portion: Nutrients, grams: Double) -> Nutrients? {
        guard grams.isFinite, grams > 0 else { return nil }
        let factor = 100 / grams
        return Nutrients(
            calories: roundTo(portion.calories * factor, 0.0001),
            protein: roundTo(portion.protein * factor, 0.0001),
            carbs: roundTo(portion.carbs * factor, 0.0001),
            fat: roundTo(portion.fat * factor, 0.0001)
        )
    }

    /// Harte Regeln für Nährwerte pro 100 g. Verstöße verhindern das Speichern.
    static func validate(_ per100g: Nutrients) -> NutrientValidation {
        func negative(_ value: Double) -> String? {
            (!value.isFinite || value < 0) ? "Bitte einen Wert ab 0 eingeben." : nil
        }
        let calories = negative(per100g.calories)
            ?? (per100g.calories > maxKcalPer100g ? "Mehr als \(Int(maxKcalPer100g)) kcal pro 100 g ist nicht möglich." : nil)
        let protein = negative(per100g.protein)
        let carbs = negative(per100g.carbs)
        let fat = negative(per100g.fat)

        let macroSum = per100g.protein + per100g.carbs + per100g.fat
        // Toleranz für Gleitkomma-Reste und die auf vier Stellen gerundeten Werte aus portionToPer100g.
        let macroTotal: String? = (protein == nil && carbs == nil && fat == nil && macroSum > maxMacrosPer100g + 0.001)
            ? "Protein, Kohlenhydrate und Fett zusammen können nicht über \(Int(maxMacrosPer100g)) g pro 100 g liegen."
            : nil

        return NutrientValidation(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            macroTotal: macroTotal,
            valid: calories == nil && protein == nil && carbs == nil && fat == nil && macroTotal == nil
        )
    }

    /// Nur ein Hinweis, kein Fehler: Ballaststoffe, Alkohol und Zuckeralkohole bringen Energie ohne Makro-Anteil.
    static func plausibilityWarning(_ per100g: Nutrients) -> String? {
        guard validate(per100g).valid else { return nil }
        let expected = kcalPerGramProtein * per100g.protein + kcalPerGramCarbs * per100g.carbs + kcalPerGramFat * per100g.fat
        let diff = abs(per100g.calories - expected)
        if diff < plausibilityMinDiffKcal { return nil }
        if expected > 0 && diff / expected <= plausibilityTolerance { return nil }
        return "Die Kalorien passen nicht ganz zu den Makros (daraus ergeben sich etwa \(Int(NumberFormat.jsRound(expected))) kcal). Bitte prüfen."
    }

    static func sum(_ items: [Nutrients]) -> Nutrients {
        var total = Nutrients.zero
        for n in items {
            total.calories += n.calories
            total.protein += n.protein
            total.carbs += n.carbs
            total.fat += n.fat
        }
        return Nutrients(
            calories: NumberFormat.jsRound(total.calories),
            protein: roundTo(total.protein, 0.1),
            carbs: roundTo(total.carbs, 0.1),
            fat: roundTo(total.fat, 0.1)
        )
    }

    /// Rundet auf ein Vielfaches von `step` und entfernt Gleitkomma-Reste wie 12.300000000000001.
    static func roundTo(_ value: Double, _ step: Double) -> Double {
        let rounded = NumberFormat.jsRound(value / step) * step
        let decimals = step < 1 ? Int((-log10(step)).rounded()) : 0
        let factor = pow(10.0, Double(decimals))
        return (rounded * factor).rounded() / factor
    }
}

struct GoalInput: Equatable {
    var age: Int
    var sex: Sex
    var heightCm: Double
    var weightKg: Double
    var goalWeightKg: Double
    var activityLevel: ActivityLevel
}

struct CalorieGoal: Equatable {
    var bmr: Int
    var tdee: Int
    var adjustment: Int
    var dailyGoal: Int
}

struct DailyGoalChoice: Equatable {
    var dailyGoal: Int
    var isCustom: Bool
    var belowBmr: Bool
}

struct MacroGrams: Equatable {
    var protein: Int
    var carbs: Int
    var fat: Int
}

struct NutrientValidation: Equatable {
    var calories: String?
    var protein: String?
    var carbs: String?
    var fat: String?
    var macroTotal: String?
    var valid: Bool
}
