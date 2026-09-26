// SQL der Schema-Versionen, ohne React-Native-Abhängigkeiten, damit tests/migrations.test.ts
// es mit node:sqlite gegen echte Datenbanken prüfen kann. Ausgeführt wird es in schema.ts.

/** Version 1: Ausgangsschema der ersten App-Version (neue Installation). Muss in einer Transaktion laufen; setzt user_version selbst. */
export const SCHEMA_V1_SQL = `
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
`;

/** Version 1 → 2. Muss in einer Transaktion laufen; setzt user_version selbst. */
export const MIGRATION_V2_SQL = `
  -- 1. Nährwert-Schnappschuss pro Eintrag, damit spätere Korrekturen alte Tage nicht verändern.
  --    REAL auch für kcal, damit pro Portion eingegebene Werte exakt erhalten bleiben.
  ALTER TABLE log_entry ADD COLUMN calories_per_100g REAL NOT NULL DEFAULT 0;
  ALTER TABLE log_entry ADD COLUMN protein_per_100g REAL NOT NULL DEFAULT 0;
  ALTER TABLE log_entry ADD COLUMN carbs_per_100g REAL NOT NULL DEFAULT 0;
  ALTER TABLE log_entry ADD COLUMN fat_per_100g REAL NOT NULL DEFAULT 0;

  -- Subqueries statt UPDATE … FROM, das erst ab SQLite 3.33 existiert.
  UPDATE log_entry SET
    calories_per_100g = (SELECT f.calories_per_100g FROM food_item f WHERE f.barcode = log_entry.barcode),
    protein_per_100g = (SELECT f.protein_per_100g FROM food_item f WHERE f.barcode = log_entry.barcode),
    carbs_per_100g = (SELECT f.carbs_per_100g FROM food_item f WHERE f.barcode = log_entry.barcode),
    fat_per_100g = (SELECT f.fat_per_100g FROM food_item f WHERE f.barcode = log_entry.barcode)
  WHERE EXISTS (SELECT 1 FROM food_item f WHERE f.barcode = log_entry.barcode);

  -- 2. Nutzerkorrekturen kennzeichnen. Die CHECK-Bedingung auf source bleibt unverändert.
  ALTER TABLE food_item ADD COLUMN user_edited INTEGER NOT NULL DEFAULT 0;
  ALTER TABLE food_item ADD COLUMN updated_at TEXT;

  -- 4. Indizes für Suche und „zuletzt verwendet“.
  CREATE INDEX idx_food_item_name ON food_item (name);
  CREATE INDEX idx_log_entry_barcode_timestamp ON log_entry (barcode, timestamp);

  PRAGMA user_version = 2;
`;

/** Version 2 → 3. Muss in einer Transaktion laufen; setzt user_version selbst. */
export const MIGRATION_V3_SQL = `
  -- 1, wenn daily_calorie_goal von Hand gesetzt wurde. Sonst folgt das Ziel der Berechnung und wird
  -- beim nächsten Speichern des Profils neu berechnet.
  ALTER TABLE user_profile ADD COLUMN calorie_goal_is_custom INTEGER NOT NULL DEFAULT 0;

  PRAGMA user_version = 3;
`;

export const LATEST_DATABASE_VERSION = 3;

/**
 * Speichert ein Produkt. Ein vom Nutzer korrigierter Datensatz (user_edited = 1) wird nie überschrieben;
 * die Bedingung steht bewusst im SQL, damit sie unabhängig von der Oberfläche gilt.
 * Parameter: barcode, name, brand, kcal, protein, carbs, fat, serving_size_g, image_url, source
 */
export const UPSERT_FOOD_ITEM_SQL = `
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
`;

/**
 * Entfernt gelöschte Zeilen auch physisch aus der Datenbankdatei. Läuft nach dem Löschen, außerhalb
 * einer Transaktion. Die Reihenfolge zählt: Im WAL-Modus schreibt VACUUM die bereinigte Datenbank
 * nur ins WAL; erst der Checkpoint danach überschreibt und kürzt die Hauptdatei und leert das WAL.
 */
export const SCRUB_DELETED_DATA_SQL = 'VACUUM; PRAGMA wal_checkpoint(TRUNCATE);';
