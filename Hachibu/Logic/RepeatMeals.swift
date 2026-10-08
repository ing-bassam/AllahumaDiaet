import Foundation

struct MealToRepeat<T> {
    var mealType: MealType
    var entries: [T]
    var label: String { mealType.label }
}

/// „Wie gestern“: Mahlzeiten des Vortags, die am gewählten Tag noch leer sind, in der Reihenfolge des Tages.
/// Eine Mahlzeit mit schon vorhandenen Einträgen wird nicht angeboten, damit nichts doppelt landet.
func mealsToRepeat<T: MealTyped>(previousDay: [T], selectedDay: [T]) -> [MealToRepeat<T>] {
    let taken = Set(selectedDay.map { $0.mealType })
    return MealType.allCases.compactMap { meal -> MealToRepeat<T>? in
        if taken.contains(meal) { return nil }
        let entries = previousDay.filter { $0.mealType == meal }
        return entries.isEmpty ? nil : MealToRepeat(mealType: meal, entries: entries)
    }
}
