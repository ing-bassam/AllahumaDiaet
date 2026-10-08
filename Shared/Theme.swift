import SwiftUI

/// Farben der App. Hintergründe kommen vom System, damit der Dunkelmodus automatisch passt.
enum Theme {
    static let primary = Color(red: 0.086, green: 0.639, blue: 0.290)
    static let primaryDark = Color(red: 0.082, green: 0.502, blue: 0.239)
    static let danger = Color(red: 0.863, green: 0.149, blue: 0.149)
    static let protein = Color(red: 0.145, green: 0.388, blue: 0.922)
    static let carbs = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let fat = Color(red: 0.545, green: 0.361, blue: 0.965)
    static let cream = Color(red: 0.969, green: 0.965, blue: 0.953)

    static let ringGradient = AngularGradient(
        colors: [Color(red: 0.133, green: 0.773, blue: 0.369), primary, Color(red: 0.016, green: 0.502, blue: 0.239)],
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )
}
