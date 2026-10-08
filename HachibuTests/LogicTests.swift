import Foundation
import Testing
@testable import Hachibu

private struct Food: NamedFood, Equatable {
    var name: String
    var brand: String
}

@Suite struct LocalSearchTests {
    @Test func likeMuster() {
        #expect(LocalSearch.toLikePattern("Äpfel 50%") == "%_pfel 50\\%%")
        #expect(LocalSearch.toLikePattern("a_b\\c") == "%a\\_b\\\\c%")
    }

    @Test func rangfolge() {
        #expect(LocalSearch.matchRank(name: "Skyr natur", brand: "Milsani", query: "sky") == 0)
        #expect(LocalSearch.matchRank(name: "Bio Skyr", brand: "", query: "sky") == 1)
        #expect(LocalSearch.matchRank(name: "Erdbeerskyr", brand: "", query: "sky") == 2)
        #expect(LocalSearch.matchRank(name: "Joghurt", brand: "Milsani Skyr", query: "sky") == 3)
        #expect(LocalSearch.matchRank(name: "Joghurt", brand: "Bioskyr", query: "sky") == 4)
        #expect(LocalSearch.matchRank(name: "Joghurt", brand: "Milsani", query: "sky") == nil)
        #expect(LocalSearch.matchRank(name: "Äpfel", brand: "", query: "äpf") == 0)
        #expect(LocalSearch.matchRank(name: "ÄPFEL", brand: "", query: "äpf") == 0)
        #expect(LocalSearch.matchRank(name: "Skyr", brand: "", query: "  ") == nil)
    }

    @Test func sortierung() {
        let items = [Food(name: "Erdbeerskyr", brand: ""), Food(name: "Skyr Vanille", brand: ""), Food(name: "Skyr Natur", brand: ""), Food(name: "Quark", brand: "Skyrland")]
        let ranked = LocalSearch.rank(items, query: "skyr", limit: 3)
        #expect(ranked.map { $0.name } == ["Skyr Natur", "Skyr Vanille", "Erdbeerskyr"])
    }
}

@Suite struct RateLimiterTests {
    @Test func erlaubtHoechstensLimitAnfragenImZeitfenster() {
        let limiter = RateLimiter(limit: 2, windowSeconds: 60)
        let start = Date(timeIntervalSince1970: 1_000_000)
        #expect(limiter.tryAcquire(now: start) == .ok)
        #expect(limiter.tryAcquire(now: start.addingTimeInterval(1)) == .ok)
        #expect(limiter.tryAcquire(now: start.addingTimeInterval(2)) == .limited(retryAfterSeconds: 58))
        #expect(limiter.tryAcquire(now: start.addingTimeInterval(60)) == .ok)
    }
}

@Suite struct PortionsTests {
    @Test func vorschlaege() {
        #expect(Portions.presets(servingSizeG: 250).map { $0.label } == ["1 Packung (250 g)", "100 g", "1 Esslöffel (15 g)", "1 Teelöffel (5 g)"])
        #expect(Portions.presets(servingSizeG: 12.5).first?.label == "1 Packung (12,5 g)")
        #expect(Portions.presets(servingSizeG: nil).count == 3)
        #expect(Portions.presets(servingSizeG: 0).count == 3)
        #expect(Portions.presets(servingSizeG: Portions.maxGrams + 1).count == 3)
        #expect(Portions.presets(servingSizeG: 250, lastAmount: 150).first?.label == "Wie zuletzt (150 g)")
        // Gleiche Menge nur einmal anbieten.
        #expect(Portions.presets(servingSizeG: 150, lastAmount: 150).count == 4)
    }

    @Test func gueltigeMengen() {
        #expect(Portions.valid(150) == 150)
        #expect(Portions.valid(Portions.maxGrams) == Portions.maxGrams)
        #expect(Portions.valid(0) == nil)
        #expect(Portions.valid(Portions.maxGrams + 1) == nil)
        #expect(Portions.valid(nil) == nil)
    }
}

@Suite struct NutritionDraftTests {
    let skyr = Nutrients(calories: 63, protein: 11, carbs: 4, fat: 0.2)

    @Test func felderFuellen() {
        #expect(NutritionDraft.draft(from: skyr, mode: .per100g, grams: nil) == NutrientDraft(calories: "63", protein: "11", carbs: "4", fat: "0,2"))
        #expect(NutritionDraft.draft(from: skyr, mode: .portion, grams: 250) == NutrientDraft(calories: "158", protein: "27,5", carbs: "10", fat: "0,5"))
        #expect(NutritionDraft.draft(from: skyr, mode: .portion, grams: nil) == NutritionDraft.draft(from: skyr, mode: .per100g, grams: nil))
    }

    @Test func felderLesen() {
        #expect(NutritionDraft.parse(NutrientDraft(calories: "63", protein: "11", carbs: "4", fat: "0,2")) == skyr)
        #expect(NutritionDraft.parse(NutrientDraft(calories: "63", protein: "", carbs: "4", fat: "0,2")) == nil)
        #expect(NutritionDraft.per100g(from: NutrientDraft(calories: "50", protein: "5", carbs: "2,5", fat: "1"), mode: .portion, grams: 50) == Nutrients(calories: 100, protein: 10, carbs: 5, fat: 2))
        #expect(NutritionDraft.per100g(from: NutrientDraft(calories: "50", protein: "5", carbs: "2,5", fat: "1"), mode: .portion, grams: 0) == nil)
    }

    @Test func nurBearbeiteteFelderUebernehmen() {
        let stored = Nutrients(calories: 63, protein: 11.37, carbs: 4, fat: 0.2)
        // Pro 30 g zeigt das Fettfeld „0,1“. Zurückgerechnet wären das 0,33 g statt der gespeicherten 0,2 g.
        var draft = NutritionDraft.draft(from: stored, mode: .portion, grams: 30)
        draft.calories = "21"
        let parsed = NutritionDraft.per100g(from: draft, mode: .portion, grams: 30)!
        #expect(NutritionDraft.mergeEditedFields(base: stored, parsed: parsed, edited: [.calories]) == Nutrients(calories: 70, protein: 11.37, carbs: 4, fat: 0.2))
        let all = Nutrients(calories: 70, protein: 12, carbs: 5, fat: 0.3)
        #expect(NutritionDraft.mergeEditedFields(base: stored, parsed: all, edited: [.calories, .fat]) == Nutrients(calories: 70, protein: 11.37, carbs: 4, fat: 0.3))
        #expect(NutritionDraft.mergeEditedFields(base: nil, parsed: all, edited: [.calories]) == all)
    }

    @Test func korrigiertePackungsgroesse() {
        // Erst 500 g getippt, dann auf 400 g korrigiert: Die Etikettwerte bleiben, die Basis ändert sich.
        let label = NutrientDraft(calories: "1200", protein: "40", carbs: "100", fat: "60")
        #expect(NutritionDraft.per100g(from: label, mode: .portion, grams: 500) == Nutrients(calories: 240, protein: 8, carbs: 20, fat: 12))
        #expect(NutritionDraft.per100g(from: label, mode: .portion, grams: 400) == Nutrients(calories: 300, protein: 10, carbs: 25, fat: 15))
    }
}

private struct Meal: MealTyped, Equatable {
    var id: String
    var mealType: MealType
}

@Suite struct RepeatMealsTests {
    @Test func bietetMahlzeitenDesVortagsAn() {
        let yesterday = [Meal(id: "s1", mealType: .snack), Meal(id: "b1", mealType: .breakfast), Meal(id: "b2", mealType: .breakfast), Meal(id: "d1", mealType: .dinner)]
        let result = mealsToRepeat(previousDay: yesterday, selectedDay: [])
        #expect(result.map { $0.mealType } == [.breakfast, .dinner, .snack])
        #expect(result[0].entries.map { $0.id } == ["b1", "b2"])
        #expect(result[0].label == "Frühstück")
    }

    @Test func laesstBelegteMahlzeitenWeg() {
        let yesterday = [Meal(id: "b1", mealType: .breakfast), Meal(id: "l1", mealType: .lunch)]
        let today = [Meal(id: "b9", mealType: .breakfast)]
        #expect(mealsToRepeat(previousDay: yesterday, selectedDay: today).map { $0.mealType } == [.lunch])
        #expect(mealsToRepeat(previousDay: [], selectedDay: today).isEmpty)
    }
}
