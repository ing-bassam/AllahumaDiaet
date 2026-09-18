import { randomUUID } from 'expo-crypto';
import type { SQLiteDatabase } from 'expo-sqlite';

import { localDateKey, type MealType } from '../lib/format';
import { rankFoods, toLikePattern } from '../lib/localSearch';
import type { ActivityLevel, MacroSplit, Nutrients, Sex } from '../lib/nutrition';
import { mayOverwriteWithRemote } from '../lib/foodSource';
import type { ProductData } from '../lib/openFoodFacts';
import { UPSERT_FOOD_ITEM_SQL } from './migrations';

export type Profile = {
  id: string;
  age: number;
  sex: Sex;
  heightCm: number;
  weightKg: number;
  goalWeightKg: number;
  activityLevel: ActivityLevel;
  dailyCalorieGoal: number;
  macroSplit: MacroSplit;
};

export type FoodSource = 'openfoodfacts' | 'manual';

/** Zum Speichern: Produktdaten plus Herkunft. `barcode` ist eine GTIN oder ein `custom:`-Schlüssel. */
export type NewFoodItem = ProductData & { source: FoodSource };

export type FoodItem = NewFoodItem & {
  /** true, wenn der Nutzer die Werte korrigiert hat. Solche Datensätze überschreibt Open Food Facts nie. */
  userEdited: boolean;
  updatedAt: string | null;
};

export type LogEntryWithFood = {
  id: string;
  barcode: string;
  timestamp: string;
  mealType: MealType;
  grams: number;
  name: string;
  brand: string;
  /** Schnappschuss beim Eintragen – unabhängig von späteren Änderungen am Lebensmittel. */
  per100g: Nutrients;
};

export type LogEntryDetail = LogEntryWithFood & {
  date: string;
  servingSizeG: number | null;
  imageUrl: string | null;
  source: FoodSource;
};

type ProfileRow = {
  id: string;
  age: number;
  sex: Sex;
  height_cm: number;
  weight_kg: number;
  goal_weight_kg: number;
  activity_level: ActivityLevel;
  daily_calorie_goal: number;
  macro_split_protein: number;
  macro_split_carbs: number;
  macro_split_fat: number;
};

type FoodItemRow = {
  barcode: string;
  name: string;
  brand: string;
  calories_per_100g: number;
  protein_per_100g: number;
  carbs_per_100g: number;
  fat_per_100g: number;
  serving_size_g: number | null;
  image_url: string | null;
  source: FoodSource;
  user_edited: number;
  updated_at: string | null;
};

type LogEntryRow = {
  id: string;
  date: string;
  barcode: string;
  timestamp: string;
  meal_type: MealType;
  consumed_weight_g: number;
  calories_per_100g: number;
  protein_per_100g: number;
  carbs_per_100g: number;
  fat_per_100g: number;
  name: string;
  brand: string;
  serving_size_g: number | null;
  image_url: string | null;
  source: FoodSource;
};

function toFoodItem(row: FoodItemRow): FoodItem {
  return {
    barcode: row.barcode,
    name: row.name,
    brand: row.brand,
    caloriesPer100g: row.calories_per_100g,
    proteinPer100g: row.protein_per_100g,
    carbsPer100g: row.carbs_per_100g,
    fatPer100g: row.fat_per_100g,
    servingSizeG: row.serving_size_g,
    imageUrl: row.image_url,
    source: row.source,
    userEdited: row.user_edited === 1,
    updatedAt: row.updated_at,
  };
}

function toLogEntry(row: LogEntryRow): LogEntryDetail {
  return {
    id: row.id,
    date: row.date,
    barcode: row.barcode,
    timestamp: row.timestamp,
    mealType: row.meal_type,
    grams: row.consumed_weight_g,
    name: row.name,
    brand: row.brand,
    per100g: {
      calories: row.calories_per_100g,
      protein: row.protein_per_100g,
      carbs: row.carbs_per_100g,
      fat: row.fat_per_100g,
    },
    servingSizeG: row.serving_size_g,
    imageUrl: row.image_url,
    source: row.source,
  };
}

export function foodPer100g(food: ProductData): Nutrients {
  return { calories: food.caloriesPer100g, protein: food.proteinPer100g, carbs: food.carbsPer100g, fat: food.fatPer100g };
}

// ---------- Profil ----------

export async function getProfile(db: SQLiteDatabase): Promise<Profile | null> {
  const row = await db.getFirstAsync<ProfileRow>('SELECT * FROM user_profile LIMIT 1');
  if (!row) return null;
  return {
    id: row.id,
    age: row.age,
    sex: row.sex,
    heightCm: row.height_cm,
    weightKg: row.weight_kg,
    goalWeightKg: row.goal_weight_kg,
    activityLevel: row.activity_level,
    dailyCalorieGoal: row.daily_calorie_goal,
    macroSplit: {
      protein: row.macro_split_protein,
      carbs: row.macro_split_carbs,
      fat: row.macro_split_fat,
    },
  };
}

export async function saveProfile(db: SQLiteDatabase, profile: Omit<Profile, 'id'>): Promise<void> {
  const existing = await db.getFirstAsync<{ id: string }>('SELECT id FROM user_profile LIMIT 1');
  const id = existing?.id ?? randomUUID();
  await db.runAsync(
    `INSERT INTO user_profile (
       id, age, sex, height_cm, weight_kg, goal_weight_kg, activity_level,
       daily_calorie_goal, macro_split_protein, macro_split_carbs, macro_split_fat
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT (id) DO UPDATE SET
       age = excluded.age,
       sex = excluded.sex,
       height_cm = excluded.height_cm,
       weight_kg = excluded.weight_kg,
       goal_weight_kg = excluded.goal_weight_kg,
       activity_level = excluded.activity_level,
       daily_calorie_goal = excluded.daily_calorie_goal,
       macro_split_protein = excluded.macro_split_protein,
       macro_split_carbs = excluded.macro_split_carbs,
       macro_split_fat = excluded.macro_split_fat`,
    id,
    profile.age,
    profile.sex,
    profile.heightCm,
    profile.weightKg,
    profile.goalWeightKg,
    profile.activityLevel,
    profile.dailyCalorieGoal,
    profile.macroSplit.protein,
    profile.macroSplit.carbs,
    profile.macroSplit.fat,
  );
}

// ---------- Lebensmittel ----------

export async function getFoodItem(db: SQLiteDatabase, key: string): Promise<FoodItem | null> {
  const row = await db.getFirstAsync<FoodItemRow>('SELECT * FROM food_item WHERE barcode = ?', key);
  return row ? toFoodItem(row) : null;
}

/**
 * Legt ein Lebensmittel an oder aktualisiert es. Vom Nutzer korrigierte Datensätze bleiben unverändert
 * (Bedingung im SQL, siehe UPSERT_FOOD_ITEM_SQL).
 */
export async function saveFoodItem(db: SQLiteDatabase, item: NewFoodItem): Promise<void> {
  // Zweite Sicherung neben der Bedingung im SQL, damit die Regel auch im Code sichtbar ist.
  const existing = await getFoodItem(db, item.barcode);
  if (!mayOverwriteWithRemote(existing)) return;

  await db.runAsync(
    UPSERT_FOOD_ITEM_SQL,
    item.barcode,
    item.name,
    item.brand,
    item.caloriesPer100g,
    item.proteinPer100g,
    item.carbsPer100g,
    item.fatPer100g,
    item.servingSizeG,
    item.imageUrl,
    item.source,
  );
}

/** Speichert eine Korrektur des Nutzers dauerhaft und markiert das Lebensmittel als korrigiert. */
export async function updateFoodNutrients(
  db: SQLiteDatabase,
  key: string,
  values: { per100g: Nutrients; name?: string; brand?: string },
): Promise<void> {
  await db.runAsync(
    `UPDATE food_item SET
       calories_per_100g = ?,
       protein_per_100g = ?,
       carbs_per_100g = ?,
       fat_per_100g = ?,
       name = COALESCE(?, name),
       brand = COALESCE(?, brand),
       user_edited = 1,
       updated_at = ?
     WHERE barcode = ?`,
    values.per100g.calories,
    values.per100g.protein,
    values.per100g.carbs,
    values.per100g.fat,
    values.name ?? null,
    values.brand ?? null,
    new Date().toISOString(),
    key,
  );
}

/** Ersetzt eigene Werte wieder durch die Daten von Open Food Facts und hebt die Korrektur-Markierung auf. */
export async function restoreFoodFromOpenFoodFacts(db: SQLiteDatabase, product: ProductData): Promise<void> {
  await db.runAsync(
    `UPDATE food_item SET
       name = ?, brand = ?, calories_per_100g = ?, protein_per_100g = ?, carbs_per_100g = ?, fat_per_100g = ?,
       serving_size_g = ?, image_url = ?, source = 'openfoodfacts', user_edited = 0, updated_at = ?
     WHERE barcode = ?`,
    product.name,
    product.brand,
    product.caloriesPer100g,
    product.proteinPer100g,
    product.carbsPer100g,
    product.fatPer100g,
    product.servingSizeG,
    product.imageUrl,
    new Date().toISOString(),
    product.barcode,
  );
}

/** Lokale Suche nach Name oder Marke, Groß-/Kleinschreibung egal, Treffer am Wortanfang zuerst. */
export async function searchLocalFoods(db: SQLiteDatabase, query: string, limit: number): Promise<FoodItem[]> {
  const pattern = toLikePattern(query);
  // LIKE wählt grob vor (ASCII ohne Groß-/Kleinschreibung), rankFoods prüft exakt und sortiert.
  const rows = await db.getAllAsync<FoodItemRow>(
    "SELECT * FROM food_item WHERE name LIKE ? ESCAPE '\\' OR brand LIKE ? ESCAPE '\\'",
    pattern,
    pattern,
  );
  return rankFoods(rows.map(toFoodItem), query, limit);
}

/** Lokal gespeicherte Lebensmittel zu den angegebenen Schlüsseln (fehlende werden ausgelassen). */
export async function getFoodItemsByKeys(db: SQLiteDatabase, keys: string[]): Promise<FoodItem[]> {
  if (keys.length === 0) return [];
  const placeholders = keys.map(() => '?').join(', ');
  const rows = await db.getAllAsync<FoodItemRow>(`SELECT * FROM food_item WHERE barcode IN (${placeholders})`, ...keys);
  return rows.map(toFoodItem);
}

export async function getRecentFoods(db: SQLiteDatabase, limit: number): Promise<FoodItem[]> {
  const rows = await db.getAllAsync<FoodItemRow>(
    `SELECT f.*
       FROM food_item f
       JOIN (SELECT barcode, MAX(timestamp) AS last_used FROM log_entry GROUP BY barcode) u ON u.barcode = f.barcode
      ORDER BY u.last_used DESC
      LIMIT ?`,
    limit,
  );
  return rows.map(toFoodItem);
}

export async function getFrequentFoods(db: SQLiteDatabase, limit: number): Promise<FoodItem[]> {
  const rows = await db.getAllAsync<FoodItemRow>(
    `SELECT f.*
       FROM food_item f
       JOIN (SELECT barcode, COUNT(*) AS uses, MAX(timestamp) AS last_used FROM log_entry GROUP BY barcode) u
         ON u.barcode = f.barcode
      ORDER BY u.uses DESC, u.last_used DESC
      LIMIT ?`,
    limit,
  );
  return rows.map(toFoodItem);
}

// ---------- Tagebuch ----------

export async function addLogEntry(
  db: SQLiteDatabase,
  entry: { barcode: string; grams: number; mealType: MealType; per100g: Nutrients; at?: Date },
): Promise<void> {
  const at = entry.at ?? new Date();
  await db.runAsync(
    `INSERT INTO log_entry (
       id, date, timestamp, barcode, consumed_weight_g, meal_type,
       calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    randomUUID(),
    localDateKey(at),
    at.toISOString(),
    entry.barcode,
    entry.grams,
    entry.mealType,
    entry.per100g.calories,
    entry.per100g.protein,
    entry.per100g.carbs,
    entry.per100g.fat,
  );
}

const LOG_ENTRY_SELECT = `
  SELECT e.id, e.date, e.barcode, e.timestamp, e.meal_type, e.consumed_weight_g,
         e.calories_per_100g, e.protein_per_100g, e.carbs_per_100g, e.fat_per_100g,
         f.name, f.brand, f.serving_size_g, f.image_url, f.source
    FROM log_entry e
    JOIN food_item f ON f.barcode = e.barcode`;

export async function getLogEntry(db: SQLiteDatabase, id: string): Promise<LogEntryDetail | null> {
  const row = await db.getFirstAsync<LogEntryRow>(`${LOG_ENTRY_SELECT} WHERE e.id = ?`, id);
  return row ? toLogEntry(row) : null;
}

export async function getEntriesForDate(db: SQLiteDatabase, date: string): Promise<LogEntryWithFood[]> {
  const rows = await db.getAllAsync<LogEntryRow>(`${LOG_ENTRY_SELECT} WHERE e.date = ? ORDER BY e.timestamp ASC`, date);
  return rows.map(toLogEntry);
}

/** Tage mit mindestens einem Eintrag im angegebenen Bereich (Schlüssel wie „2026-09-16“). */
export async function getDatesWithEntries(db: SQLiteDatabase, fromDate: string, toDate: string): Promise<string[]> {
  const rows = await db.getAllAsync<{ date: string }>(
    'SELECT DISTINCT date FROM log_entry WHERE date BETWEEN ? AND ? ORDER BY date',
    fromDate,
    toDate,
  );
  return rows.map((row) => row.date);
}

/** Ändert nur die übergebenen Felder eines Eintrags. Das Lebensmittel selbst bleibt unberührt. */
export async function updateLogEntry(
  db: SQLiteDatabase,
  id: string,
  changes: { grams?: number; mealType?: MealType; per100g?: Nutrients },
): Promise<void> {
  const assignments: string[] = [];
  const params: (string | number)[] = [];

  if (changes.grams !== undefined) {
    assignments.push('consumed_weight_g = ?');
    params.push(changes.grams);
  }
  if (changes.mealType !== undefined) {
    assignments.push('meal_type = ?');
    params.push(changes.mealType);
  }
  if (changes.per100g !== undefined) {
    assignments.push('calories_per_100g = ?', 'protein_per_100g = ?', 'carbs_per_100g = ?', 'fat_per_100g = ?');
    params.push(changes.per100g.calories, changes.per100g.protein, changes.per100g.carbs, changes.per100g.fat);
  }
  if (assignments.length === 0) return;

  await db.runAsync(`UPDATE log_entry SET ${assignments.join(', ')} WHERE id = ?`, ...params, id);
}

export async function deleteLogEntry(db: SQLiteDatabase, id: string): Promise<void> {
  await db.runAsync('DELETE FROM log_entry WHERE id = ?', id);
}

/** Löscht Profil, Tagebuch und gespeicherte Lebensmittel. Das Schema bleibt erhalten. */
export async function deleteAllData(db: SQLiteDatabase): Promise<void> {
  await db.withExclusiveTransactionAsync(async (txn) => {
    // log_entry zuerst, weil es per Fremdschlüssel auf food_item zeigt.
    await txn.runAsync('DELETE FROM log_entry');
    await txn.runAsync('DELETE FROM food_item');
    await txn.runAsync('DELETE FROM user_profile');
  });
  // Gelöschte Zeilen bleiben sonst in freien Seiten und im WAL lesbar, bis sie überschrieben werden.
  await db.execAsync('PRAGMA wal_checkpoint(TRUNCATE); VACUUM;');
}
