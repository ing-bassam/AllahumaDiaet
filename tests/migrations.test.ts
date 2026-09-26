import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import { DatabaseSync } from 'node:sqlite';

import {
  LATEST_DATABASE_VERSION,
  MIGRATION_V2_SQL,
  MIGRATION_V3_SQL,
  SCHEMA_V1_SQL,
  SCRUB_DELETED_DATA_SQL,
  UPSERT_FOOD_ITEM_SQL,
} from '../src/db/migrations.ts';

/** Datenbank im Zustand einer Version-1-Installation mit echten Einträgen. */
function createV1Database() {
  const db = new DatabaseSync(':memory:');
  db.exec('PRAGMA foreign_keys = ON;');
  db.exec(SCHEMA_V1_SQL);
  db.exec(`
    INSERT INTO user_profile VALUES ('p1', 30, 'male', 180, 80, 75, 'sedentary', 1990, 0.3, 0.5, 0.2);
    INSERT INTO food_item VALUES ('4006381333931', 'Skyr', 'Marke', 63, 11, 4, 0.2, 500, NULL, 'openfoodfacts');
    INSERT INTO food_item VALUES ('96385074', 'Nüsse', '', 650, 20, 10, 55, NULL, NULL, 'manual');
    INSERT INTO log_entry VALUES ('e1', '2026-09-14', '2026-09-14T07:00:00.000Z', '4006381333931', 250, 'breakfast');
    INSERT INTO log_entry VALUES ('e2', '2026-09-14', '2026-09-14T15:00:00.000Z', '96385074', 30, 'snack');
    INSERT INTO log_entry VALUES ('e3', '2026-09-15', '2026-09-15T07:00:00.000Z', '4006381333931', 150, 'breakfast');
  `);
  return db;
}

const migrate = (db: DatabaseSync) => {
  db.exec('BEGIN EXCLUSIVE;');
  db.exec(MIGRATION_V2_SQL);
  db.exec('COMMIT;');
};

describe('Schema v1', () => {
  it('rollt bei einem Fehler vollständig zurück, auch user_version', () => {
    const db = new DatabaseSync(':memory:');
    // Erzwingt einen Fehler beim dritten CREATE TABLE, nachdem zwei Tabellen schon angelegt sind.
    db.exec('CREATE TABLE log_entry (x);');

    db.exec('BEGIN EXCLUSIVE;');
    assert.throws(() => db.exec(SCHEMA_V1_SQL));
    db.exec('ROLLBACK;');

    const tables = db.prepare("SELECT name FROM sqlite_master WHERE type = 'table'").all().map((row) => row.name);
    assert.deepEqual(tables, ['log_entry']);
    assert.equal((db.prepare('PRAGMA user_version').get() as { user_version: number }).user_version, 0);
  });
});

describe('Migration v1 → v2', () => {
  it('behält alle Daten und füllt die Schnappschüsse aus food_item', () => {
    const db = createV1Database();
    migrate(db);

    assert.equal((db.prepare('PRAGMA user_version').get() as { user_version: number }).user_version, 2);
    assert.equal((db.prepare('SELECT COUNT(*) AS n FROM user_profile').get() as { n: number }).n, 1);
    assert.equal((db.prepare('SELECT COUNT(*) AS n FROM food_item').get() as { n: number }).n, 2);

    const entries = db
      .prepare('SELECT id, consumed_weight_g, meal_type, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g FROM log_entry ORDER BY id')
      .all();
    assert.deepEqual(
      entries.map((e) => ({ ...e })),
      [
        { id: 'e1', consumed_weight_g: 250, meal_type: 'breakfast', calories_per_100g: 63, protein_per_100g: 11, carbs_per_100g: 4, fat_per_100g: 0.2 },
        { id: 'e2', consumed_weight_g: 30, meal_type: 'snack', calories_per_100g: 650, protein_per_100g: 20, carbs_per_100g: 10, fat_per_100g: 55 },
        { id: 'e3', consumed_weight_g: 150, meal_type: 'breakfast', calories_per_100g: 63, protein_per_100g: 11, carbs_per_100g: 4, fat_per_100g: 0.2 },
      ],
    );
  });

  it('setzt user_edited = 0 für bestehende Produkte und legt die Indizes an', () => {
    const db = createV1Database();
    migrate(db);

    const flags = db.prepare('SELECT user_edited, updated_at FROM food_item').all();
    assert.ok(flags.every((f) => f.user_edited === 0 && f.updated_at === null));

    const indexes = db
      .prepare("SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%' ORDER BY name")
      .all()
      .map((row) => row.name);
    assert.deepEqual(indexes, ['idx_food_item_name', 'idx_log_entry_barcode_timestamp', 'idx_log_entry_date']);
  });

  it('rollt bei einem Fehler vollständig zurück', () => {
    const db = createV1Database();
    // Simuliert einen Abbruch mitten in der Migration: Index-Name existiert schon.
    db.exec('CREATE INDEX idx_food_item_name ON food_item (brand);');

    db.exec('BEGIN EXCLUSIVE;');
    assert.throws(() => db.exec(MIGRATION_V2_SQL));
    db.exec('ROLLBACK;');

    assert.equal((db.prepare('PRAGMA user_version').get() as { user_version: number }).user_version, 1);
    const columns = db.prepare('PRAGMA table_info(log_entry)').all().map((c) => c.name);
    assert.ok(!columns.includes('calories_per_100g'));
    assert.equal((db.prepare('SELECT COUNT(*) AS n FROM log_entry').get() as { n: number }).n, 3);
  });
});

describe('Migration v2 → v3', () => {
  it('behält das Profil und markiert das Ziel als berechnet', () => {
    const db = createV1Database();
    migrate(db);
    db.exec('BEGIN EXCLUSIVE;');
    db.exec(MIGRATION_V3_SQL);
    db.exec('COMMIT;');

    assert.equal((db.prepare('PRAGMA user_version').get() as { user_version: number }).user_version, LATEST_DATABASE_VERSION);
    const row = db.prepare('SELECT daily_calorie_goal, calorie_goal_is_custom FROM user_profile').get();
    assert.deepEqual({ ...row }, { daily_calorie_goal: 1990, calorie_goal_is_custom: 0 });
  });
});

describe('UPSERT_FOOD_ITEM_SQL', () => {
  it('überschreibt keine vom Nutzer korrigierten Produkte', () => {
    const db = createV1Database();
    migrate(db);
    db.exec("UPDATE food_item SET calories_per_100g = 70, user_edited = 1 WHERE barcode = '4006381333931'");

    db.prepare(UPSERT_FOOD_ITEM_SQL).run('4006381333931', 'Skyr neu', 'Marke', 99, 1, 1, 1, 500, null, 'openfoodfacts');
    const row = db.prepare("SELECT name, calories_per_100g FROM food_item WHERE barcode = '4006381333931'").get();
    assert.deepEqual({ ...row }, { name: 'Skyr', calories_per_100g: 70 });
  });

  it('aktualisiert nicht korrigierte Produkte und legt neue an', () => {
    const db = createV1Database();
    migrate(db);

    db.prepare(UPSERT_FOOD_ITEM_SQL).run('4006381333931', 'Skyr neu', 'Marke', 65, 11, 4, 0.2, 500, null, 'openfoodfacts');
    db.prepare(UPSERT_FOOD_ITEM_SQL).run('custom:3f2a9c1e-7b4d-4e8a-9f10-2c6d5e7a8b90', 'Apfel', '', 52, 0.3, 14, 0.2, null, null, 'manual');

    assert.equal((db.prepare("SELECT name FROM food_item WHERE barcode = '4006381333931'").get() as { name: string }).name, 'Skyr neu');
    assert.equal((db.prepare('SELECT COUNT(*) AS n FROM food_item').get() as { n: number }).n, 3);
  });
});

describe('SCRUB_DELETED_DATA_SQL', () => {
  it('entfernt gelöschte Inhalte aus Datenbankdatei und WAL', () => {
    const dir = mkdtempSync(join(tmpdir(), 'hachibu-scrub-'));
    const file = join(dir, 'test.db');
    const marker = 'GEHEIMMARKER-7f3a9c';
    // Wie in der App: eine dauerhaft offene Verbindung im WAL-Modus …
    const main = new DatabaseSync(file);
    try {
      main.exec('PRAGMA journal_mode = WAL;');
      main.exec(SCHEMA_V1_SQL);
      migrate(main);
      main.prepare(UPSERT_FOOD_ITEM_SQL).run('4006381333931', marker, marker, 63, 11, 4, 0.2, 500, null, 'openfoodfacts');
      // Die Daten liegen schon länger in der Hauptdatei, nicht nur im WAL.
      main.exec('PRAGMA wal_checkpoint(TRUNCATE);');
      assert.ok(readFileSync(file).includes(marker));

      // … und eine zweite, kurzlebige für die Lösch-Transaktion (withExclusiveTransactionAsync).
      const txn = new DatabaseSync(file);
      txn.exec('BEGIN EXCLUSIVE; DELETE FROM log_entry; DELETE FROM food_item; DELETE FROM user_profile; COMMIT;');
      txn.close();

      main.exec(SCRUB_DELETED_DATA_SQL);

      assert.ok(!readFileSync(file).includes(marker), 'Hauptdatei enthält noch gelöschte Inhalte');
      assert.ok(!readFileSync(`${file}-wal`).includes(marker), 'WAL enthält noch gelöschte Inhalte');
    } finally {
      main.close();
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
