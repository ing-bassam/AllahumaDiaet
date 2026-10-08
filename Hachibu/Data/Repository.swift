import Foundation
import GRDB

/// Alle Lese- und Schreibzugriffe auf die Datenbank. Die Abfragen sind bewusst einfaches SQL.
struct Repository {
    let queue: DatabaseQueue

    // MARK: - Profil

    func profile() throws -> Profile? {
        try queue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM user_profile LIMIT 1") else { return nil }
            return Repository.profile(from: row)
        }
    }

    private static func profile(from row: Row) -> Profile {
        let sexText: String = row["sex"]
        let activityText: String = row["activity_level"]
        let custom: Int = row["calorie_goal_is_custom"]
        return Profile(
            id: row["id"],
            age: row["age"],
            sex: Sex(rawValue: sexText) ?? .female,
            heightCm: row["height_cm"],
            weightKg: row["weight_kg"],
            goalWeightKg: row["goal_weight_kg"],
            activityLevel: ActivityLevel(rawValue: activityText) ?? .sedentary,
            dailyCalorieGoal: row["daily_calorie_goal"],
            calorieGoalIsCustom: custom == 1,
            macroSplit: MacroSplit(protein: row["macro_split_protein"], carbs: row["macro_split_carbs"], fat: row["macro_split_fat"])
        )
    }

    /// Legt das Profil an oder aktualisiert das vorhandene (es gibt höchstens eines).
    func saveProfile(_ profile: Profile) throws {
        try queue.write { db in
            let existing: String? = try String.fetchOne(db, sql: "SELECT id FROM user_profile LIMIT 1")
            let id = existing ?? profile.id
            try db.execute(
                sql: """
                  INSERT INTO user_profile (
                    id, age, sex, height_cm, weight_kg, goal_weight_kg, activity_level,
                    daily_calorie_goal, calorie_goal_is_custom, macro_split_protein, macro_split_carbs, macro_split_fat
                  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                  ON CONFLICT (id) DO UPDATE SET
                    age = excluded.age,
                    sex = excluded.sex,
                    height_cm = excluded.height_cm,
                    weight_kg = excluded.weight_kg,
                    goal_weight_kg = excluded.goal_weight_kg,
                    activity_level = excluded.activity_level,
                    daily_calorie_goal = excluded.daily_calorie_goal,
                    calorie_goal_is_custom = excluded.calorie_goal_is_custom,
                    macro_split_protein = excluded.macro_split_protein,
                    macro_split_carbs = excluded.macro_split_carbs,
                    macro_split_fat = excluded.macro_split_fat
                """,
                arguments: [
                    id, profile.age, profile.sex.rawValue, profile.heightCm, profile.weightKg, profile.goalWeightKg,
                    profile.activityLevel.rawValue, profile.dailyCalorieGoal, profile.calorieGoalIsCustom ? 1 : 0,
                    profile.macroSplit.protein, profile.macroSplit.carbs, profile.macroSplit.fat,
                ]
            )
        }
    }

    // MARK: - Lebensmittel

    private static func food(from row: Row) -> FoodItem {
        let sourceText: String = row["source"]
        let edited: Int = row["user_edited"]
        let favorite: Int = row["favorite"]
        return FoodItem(
            barcode: row["barcode"],
            name: row["name"],
            brand: row["brand"],
            per100g: Nutrients(
                calories: row["calories_per_100g"],
                protein: row["protein_per_100g"],
                carbs: row["carbs_per_100g"],
                fat: row["fat_per_100g"]
            ),
            servingSizeG: row["serving_size_g"],
            imageUrl: row["image_url"],
            source: FoodSource(rawValue: sourceText) ?? .manual,
            userEdited: edited == 1,
            favorite: favorite == 1
        )
    }

    func foodItem(key: String) throws -> FoodItem? {
        try queue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM food_item WHERE barcode = ?", arguments: [key]) else { return nil }
            return Repository.food(from: row)
        }
    }

    /// Speichert ein Produkt von Open Food Facts oder ein eigenes Lebensmittel. Korrigierte Datensätze
    /// bleiben unverändert (siehe Migrations.upsertFoodItem).
    func saveFood(key: String, name: String, brand: String, per100g: Nutrients, servingSizeG: Double?, imageUrl: String?, source: FoodSource) throws {
        try queue.write { db in
            try Repository.upsertFood(db, key: key, name: name, brand: brand, per100g: per100g, servingSizeG: servingSizeG, imageUrl: imageUrl, source: source)
        }
    }

    private static func upsertFood(_ db: GRDB.Database, key: String, name: String, brand: String, per100g: Nutrients, servingSizeG: Double?, imageUrl: String?, source: FoodSource) throws {
        try db.execute(
            sql: Migrations.upsertFoodItem,
            arguments: [key, name, brand, per100g.calories, per100g.protein, per100g.carbs, per100g.fat, servingSizeG, imageUrl, source.rawValue]
        )
    }

    func saveProduct(_ product: ProductData) throws {
        try saveFood(
            key: product.barcode, name: product.name, brand: product.brand, per100g: product.per100g,
            servingSizeG: product.servingSizeG, imageUrl: product.imageUrl, source: .openfoodfacts
        )
    }

    /// Nutzerkorrektur: Werte überschreiben und als korrigiert markieren.
    func updateFoodNutrients(key: String, per100g: Nutrients, name: String, brand: String) throws {
        try queue.write { db in
            try db.execute(
                sql: """
                  UPDATE food_item SET
                    name = ?, brand = ?, calories_per_100g = ?, protein_per_100g = ?, carbs_per_100g = ?, fat_per_100g = ?,
                    user_edited = 1, updated_at = ?
                  WHERE barcode = ?
                """,
                arguments: [name, brand, per100g.calories, per100g.protein, per100g.carbs, per100g.fat, Formatting.isoTimestamp(Date()), key]
            )
        }
    }

    /// Eigene Werte verwerfen und wieder die Daten von Open Food Facts verwenden.
    func restoreFromOpenFoodFacts(_ product: ProductData) throws {
        try queue.write { db in
            try db.execute(
                sql: """
                  UPDATE food_item SET
                    name = ?, brand = ?, calories_per_100g = ?, protein_per_100g = ?, carbs_per_100g = ?, fat_per_100g = ?,
                    serving_size_g = ?, image_url = ?, source = 'openfoodfacts', user_edited = 0, updated_at = ?
                  WHERE barcode = ?
                """,
                arguments: [
                    product.name, product.brand, product.caloriesPer100g, product.proteinPer100g, product.carbsPer100g, product.fatPer100g,
                    product.servingSizeG, product.imageUrl, Formatting.isoTimestamp(Date()), product.barcode,
                ]
            )
        }
    }

    func searchLocalFoods(query: String, limit: Int) throws -> [FoodItem] {
        let pattern = LocalSearch.toLikePattern(query)
        let rows = try queue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM food_item WHERE barcode != ? AND (name LIKE ? ESCAPE '\\' OR brand LIKE ? ESCAPE '\\')",
                arguments: [FoodKey.quickEntryKey, pattern, pattern]
            )
        }
        return LocalSearch.rank(rows.map(Repository.food(from:)), query: query, limit: limit)
    }

    func foodItems(keys: [String]) throws -> [FoodItem] {
        guard !keys.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: keys.count).joined(separator: ", ")
        return try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM food_item WHERE barcode IN (\(placeholders))", arguments: StatementArguments(keys))
                .map(Repository.food(from:))
        }
    }

    func recentFoods(limit: Int) throws -> [FoodItem] {
        try queue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                  SELECT f.* FROM food_item f
                    JOIN (SELECT barcode, MAX(timestamp) AS last_used FROM log_entry GROUP BY barcode) u ON u.barcode = f.barcode
                   WHERE f.barcode != ?
                   ORDER BY u.last_used DESC
                   LIMIT ?
                """,
                arguments: [FoodKey.quickEntryKey, limit]
            ).map(Repository.food(from:))
        }
    }

    func frequentFoods(limit: Int) throws -> [FoodItem] {
        try queue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                  SELECT f.* FROM food_item f
                    JOIN (SELECT barcode, COUNT(*) AS uses, MAX(timestamp) AS last_used FROM log_entry GROUP BY barcode) u
                      ON u.barcode = f.barcode
                   WHERE f.barcode != ?
                   ORDER BY u.uses DESC, u.last_used DESC
                   LIMIT ?
                """,
                arguments: [FoodKey.quickEntryKey, limit]
            ).map(Repository.food(from:))
        }
    }

    func favoriteFoods() throws -> [FoodItem] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM food_item WHERE favorite = 1 ORDER BY name COLLATE NOCASE").map(Repository.food(from:))
        }
    }

    func setFavorite(key: String, _ favorite: Bool) throws {
        try queue.write { db in
            try db.execute(sql: "UPDATE food_item SET favorite = ? WHERE barcode = ?", arguments: [favorite ? 1 : 0, key])
        }
    }

    /// Die zuletzt eingetragene Menge dieses Lebensmittels, zum Vorausfüllen.
    func lastAmount(key: String) throws -> Double? {
        try queue.read { db in
            try Double.fetchOne(db, sql: "SELECT consumed_weight_g FROM log_entry WHERE barcode = ? ORDER BY timestamp DESC LIMIT 1", arguments: [key])
        }
    }

    // MARK: - Tagebuch

    private static let entrySelect = """
      SELECT e.id, e.date, e.barcode, e.timestamp, e.meal_type, e.consumed_weight_g,
             e.calories_per_100g, e.protein_per_100g, e.carbs_per_100g, e.fat_per_100g, e.note,
             f.name, f.brand, f.serving_size_g, f.image_url, f.source
        FROM log_entry e
        JOIN food_item f ON f.barcode = e.barcode
    """

    private static func entry(from row: Row) -> LogEntry {
        let mealText: String = row["meal_type"]
        let sourceText: String = row["source"]
        return LogEntry(
            id: row["id"],
            date: row["date"],
            timestamp: row["timestamp"],
            barcode: row["barcode"],
            grams: row["consumed_weight_g"],
            mealType: MealType(rawValue: mealText) ?? .snack,
            per100g: Nutrients(
                calories: row["calories_per_100g"],
                protein: row["protein_per_100g"],
                carbs: row["carbs_per_100g"],
                fat: row["fat_per_100g"]
            ),
            note: row["note"],
            name: row["name"],
            brand: row["brand"],
            servingSizeG: row["serving_size_g"],
            imageUrl: row["image_url"],
            source: FoodSource(rawValue: sourceText) ?? .manual
        )
    }

    @discardableResult
    func addEntry(key: String, grams: Double, mealType: MealType, per100g: Nutrients, at: Date = Date(), note: String? = nil) throws -> String {
        let id = UUID().uuidString.lowercased()
        try queue.write { db in
            try Repository.insertEntry(db, id: id, key: key, grams: grams, mealType: mealType, per100g: per100g, at: at, note: note)
        }
        return id
    }

    private static func insertEntry(_ db: GRDB.Database, id: String, key: String, grams: Double, mealType: MealType, per100g: Nutrients, at: Date, note: String?) throws {
        try db.execute(
            sql: """
              INSERT INTO log_entry (
                id, date, timestamp, barcode, consumed_weight_g, meal_type,
                calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, note
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                id, Formatting.dateKey(at), Formatting.isoTimestamp(at), key, grams, mealType.rawValue,
                per100g.calories, per100g.protein, per100g.carbs, per100g.fat, note,
            ]
        )
    }

    /// Schnelleintrag ohne Lebensmittel: Die Werte gelten für 100 g eines festen Pseudo-Produkts.
    func addQuickEntry(nutrients: Nutrients, note: String?, mealType: MealType, at: Date = Date()) throws {
        let id = UUID().uuidString.lowercased()
        try queue.write { db in
            try db.execute(
                sql: """
                  INSERT OR IGNORE INTO food_item (barcode, name, brand, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, source)
                  VALUES (?, 'Schnelleintrag', '', 0, 0, 0, 0, 'manual')
                """,
                arguments: [FoodKey.quickEntryKey]
            )
            try Repository.insertEntry(db, id: id, key: FoodKey.quickEntryKey, grams: 100, mealType: mealType, per100g: nutrients, at: at, note: note)
        }
    }

    func entry(id: String) throws -> LogEntry? {
        try queue.read { db in
            guard let row = try Row.fetchOne(db, sql: Repository.entrySelect + " WHERE e.id = ?", arguments: [id]) else { return nil }
            return Repository.entry(from: row)
        }
    }

    func entries(dateKey: String) throws -> [LogEntry] {
        try queue.read { db in
            try Row.fetchAll(db, sql: Repository.entrySelect + " WHERE e.date = ? ORDER BY e.timestamp ASC", arguments: [dateKey])
                .map(Repository.entry(from:))
        }
    }

    func datesWithEntries(from: String, to: String) throws -> [String] {
        try queue.read { db in
            try String.fetchAll(db, sql: "SELECT DISTINCT date FROM log_entry WHERE date BETWEEN ? AND ? ORDER BY date", arguments: [from, to])
        }
    }

    /// Kalorien und Makros je Tag im Zeitraum, für Statistiken. Tage ohne Einträge fehlen.
    func dailyTotals(from: String, to: String) throws -> [String: Nutrients] {
        try queue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                  SELECT date,
                         SUM(calories_per_100g * consumed_weight_g / 100.0) AS calories,
                         SUM(protein_per_100g * consumed_weight_g / 100.0) AS protein,
                         SUM(carbs_per_100g * consumed_weight_g / 100.0) AS carbs,
                         SUM(fat_per_100g * consumed_weight_g / 100.0) AS fat
                    FROM log_entry
                   WHERE date BETWEEN ? AND ?
                   GROUP BY date
                """,
                arguments: [from, to]
            )
            var result: [String: Nutrients] = [:]
            for row in rows {
                let key: String = row["date"]
                result[key] = Nutrients(calories: row["calories"], protein: row["protein"], carbs: row["carbs"], fat: row["fat"])
            }
            return result
        }
    }

    /// Schreibt Menge, Mahlzeit, Nährwerte und Notiz des Eintrags.
    func updateEntry(_ entry: LogEntry) throws {
        try queue.write { db in
            try db.execute(
                sql: """
                  UPDATE log_entry SET
                    consumed_weight_g = ?, meal_type = ?, calories_per_100g = ?, protein_per_100g = ?, carbs_per_100g = ?, fat_per_100g = ?, note = ?
                  WHERE id = ?
                """,
                arguments: [entry.grams, entry.mealType.rawValue, entry.per100g.calories, entry.per100g.protein, entry.per100g.carbs, entry.per100g.fat, entry.note, entry.id]
            )
        }
    }

    func deleteEntry(id: String) throws {
        try queue.write { db in
            try db.execute(sql: "DELETE FROM log_entry WHERE id = ?", arguments: [id])
        }
    }

    /// Trägt Einträge eines anderen Tages noch einmal auf `day` ein: gleiche Menge, gleiche Mahlzeit,
    /// gleiche Uhrzeit und dieselben Nährwerte, die damals galten. Alles oder nichts.
    func copyEntries(_ entries: [LogEntry], to day: Date) throws {
        try queue.write { db in
            for entry in entries {
                let time = Formatting.parseIsoTimestamp(entry.timestamp) ?? Date()
                try Repository.insertEntry(
                    db, id: UUID().uuidString.lowercased(), key: entry.barcode, grams: entry.grams, mealType: entry.mealType,
                    per100g: entry.per100g, at: DateMath.combine(day: day, time: time), note: entry.note
                )
            }
        }
    }

    // MARK: - Gewicht

    func saveWeight(dateKey: String, weightKg: Double) throws {
        try queue.write { db in
            try db.execute(
                sql: """
                  INSERT INTO weight_log (date, weight_kg, created_at) VALUES (?, ?, ?)
                  ON CONFLICT (date) DO UPDATE SET weight_kg = excluded.weight_kg, created_at = excluded.created_at
                """,
                arguments: [dateKey, weightKg, Formatting.isoTimestamp(Date())]
            )
        }
    }

    func weights(limit: Int = 365) throws -> [WeightEntry] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT date, weight_kg FROM weight_log ORDER BY date DESC LIMIT ?", arguments: [limit])
                .map { WeightEntry(date: $0["date"], weightKg: $0["weight_kg"]) }
        }
    }

    func deleteWeight(dateKey: String) throws {
        try queue.write { db in
            try db.execute(sql: "DELETE FROM weight_log WHERE date = ?", arguments: [dateKey])
        }
    }

    // MARK: - Alles löschen

    /// Löscht Profil, Tagebuch, Lebensmittel und Gewichtsverlauf. Das Schema bleibt erhalten.
    func deleteAllData() throws {
        try queue.write { db in
            // log_entry zuerst, weil es per Fremdschlüssel auf food_item zeigt.
            try db.execute(sql: "DELETE FROM log_entry")
            try db.execute(sql: "DELETE FROM food_item")
            try db.execute(sql: "DELETE FROM user_profile")
            try db.execute(sql: "DELETE FROM weight_log")
        }
        try scrubDeletedData()
    }

    /// Entfernt gelöschte Zeilen auch physisch aus der Datei. Im WAL-Modus schreibt VACUUM die bereinigte
    /// Datenbank nur ins WAL; erst der Checkpoint danach überschreibt und kürzt die Hauptdatei.
    func scrubDeletedData() throws {
        try queue.writeWithoutTransaction { db in
            try db.execute(sql: "VACUUM")
            _ = try Row.fetchOne(db, sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
    }

    // MARK: - Statistik-Hilfen

    func entryCount() throws -> Int {
        try queue.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM log_entry") ?? 0 }
    }

    func distinctEntryDayCount() throws -> Int {
        try queue.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(DISTINCT date) FROM log_entry") ?? 0 }
    }
}
