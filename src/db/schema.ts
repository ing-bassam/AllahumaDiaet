import type { SQLiteDatabase } from 'expo-sqlite';

import { LATEST_DATABASE_VERSION, MIGRATION_V2_SQL, SCHEMA_V1_SQL } from './migrations';

export const DATABASE_NAME = 'allahuma-diaet.db';

export async function migrateDbIfNeeded(db: SQLiteDatabase): Promise<void> {
  // Muss pro Verbindung gesetzt werden, nicht nur bei der Migration.
  await db.execAsync('PRAGMA foreign_keys = ON;');

  const result = await db.getFirstAsync<{ user_version: number }>('PRAGMA user_version');
  let currentVersion = result?.user_version ?? 0;
  if (currentVersion >= LATEST_DATABASE_VERSION) return;

  if (currentVersion === 0) {
    // Neue, leere Datenbank. journal_mode lässt sich nicht innerhalb einer Transaktion ändern.
    await db.execAsync('PRAGMA journal_mode = WAL;');
    // Alles oder nichts, wie unten: Sonst bliebe nach einem Abbruch user_version auf 0, während die
    // ersten Tabellen schon existieren, und jeder weitere Start scheiterte an „table already exists“.
    await db.withExclusiveTransactionAsync(async (txn) => {
      await txn.execAsync(SCHEMA_V1_SQL);
    });
    currentVersion = 1;
  }

  if (currentVersion === 1) {
    // Alles oder nichts: Bricht die App mittendrin ab, bleibt die Datenbank auf Version 1 und die
    // Migration läuft beim nächsten Start erneut. user_version wird in derselben Transaktion gesetzt.
    await db.withExclusiveTransactionAsync(async (txn) => {
      await txn.execAsync(MIGRATION_V2_SQL);
    });
    currentVersion = 2;
  }
}
