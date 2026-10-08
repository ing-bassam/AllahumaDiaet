import Foundation

/// SQL der Schema-Versionen. Versionen 1 bis 3 stammen unverändert aus der bisherigen App, damit die
/// vorhandene Datenbankdatei der Nutzer weiterverwendet wird. Jede Migration setzt user_version selbst
/// und läuft in einer Transaktion (siehe AppDatabase).
enum Migrations {
    static let latestVersion = 4

    /// Version 1: Ausgangsschema der ersten App-Version (neue Installation).
    static let schemaV1 = """
      CREATE TABLE user_profile (
        id TEXT PRIMARY KEY NOT NULL,
        age INTEGER NOT NULL,
        sex TEXT NOT NULL CHECK (sex IN ('male', 'female')),
        height_cm REAL NOT NULL,
        weight_kg REAL NOT NULL,
        goal_weight_kg REAL NOT NULL,
        activity_level TEXT NOT NULL,
        daily_calorie_goal INTEGER NOT NULL,
        macro_split_protein REAL NOT NULL,
        macro_split_carbs REAL NOT NULL,
        macro_split_fat REAL NOT NULL
      );

      CREATE TABLE food_item (
        barcode TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        brand TEXT NOT NULL DEFAULT '',
        calories_per_100g INTEGER NOT NULL,
        protein_per_100g REAL NOT NULL,
        carbs_per_100g REAL NOT NULL,
        fat_per_100g REAL NOT NULL,
        serving_size_g REAL,
        image_url TEXT,
        source TEXT NOT NULL CHECK (source IN ('openfoodfacts', 'manual'))
      );

      CREATE TABLE log_entry (
        id TEXT PRIMARY KEY NOT NULL,
        date TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        barcode TEXT NOT NULL REFERENCES food_item (barcode),
        consumed_weight_g REAL NOT NULL,
        meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack'))
      );

      CREATE INDEX idx_log_entry_date ON log_entry (date);

      PRAGMA user_version = 1;
    """

    /// Version 1 → 2: Nährwert-Schnappschuss pro Eintrag, Kennzeichnung von Korrekturen, Indizes.
    static let migrationV2 = """
      ALTER TABLE log_entry ADD COLUMN calories_per_100g REAL NOT NULL DEFAULT 0;
      ALTER TABLE log_entry ADD COLUMN protein_per_100g REAL NOT NULL DEFAULT 0;
      ALTER TABLE log_entry ADD COLUMN carbs_per_100g REAL NOT NULL DEFAULT 0;
      ALTER TABLE log_entry ADD COLUMN fat_per_100g REAL NOT NULL DEFAULT 0;

      UPDATE log_entry SET
        calories_per_100g = (SELECT f.calories_per_100g FROM food_item f WHERE f.barcode = log_entry.barcode),
        protein_per_100g = (SELECT f.protein_per_100g FROM food_item f WHERE f.barcode = log_entry.barcode),
        carbs_per_100g = (SELECT f.carbs_per_100g FROM food_item f WHERE f.barcode = log_entry.barcode),
        fat_per_100g = (SELECT f.fat_per_100g FROM food_item f WHERE f.barcode = log_entry.barcode)
      WHERE EXISTS (SELECT 1 FROM food_item f WHERE f.barcode = log_entry.barcode);

      ALTER TABLE food_item ADD COLUMN user_edited INTEGER NOT NULL DEFAULT 0;
      ALTER TABLE food_item ADD COLUMN updated_at TEXT;

      CREATE INDEX idx_food_item_name ON food_item (name);
      CREATE INDEX idx_log_entry_barcode_timestamp ON log_entry (barcode, timestamp);

      PRAGMA user_version = 2;
    """

    /// Version 2 → 3: Merker, ob das Tagesziel von Hand gesetzt wurde.
    static let migrationV3 = """
      ALTER TABLE user_profile ADD COLUMN calorie_goal_is_custom INTEGER NOT NULL DEFAULT 0;

      PRAGMA user_version = 3;
    """

    /// Version 3 → 4 (SwiftUI-App): Favoriten, Notiz für Schnelleinträge, Gewichtsverlauf.
    static let migrationV4 = """
      ALTER TABLE food_item ADD COLUMN favorite INTEGER NOT NULL DEFAULT 0;
      ALTER TABLE log_entry ADD COLUMN note TEXT;

      CREATE TABLE weight_log (
        date TEXT PRIMARY KEY NOT NULL,
        weight_kg REAL NOT NULL,
        created_at TEXT NOT NULL
      );

      PRAGMA user_version = 4;
    """

    /// Speichert ein Produkt. Ein vom Nutzer korrigierter Datensatz (user_edited = 1) wird nie überschrieben;
    /// die Bedingung steht bewusst im SQL, damit sie unabhängig von der Oberfläche gilt.
    /// Parameter: barcode, name, brand, kcal, protein, carbs, fat, serving_size_g, image_url, source
    static let upsertFoodItem = """
      INSERT INTO food_item (
        barcode, name, brand, calories_per_100g, protein_per_100g, carbs_per_100g,
        fat_per_100g, serving_size_g, image_url, source
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT (barcode) DO UPDATE SET
        name = excluded.name,
        brand = excluded.brand,
        calories_per_100g = excluded.calories_per_100g,
        protein_per_100g = excluded.protein_per_100g,
        carbs_per_100g = excluded.carbs_per_100g,
        fat_per_100g = excluded.fat_per_100g,
        serving_size_g = excluded.serving_size_g,
        image_url = excluded.image_url,
        source = excluded.source
      WHERE food_item.user_edited = 0
    """
}
