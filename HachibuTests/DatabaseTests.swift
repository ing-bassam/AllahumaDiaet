import Foundation
import Testing
@testable import Hachibu

@Suite struct MigrationTests {
    @Test func neueDatenbankHatAktuellesSchema() throws {
        let queue = try AppDatabase.openInMemory()
        #expect(try AppDatabase.userVersion(queue) == Migrations.latestVersion)
        #expect(try AppDatabase.columns(queue, table: "food_item").contains("favorite"))
        #expect(try AppDatabase.columns(queue, table: "log_entry").contains("note"))
        #expect(try AppDatabase.columns(queue, table: "user_profile").contains("calorie_goal_is_custom"))
        #expect(try AppDatabase.columns(queue, table: "weight_log") == ["date", "weight_kg", "created_at"])
    }

    @Test func bestehendeDatenbankDerAltenAppWirdUebernommen() throws {
        // Stand der bisherigen App: Schema v3 mit echten Daten.
        let queue = try AppDatabase.openInMemory(upTo: 3)
        #expect(try AppDatabase.userVersion(queue) == 3)
        try AppDatabase.execute(queue, sql: """
          INSERT INTO user_profile VALUES ('p1', 30, 'male', 180, 80, 75, 'sedentary', 1990, 0.3, 0.5, 0.2, 0);
          INSERT INTO food_item (barcode, name, brand, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, serving_size_g, image_url, source)
            VALUES ('4006381333931', 'Skyr', 'Marke', 63, 11, 4, 0.2, 500, NULL, 'openfoodfacts');
          INSERT INTO log_entry (id, date, timestamp, barcode, consumed_weight_g, meal_type, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g)
            VALUES ('e1', '2026-09-14', '2026-09-14T07:00:00.000Z', '4006381333931', 250, 'breakfast', 63, 11, 4, 0.2);
        """)

        try AppDatabase.migrate(queue)
        #expect(try AppDatabase.userVersion(queue) == 4)

        let repo = Repository(queue: queue)
        let profile = try repo.profile()
        #expect(profile?.dailyCalorieGoal == 1990)
        #expect(profile?.calorieGoalIsCustom == false)
        let food = try repo.foodItem(key: "4006381333931")
        #expect(food?.name == "Skyr")
        #expect(food?.favorite == false)
        let entries = try repo.entries(dateKey: "2026-09-14")
        #expect(entries.count == 1)
        #expect(entries[0].grams == 250)
        #expect(entries[0].note == nil)
        #expect(entries[0].totals == Nutrients(calories: 158, protein: 27.5, carbs: 10, fat: 0.5))
    }

    @Test func migrationLaeuftNichtDoppelt() throws {
        let queue = try AppDatabase.openInMemory()
        try AppDatabase.migrate(queue)
        #expect(try AppDatabase.userVersion(queue) == Migrations.latestVersion)
    }
}

@Suite struct RepositoryTests {
    func makeRepo() throws -> Repository {
        Repository(queue: try AppDatabase.openInMemory())
    }

    let skyr = ProductData(barcode: "4006381333931", name: "Skyr", brand: "Marke", caloriesPer100g: 63, proteinPer100g: 11, carbsPer100g: 4, fatPer100g: 0.2, servingSizeG: 500, imageUrl: nil)

    @Test func profilSpeichernUndLesen() throws {
        let repo = try makeRepo()
        #expect(try repo.profile() == nil)
        let profile = Profile(id: "p1", age: 30, sex: .male, heightCm: 180, weightKg: 80, goalWeightKg: 72, activityLevel: .sedentary, dailyCalorieGoal: 1990, calorieGoalIsCustom: false, macroSplit: .standard)
        try repo.saveProfile(profile)
        #expect(try repo.profile() == profile)
        var changed = profile
        changed.dailyCalorieGoal = 1800
        changed.calorieGoalIsCustom = true
        try repo.saveProfile(changed)
        #expect(try repo.profile()?.dailyCalorieGoal == 1800)
        #expect(try repo.profile()?.calorieGoalIsCustom == true)
    }

    @Test func korrigierteProdukteWerdenNichtUeberschrieben() throws {
        let repo = try makeRepo()
        try repo.saveProduct(skyr)
        try repo.updateFoodNutrients(key: skyr.barcode, per100g: Nutrients(calories: 70, protein: 11, carbs: 4, fat: 0.2), name: "Skyr", brand: "Marke")
        var newer = skyr
        newer.name = "Skyr neu"
        newer.caloriesPer100g = 99
        try repo.saveProduct(newer)
        let stored = try repo.foodItem(key: skyr.barcode)
        #expect(stored?.name == "Skyr")
        #expect(stored?.per100g.calories == 70)
        #expect(stored?.userEdited == true)
        try repo.restoreFromOpenFoodFacts(newer)
        #expect(try repo.foodItem(key: skyr.barcode)?.name == "Skyr neu")
        #expect(try repo.foodItem(key: skyr.barcode)?.userEdited == false)
    }

    @Test func tagebuchUndLetzteMenge() throws {
        let repo = try makeRepo()
        try repo.saveProduct(skyr)
        // Mittagszeit in Berlin: fällt in jeder Zeitzone des Test-Rechners auf denselben Kalendertag.
        let at = TestCalendar.date(2026, 9, 14, 12, 30)
        try repo.addEntry(key: skyr.barcode, grams: 250, mealType: .breakfast, per100g: skyr.per100g, at: at)
        try repo.addEntry(key: skyr.barcode, grams: 150, mealType: .snack, per100g: skyr.per100g, at: at.addingTimeInterval(3600))
        let key = Formatting.dateKey(at)
        let entries = try repo.entries(dateKey: key)
        #expect(entries.count == 2)
        #expect(entries[0].grams == 250)
        #expect(try repo.lastAmount(key: skyr.barcode) == 150)
        #expect(try repo.datesWithEntries(from: "2026-09-01", to: "2026-09-30") == [key])
        #expect(try repo.recentFoods(limit: 5).map { $0.barcode } == [skyr.barcode])
        #expect(try repo.frequentFoods(limit: 5).map { $0.barcode } == [skyr.barcode])

        var edited = entries[0]
        edited.grams = 300
        edited.mealType = .lunch
        try repo.updateEntry(edited)
        #expect(try repo.entry(id: edited.id)?.grams == 300)
        #expect(try repo.entry(id: edited.id)?.mealType == .lunch)

        try repo.deleteEntry(id: edited.id)
        #expect(try repo.entries(dateKey: key).count == 1)
    }

    @Test func schnelleintrag() throws {
        let repo = try makeRepo()
        try repo.addQuickEntry(nutrients: Nutrients(calories: 650, protein: 30, carbs: 60, fat: 25), note: "Kantine", mealType: .lunch, at: TestCalendar.date(2026, 9, 14, 12))
        try repo.addQuickEntry(nutrients: Nutrients(calories: 200, protein: 0, carbs: 0, fat: 0), note: nil, mealType: .snack, at: TestCalendar.date(2026, 9, 14, 15))
        let entries = try repo.entries(dateKey: "2026-09-14")
        #expect(entries.count == 2)
        #expect(entries[0].displayName == "Kantine")
        #expect(entries[0].totals.calories == 650)
        #expect(entries[1].displayName == "Schnelleintrag")
        // Das Pseudo-Lebensmittel taucht nirgends als Vorschlag auf.
        #expect(try repo.recentFoods(limit: 5).isEmpty)
        #expect(try repo.frequentFoods(limit: 5).isEmpty)
        #expect(try repo.searchLocalFoods(query: "schnell", limit: 5).isEmpty)
    }

    @Test func favoritenUndSuche() throws {
        let repo = try makeRepo()
        try repo.saveProduct(skyr)
        try repo.saveFood(key: FoodKey.newCustomKey(), name: "Äpfel", brand: "", per100g: Nutrients(calories: 52, protein: 0.3, carbs: 14, fat: 0.2), servingSizeG: nil, imageUrl: nil, source: .manual)
        #expect(try repo.favoriteFoods().isEmpty)
        try repo.setFavorite(key: skyr.barcode, true)
        #expect(try repo.favoriteFoods().map { $0.name } == ["Skyr"])
        #expect(try repo.searchLocalFoods(query: "äpf", limit: 5).map { $0.name } == ["Äpfel"])
        #expect(try repo.searchLocalFoods(query: "sky", limit: 5).map { $0.name } == ["Skyr"])
        #expect(try repo.foodItems(keys: [skyr.barcode, "fehlt"]).count == 1)
    }

    @Test func mahlzeitKopieren() throws {
        let repo = try makeRepo()
        try repo.saveProduct(skyr)
        let yesterday = TestCalendar.date(2026, 9, 13, 13, 15)
        try repo.addEntry(key: skyr.barcode, grams: 200, mealType: .breakfast, per100g: skyr.per100g, at: yesterday)
        let entries = try repo.entries(dateKey: Formatting.dateKey(yesterday))
        try repo.copyEntries(entries, to: TestCalendar.localDay(2026, 9, 14))
        let copied = try repo.entries(dateKey: "2026-09-14")
        #expect(copied.count == 1)
        #expect(copied[0].grams == 200)
        #expect(copied[0].mealType == .breakfast)
        #expect(Formatting.time(copied[0].timestamp, calendar: TestCalendar.berlin) == "13:15")
    }

    @Test func tagessummenUndGewicht() throws {
        let repo = try makeRepo()
        try repo.saveProduct(skyr)
        try repo.addEntry(key: skyr.barcode, grams: 100, mealType: .breakfast, per100g: skyr.per100g, at: TestCalendar.date(2026, 9, 14, 12))
        try repo.addEntry(key: skyr.barcode, grams: 100, mealType: .dinner, per100g: skyr.per100g, at: TestCalendar.date(2026, 9, 14, 14))
        let totals = try repo.dailyTotals(from: "2026-09-10", to: "2026-09-20")
        #expect(totals["2026-09-14"]?.calories == 126)
        #expect(totals["2026-09-15"] == nil)

        try repo.saveWeight(dateKey: "2026-09-14", weightKg: 80.4)
        try repo.saveWeight(dateKey: "2026-09-14", weightKg: 80.2)
        try repo.saveWeight(dateKey: "2026-09-13", weightKg: 80.9)
        #expect(try repo.weights().map { $0.weightKg } == [80.2, 80.9])
        try repo.deleteWeight(dateKey: "2026-09-13")
        #expect(try repo.weights().count == 1)
    }

    @Test func allesLoeschen() throws {
        let repo = try makeRepo()
        try repo.saveProfile(Profile(id: "p1", age: 30, sex: .male, heightCm: 180, weightKg: 80, goalWeightKg: 72, activityLevel: .sedentary, dailyCalorieGoal: 1990, calorieGoalIsCustom: false, macroSplit: .standard))
        try repo.saveProduct(skyr)
        try repo.addEntry(key: skyr.barcode, grams: 100, mealType: .breakfast, per100g: skyr.per100g)
        try repo.saveWeight(dateKey: "2026-09-14", weightKg: 80)
        try repo.deleteAllData()
        #expect(try repo.profile() == nil)
        #expect(try repo.entryCount() == 0)
        #expect(try AppDatabase.count(repo.queue, table: "food_item") == 0)
        #expect(try repo.weights().isEmpty)
        #expect(try AppDatabase.userVersion(repo.queue) == Migrations.latestVersion)
    }
}

@Suite struct BackupTests {
    let skyr = ProductData(barcode: "4006381333931", name: "Skyr", brand: "Marke", caloriesPer100g: 63, proteinPer100g: 11, carbsPer100g: 4, fatPer100g: 0.2, servingSizeG: 500, imageUrl: nil)

    @Test func sicherungHinUndZurueck() throws {
        let source = Repository(queue: try AppDatabase.openInMemory())
        let profile = Profile(id: "p1", age: 30, sex: .male, heightCm: 180, weightKg: 80, goalWeightKg: 72, activityLevel: .sedentary, dailyCalorieGoal: 1990, calorieGoalIsCustom: false, macroSplit: .standard)
        try source.saveProfile(profile)
        try source.saveProduct(skyr)
        try source.setFavorite(key: skyr.barcode, true)
        try source.addEntry(key: skyr.barcode, grams: 250, mealType: .breakfast, per100g: skyr.per100g, at: TestCalendar.date(2026, 9, 14, 12))
        try source.addQuickEntry(nutrients: Nutrients(calories: 500, protein: 0, carbs: 0, fat: 0), note: "Kantine", mealType: .lunch, at: TestCalendar.date(2026, 9, 14, 13))
        try source.saveWeight(dateKey: "2026-09-14", weightKg: 80)

        let document = try source.exportBackup(appVersion: "2.0.0")
        #expect(document.validate() == nil)
        let data = try document.encoded()
        let decoded = try BackupDocument.decode(data)
        #expect(decoded.foods.count == 2)
        #expect(decoded.entries.count == 2)

        let target = Repository(queue: try AppDatabase.openInMemory())
        try target.importBackup(decoded)
        let restored = try target.profile()
        #expect(restored?.age == 30)
        #expect(restored?.dailyCalorieGoal == 1990)
        #expect(try target.foodItem(key: skyr.barcode)?.favorite == true)
        let entries = try target.entries(dateKey: "2026-09-14")
        #expect(entries.count == 2)
        #expect(entries[1].displayName == "Kantine")
        #expect(try target.weights().first?.weightKg == 80)
    }

    @Test func fremdeDateienWerdenAbgelehnt() throws {
        var document = BackupDocument(exportedAt: Date(), appVersion: "2.0.0", profile: nil, foods: [], entries: [], weights: [])
        #expect(document.validate() == nil)
        document.format = "irgendwas"
        #expect(document.validate() != nil)
        var broken = BackupDocument(exportedAt: Date(), appVersion: "2.0.0", profile: nil, foods: [], entries: [
            BackupDocument.BackupEntry(id: "e1", date: "2026-09-14", timestamp: "2026-09-14T07:00:00.000Z", key: "fehlt", grams: 100, mealType: "lunch", caloriesPer100g: 1, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0, note: nil),
        ], weights: [])
        #expect(broken.validate() != nil)
        broken.entries = []
        broken.version = 99
        #expect(broken.validate() != nil)
        #expect(throws: (any Error).self) { try BackupDocument.decode(Data("{}".utf8)) }
    }

    @Test func csvExport() throws {
        let repo = Repository(queue: try AppDatabase.openInMemory())
        try repo.saveProduct(skyr)
        try repo.addEntry(key: skyr.barcode, grams: 250, mealType: .breakfast, per100g: skyr.per100g, at: TestCalendar.date(2026, 9, 14, 12))
        let csv = try repo.exportCSV()
        let lines = csv.split(separator: "\r\n").map(String.init)
        #expect(lines.count == 2)
        #expect(lines[0].hasPrefix("Datum;Uhrzeit;Mahlzeit;Lebensmittel"))
        #expect(lines[1].hasPrefix("2026-09-14;"))
        #expect(lines[1].contains(";Frühstück;Skyr;Marke;250;158;27,5;10;0,5"))
        #expect(Repository.csvField("Müsli; kernig") == "\"Müsli; kernig\"")
    }
}
