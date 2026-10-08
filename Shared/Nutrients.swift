import Foundation

/// Nährwerte – je nach Kontext pro 100 g, pro Portion oder als Tagessumme.
struct Nutrients: Codable, Equatable, Hashable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    static let zero = Nutrients(calories: 0, protein: 0, carbs: 0, fat: 0)
}
