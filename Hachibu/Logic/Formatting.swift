import Foundation

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: return "Frühstück"
        case .lunch: return "Mittagessen"
        case .dinner: return "Abendessen"
        case .snack: return "Snacks"
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .snack: return "takeoutbag.and.cup.and.straw"
        }
    }

    /// Schlägt die Mahlzeit anhand der Uhrzeit vor.
    static func suggested(for date: Date, calendar: Calendar = .current) -> MealType {
        let hour = calendar.component(.hour, from: date)
        if hour >= 4 && hour < 11 { return .breakfast }
        if hour >= 11 && hour < 15 { return .lunch }
        if hour >= 17 && hour < 22 { return .dinner }
        return .snack
    }
}

protocol MealTyped {
    var mealType: MealType { get }
}

enum Formatting {
    /// Lokales Datum als YYYY-MM-DD (nicht UTC, sonst landet ein Eintrag um 0:30 Uhr am Vortag).
    static func dateKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static let isoWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Zeitstempel wie in der Datenbank: ISO 8601 in UTC mit Millisekunden (wie `Date.toISOString()`).
    static func isoTimestamp(_ date: Date) -> String {
        isoWithFraction.string(from: date)
    }

    static func parseIsoTimestamp(_ text: String) -> Date? {
        isoWithFraction.date(from: text) ?? isoPlain.date(from: text)
    }

    static func time(_ isoTimestamp: String, calendar: Calendar = .current) -> String {
        guard let date = parseIsoTimestamp(isoTimestamp) else { return "" }
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// Zahl als Text für ein Eingabefeld: Komma statt Punkt, ohne Tausenderpunkt.
    static func inputText(_ value: Double) -> String {
        let rounded = NumberFormat.jsRound(value * 10) / 10
        if rounded == rounded.rounded(.towardZero) {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
    }

    /// Liest Nutzereingaben mit Komma oder Punkt; leer oder ungültig ergibt `nil`.
    static func parseDecimal(_ text: String) -> Double? {
        var normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let comma = normalized.firstIndex(of: ",") {
            normalized.replaceSubrange(comma...comma, with: ".")
        }
        if normalized.isEmpty || normalized == "." { return nil }
        var dots = 0
        for char in normalized {
            if char == "." {
                dots += 1
                if dots > 1 { return nil }
            } else if !(char.isASCII && char.isNumber) {
                return nil
            }
        }
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
}
