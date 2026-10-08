import Foundation
import GRDB

/// Datensicherung als eine JSON-Datei: Profil, Lebensmittel, Tagebuch und Gewichtsverlauf.
/// Der Nutzer entscheidet über das Teilen-Menü selbst, wohin die Datei geht.
struct BackupDocument: Codable, Equatable {
    static let formatName = "hachibu-backup"
    static let currentVersion = 1

    var format: String = BackupDocument.formatName
    var version: Int = BackupDocument.currentVersion
    var exportedAt: Date
    var appVersion: String
    var profile: BackupProfile?
    var foods: [BackupFood]
    var entries: [BackupEntry]
    var weights: [BackupWeight]

    struct BackupProfile: Codable, Equatable {
        var age: Int
        var sex: String
        var heightCm: Double
        var weightKg: Double
        var goalWeightKg: Double
        var activityLevel: String
        var dailyCalorieGoal: Int
        var calorieGoalIsCustom: Bool
        var macroProtein: Double
        var macroCarbs: Double
        var macroFat: Double
    }

    struct BackupFood: Codable, Equatable {
        var key: String
        var name: String
        var brand: String
        var caloriesPer100g: Double
        var proteinPer100g: Double
        var carbsPer100g: Double
        var fatPer100g: Double
        var servingSizeG: Double?
        var imageUrl: String?
        var source: String
        var userEdited: Bool
        var favorite: Bool
    }

    struct BackupEntry: Codable, Equatable {
        var id: String
        var date: String
        var timestamp: String
        var key: String
        var grams: Double
        var mealType: String
        var caloriesPer100g: Double
        var proteinPer100g: Double
        var carbsPer100g: Double
        var fatPer100g: Double
        var note: String?
    }

    struct BackupWeight: Codable, Equatable {
        var date: String
        var weightKg: Double
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func encoded() throws -> Data {
        try BackupDocument.encoder().encode(self)
    }

    static func decode(_ data: Data) throws -> BackupDocument {
        try decoder().decode(BackupDocument.self, from: data)
    }

    /// Prüft die Datei, bevor sie die Datenbank ersetzt. Liefert eine lesbare Fehlermeldung.
    func validate() -> String? {
        if format != BackupDocument.formatName { return "Das ist keine Hachibu-Sicherung." }
        if version > BackupDocument.currentVersion { return "Die Sicherung stammt aus einer neueren App-Version. Bitte Hachibu aktualisieren." }
        if let profile {
            if Sex(rawValue: profile.sex) == nil || ActivityLevel(rawValue: profile.activityLevel) == nil { return "Das Profil in der Sicherung ist beschädigt." }
        }
        let keys = Set(foods.map { $0.key })
        for food in foods {
            if FoodSource(rawValue: food.source) == nil || !FoodKey.isValid(food.key) { return "Ein Lebensmittel in der Sicherung ist beschädigt." }
            if ![food.caloriesPer100g, food.proteinPer100g, food.carbsPer100g, food.fatPer100g].allSatisfy({ $0.isFinite }) { return "Ein Lebensmittel in der Sicherung hat ungültige Nährwerte." }
        }
        for entry in entries {
            if !keys.contains(entry.key) || MealType(rawValue: entry.mealType) == nil || DateMath.parseDateKey(entry.date) == nil {
                return "Ein Tagebucheintrag in der Sicherung ist beschädigt."
            }
            if !entry.grams.isFinite || entry.grams <= 0 { return "Ein Tagebucheintrag in der Sicherung hat eine ungültige Menge." }
        }
        for weight in weights where DateMath.parseDateKey(weight.date) == nil || !weight.weightKg.isFinite || weight.weightKg <= 0 {
            return "Ein Gewichtseintrag in der Sicherung ist beschädigt."
        }
        return nil
    }
}

extension Repository {
    func exportBackup(appVersion: String, now: Date = Date()) throws -> BackupDocument {
        try queue.read { db in
            let profileRow = try Row.fetchOne(db, sql: "SELECT * FROM user_profile LIMIT 1")
            let profile: BackupDocument.BackupProfile? = profileRow.map { row in
                let custom: Int = row["calorie_goal_is_custom"]
                return BackupDocument.BackupProfile(
                    age: row["age"], sex: row["sex"], heightCm: row["height_cm"], weightKg: row["weight_kg"], goalWeightKg: row["goal_weight_kg"],
                    activityLevel: row["activity_level"], dailyCalorieGoal: row["daily_calorie_goal"], calorieGoalIsCustom: custom == 1,
                    macroProtein: row["macro_split_protein"], macroCarbs: row["macro_split_carbs"], macroFat: row["macro_split_fat"]
                )
            }
            let foods = try Row.fetchAll(db, sql: "SELECT * FROM food_item ORDER BY barcode").map { row -> BackupDocument.BackupFood in
                let edited: Int = row["user_edited"]
                let favorite: Int = row["favorite"]
                return BackupDocument.BackupFood(
                    key: row["barcode"], name: row["name"], brand: row["brand"],
                    caloriesPer100g: row["calories_per_100g"], proteinPer100g: row["protein_per_100g"],
                    carbsPer100g: row["carbs_per_100g"], fatPer100g: row["fat_per_100g"],
                    servingSizeG: row["serving_size_g"], imageUrl: row["image_url"], source: row["source"],
                    userEdited: edited == 1, favorite: favorite == 1
                )
            }
            let entries = try Row.fetchAll(db, sql: "SELECT * FROM log_entry ORDER BY timestamp").map { row -> BackupDocument.BackupEntry in
                BackupDocument.BackupEntry(
                    id: row["id"], date: row["date"], timestamp: row["timestamp"], key: row["barcode"], grams: row["consumed_weight_g"],
                    mealType: row["meal_type"], caloriesPer100g: row["calories_per_100g"], proteinPer100g: row["protein_per_100g"],
                    carbsPer100g: row["carbs_per_100g"], fatPer100g: row["fat_per_100g"], note: row["note"]
                )
            }
            let weights = try Row.fetchAll(db, sql: "SELECT date, weight_kg FROM weight_log ORDER BY date").map { row in
                BackupDocument.BackupWeight(date: row["date"], weightKg: row["weight_kg"])
            }
            return BackupDocument(exportedAt: now, appVersion: appVersion, profile: profile, foods: foods, entries: entries, weights: weights)
        }
    }

    /// Ersetzt alle Daten durch die Sicherung. Alles oder nichts.
    func importBackup(_ document: BackupDocument) throws {
        if let problem = document.validate() { throw BackupError.invalid(problem) }
        try queue.write { db in
            try db.execute(sql: "DELETE FROM log_entry")
            try db.execute(sql: "DELETE FROM food_item")
            try db.execute(sql: "DELETE FROM user_profile")
            try db.execute(sql: "DELETE FROM weight_log")

            if let p = document.profile {
                try db.execute(
                    sql: """
                      INSERT INTO user_profile (id, age, sex, height_cm, weight_kg, goal_weight_kg, activity_level,
                        daily_calorie_goal, calorie_goal_is_custom, macro_split_protein, macro_split_carbs, macro_split_fat)
                      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [UUID().uuidString.lowercased(), p.age, p.sex, p.heightCm, p.weightKg, p.goalWeightKg, p.activityLevel,
                                p.dailyCalorieGoal, p.calorieGoalIsCustom ? 1 : 0, p.macroProtein, p.macroCarbs, p.macroFat]
                )
            }
            for f in document.foods {
                try db.execute(
                    sql: """
                      INSERT INTO food_item (barcode, name, brand, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g,
                        serving_size_g, image_url, source, user_edited, favorite)
                      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [f.key, f.name, f.brand, f.caloriesPer100g, f.proteinPer100g, f.carbsPer100g, f.fatPer100g,
                                f.servingSizeG, f.imageUrl, f.source, f.userEdited ? 1 : 0, f.favorite ? 1 : 0]
                )
            }
            for e in document.entries {
                try db.execute(
                    sql: """
                      INSERT INTO log_entry (id, date, timestamp, barcode, consumed_weight_g, meal_type,
                        calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, note)
                      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [e.id, e.date, e.timestamp, e.key, e.grams, e.mealType, e.caloriesPer100g, e.proteinPer100g, e.carbsPer100g, e.fatPer100g, e.note]
                )
            }
            for w in document.weights {
                try db.execute(
                    sql: "INSERT INTO weight_log (date, weight_kg, created_at) VALUES (?, ?, ?)",
                    arguments: [w.date, w.weightKg, Formatting.isoTimestamp(Date())]
                )
            }
        }
    }

    /// Tagebuch als CSV (Semikolon-getrennt, deutsche Dezimalkommas), z. B. für Excel.
    func exportCSV() throws -> String {
        let rows = try queue.read { db in
            try Row.fetchAll(db, sql: Repository.entrySelectForExport + " ORDER BY e.timestamp")
        }
        var lines = ["Datum;Uhrzeit;Mahlzeit;Lebensmittel;Marke;Menge (g);kcal;Protein (g);Kohlenhydrate (g);Fett (g)"]
        for row in rows {
            let timestamp: String = row["timestamp"]
            let mealText: String = row["meal_type"]
            let per100g = Nutrients(calories: row["calories_per_100g"], protein: row["protein_per_100g"], carbs: row["carbs_per_100g"], fat: row["fat_per_100g"])
            let grams: Double = row["consumed_weight_g"]
            let totals = Nutrition.nutrientsForPortion(per100g, grams: grams)
            let barcode: String = row["barcode"]
            let note: String? = row["note"]
            let name: String = FoodKey.isQuickEntry(barcode) ? ((note ?? "").isEmpty ? "Schnelleintrag" : (note ?? "")) : row["name"]
            let brand: String = row["brand"]
            let fields: [String] = [
                row["date"], Formatting.time(timestamp), MealType(rawValue: mealText)?.label ?? mealText, name, brand,
                Formatting.inputText(grams), Formatting.inputText(totals.calories), Formatting.inputText(totals.protein),
                Formatting.inputText(totals.carbs), Formatting.inputText(totals.fat),
            ]
            lines.append(fields.map(Repository.csvField).joined(separator: ";"))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    private static let entrySelectForExport = """
      SELECT e.date, e.timestamp, e.meal_type, e.barcode, e.consumed_weight_g, e.note,
             e.calories_per_100g, e.protein_per_100g, e.carbs_per_100g, e.fat_per_100g, f.name, f.brand
        FROM log_entry e JOIN food_item f ON f.barcode = e.barcode
    """

    static func csvField(_ value: String) -> String {
        if value.contains(";") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}

enum BackupError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        }
    }
}
