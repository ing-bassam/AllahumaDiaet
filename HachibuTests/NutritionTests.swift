import Testing
@testable import Hachibu

@Suite struct NutritionTests {
    let base = GoalInput(age: 30, sex: .male, heightCm: 180, weightKg: 80, goalWeightKg: 80, activityLevel: .sedentary)

    @Test func grundumsatzNachMifflinStJeor() {
        #expect(Nutrition.bmrMifflinStJeor(age: 30, sex: .male, heightCm: 180, weightKg: 80) == 1780)
        #expect(Nutrition.bmrMifflinStJeor(age: 30, sex: .female, heightCm: 165, weightKg: 60) == 1320.25)
    }

    @Test func gewichtHaltenRundetAufZehn() {
        let goal = Nutrition.calculateCalorieGoal(base)
        #expect(goal.bmr == 1780)
        #expect(goal.tdee == 2492)
        #expect(goal.adjustment == 0)
        #expect(goal.dailyGoal == 2490)
    }

    @Test func abnehmenZiehtFuenfhundertAb() {
        var input = base
        input.goalWeightKg = 72
        let goal = Nutrition.calculateCalorieGoal(input)
        #expect(goal.adjustment == -500)
        #expect(goal.dailyGoal == 1990)
    }

    @Test func zunehmenLegtDreihundertDrauf() {
        var input = base
        input.goalWeightKg = 85
        #expect(Nutrition.calculateCalorieGoal(input).dailyGoal == 2790)
    }

    @Test func ignoriertAbweichungenUnterEinemKilo() {
        var input = base
        input.goalWeightKg = 79.5
        #expect(Nutrition.calculateCalorieGoal(input).adjustment == 0)
    }

    @Test func genauEinKiloTrotzGleitkommaRest() {
        var lose = base
        lose.weightKg = 64.1
        lose.goalWeightKg = 63.1
        #expect(Nutrition.calculateCalorieGoal(lose).adjustment == -500)
        var gain = base
        gain.weightKg = 63.1
        gain.goalWeightKg = 64.1
        #expect(Nutrition.calculateCalorieGoal(gain).adjustment == 300)
    }

    @Test func gehtNieUnterDenGrundumsatz() {
        let goal = Nutrition.calculateCalorieGoal(GoalInput(age: 70, sex: .female, heightCm: 150, weightKg: 45, goalWeightKg: 40, activityLevel: .sedentary))
        #expect(goal.dailyGoal >= goal.bmr)
    }

    @Test func bleibtAuchNachDemRundenUeberDemGrundumsatz() {
        // Grundumsatz 1131,5 → Gesamtbedarf 1584,1. Minus 500 läge darunter, und 1131,5 rundet auf 1130 ab.
        let goal = Nutrition.calculateCalorieGoal(GoalInput(age: 55, sex: .female, heightCm: 158, weightKg: 58, goalWeightKg: 52, activityLevel: .sedentary))
        #expect(goal.bmr == 1132)
        #expect(goal.dailyGoal == 1140)
        #expect(goal.adjustment == -453)
    }

    @Test func eigenesZiel() {
        var input = base
        input.goalWeightKg = 72
        let goal = Nutrition.calculateCalorieGoal(input)
        #expect(Nutrition.chooseDailyGoal(goal, customEnabled: false, customKcal: 3000) == DailyGoalChoice(dailyGoal: 1990, isCustom: false, belowBmr: false))
        #expect(Nutrition.chooseDailyGoal(goal, customEnabled: true, customKcal: 2200.4) == DailyGoalChoice(dailyGoal: 2200, isCustom: true, belowBmr: false))
        #expect(Nutrition.chooseDailyGoal(goal, customEnabled: true, customKcal: 1500) == DailyGoalChoice(dailyGoal: 1500, isCustom: true, belowBmr: true))
        #expect(Nutrition.chooseDailyGoal(goal, customEnabled: true, customKcal: 1200)?.dailyGoal == 1200)
        #expect(Nutrition.chooseDailyGoal(goal, customEnabled: true, customKcal: 5000)?.dailyGoal == 5000)
        #expect(Nutrition.chooseDailyGoal(goal, customEnabled: true, customKcal: 1199) == nil)
        #expect(Nutrition.chooseDailyGoal(goal, customEnabled: true, customKcal: 5001) == nil)
        #expect(Nutrition.chooseDailyGoal(goal, customEnabled: true, customKcal: nil) == nil)
    }

    @Test func makrosInGramm() {
        // 2000 kcal: 30 % Protein = 150 g, 50 % KH = 250 g, 20 % Fett = 44 g
        #expect(Nutrition.macroGoalsInGrams(dailyCalories: 2000, split: .standard) == MacroGrams(protein: 150, carbs: 250, fat: 44))
    }

    @Test func makroverteilungPruefen() {
        #expect(Nutrition.isValidMacroSplit(.standard))
        #expect(Nutrition.isValidMacroSplit(MacroSplit(protein: 0.4, carbs: 0.4, fat: 0.2)))
        #expect(!Nutrition.isValidMacroSplit(MacroSplit(protein: 0.5, carbs: 0.5, fat: 0.1)))
        #expect(!Nutrition.isValidMacroSplit(MacroSplit(protein: .nan, carbs: 0.5, fat: 0.5)))
    }

    @Test func portionUmrechnen() {
        let skyr = Nutrients(calories: 63, protein: 11, carbs: 4, fat: 0.2)
        #expect(Nutrition.nutrientsForPortion(skyr, grams: 250) == Nutrients(calories: 158, protein: 27.5, carbs: 10, fat: 0.5))
        #expect(Nutrition.portionToPer100g(Nutrients(calories: 50, protein: 5, carbs: 2.5, fat: 1), grams: 50) == Nutrients(calories: 100, protein: 10, carbs: 5, fat: 2))
        #expect(Nutrition.portionToPer100g(Nutrients(calories: 1, protein: 0, carbs: 0, fat: 0), grams: 0) == nil)
    }

    @Test func portionHinUndZurueck() {
        let portion = Nutrients(calories: 50, protein: 3.2, carbs: 6.1, fat: 1.4)
        for grams in [37.0, 12.5, 250.0, 3.0] {
            let per100g = Nutrition.portionToPer100g(portion, grams: grams)!
            #expect(Nutrition.nutrientsForPortion(per100g, grams: grams) == portion, "bei \(grams) g")
        }
    }

    @Test func validierung() {
        #expect(Nutrition.validate(Nutrients(calories: 67, protein: 12, carbs: 4, fat: 0.2)).valid)
        let tooMany = Nutrition.validate(Nutrients(calories: 901, protein: 0, carbs: 0, fat: 100))
        #expect(!tooMany.valid)
        #expect(tooMany.calories?.contains("900 kcal") == true)
        let macros = Nutrition.validate(Nutrients(calories: 400, protein: 40, carbs: 50, fat: 20))
        #expect(!macros.valid)
        #expect(macros.macroTotal != nil)
        // 85.2 + 7.4 + 7.4 ergibt in Gleitkomma 100.00000000000001.
        #expect(Nutrition.validate(Nutrients(calories: 420, protein: 85.2, carbs: 7.4, fat: 7.4)).valid)
        let fromPortion = Nutrition.portionToPer100g(Nutrients(calories: 120, protein: 20, carbs: 5, fat: 5), grams: 30)!
        #expect(Nutrition.validate(fromPortion).valid)
        let negative = Nutrition.validate(Nutrients(calories: 100, protein: -1, carbs: 10, fat: 1))
        #expect(!negative.valid)
        #expect(negative.protein != nil)
        #expect(negative.carbs == nil)
        #expect(negative.macroTotal == nil)
    }

    @Test func plausibilitaet() {
        // 4·12 + 4·4 + 9·0.2 = 65.8
        #expect(Nutrition.plausibilityWarning(Nutrients(calories: 67, protein: 12, carbs: 4, fat: 0.2)) == nil)
        // erwartet 4·10 + 4·50 + 9·10 = 330
        #expect(Nutrition.plausibilityWarning(Nutrients(calories: 150, protein: 10, carbs: 50, fat: 10))?.contains("330 kcal") == true)
        #expect(Nutrition.plausibilityWarning(Nutrients(calories: 1, protein: 0, carbs: 0, fat: 0)) == nil)
    }

    @Test func summe() {
        let sum = Nutrition.sum([Nutrients(calories: 100.4, protein: 1.25, carbs: 2, fat: 0.33), Nutrients(calories: 50.4, protein: 1.25, carbs: 2, fat: 0.33)])
        #expect(sum == Nutrients(calories: 151, protein: 2.5, carbs: 4, fat: 0.7))
    }

    @Test func rundenWieJavaScript() {
        #expect(Nutrition.roundTo(12.300000000000001, 0.1) == 12.3)
        #expect(Nutrition.roundTo(1995, 10) == 2000)
        #expect(Nutrition.roundTo(-0.9999999999999929, 0.01) == -1)
        #expect(NumberFormat.jsRound(2.5) == 3)
        #expect(NumberFormat.jsRound(-2.5) == -2)
    }
}
