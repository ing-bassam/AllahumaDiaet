import Foundation

/// Kurzfassung des heutigen Tages für das Widget. Die App schreibt sie nach jeder Änderung in den
/// gemeinsamen App-Group-Ordner; das Widget liest nur diese Datei und nie die Datenbank.
struct TodaySnapshot: Codable, Equatable {
    var dateKey: String
    var consumed: Nutrients
    var goalCalories: Int
    var goalProtein: Int
    var goalCarbs: Int
    var goalFat: Int
    var entryCount: Int
    var updatedAt: Date

    static let appGroup = "group.com.abdelkarim.hachibu"
    static let fileName = "today.json"

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }

    /// Lokales Datum als YYYY-MM-DD, wie es die App in der Datenbank verwendet.
    static func todayKey(now: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func load() -> TodaySnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(TodaySnapshot.self, from: data)
    }

    func save() throws {
        guard let url = TodaySnapshot.fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }

    static func remove() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    var remainingCalories: Int { goalCalories - Int(consumed.calories.rounded()) }

    /// Beispieldaten für die Widget-Galerie.
    static let sample = TodaySnapshot(
        dateKey: todayKey(),
        consumed: Nutrients(calories: 1240, protein: 82, carbs: 130, fat: 41),
        goalCalories: 2170, goalProtein: 163, goalCarbs: 271, goalFat: 48,
        entryCount: 4, updatedAt: Date()
    )
}
