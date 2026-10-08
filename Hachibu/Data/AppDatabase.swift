import Foundation
import GRDB

/// Öffnet die Datenbank und bringt sie auf die aktuelle Schema-Version.
enum AppDatabase {
    static let fileName = "allahuma-diaet.db"

    /// Gleicher Ort wie in der bisherigen App (Documents/SQLite), damit die Datei beim Update erhalten bleibt.
    static func defaultURL() throws -> URL {
        let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = documents.appendingPathComponent("SQLite", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    private static func configuration() -> Configuration {
        var config = Configuration()
        config.foreignKeysEnabled = true
        return config
    }

    static func open(at url: URL) throws -> DatabaseQueue {
        let queue = try DatabaseQueue(path: url.path, configuration: configuration())
        try migrate(queue)
        return queue
    }

    static func openDefault() throws -> DatabaseQueue {
        try open(at: defaultURL())
    }

    /// Für Tests: eine leere Datenbank im Arbeitsspeicher, wahlweise nur bis zu einer älteren Version migriert.
    static func openInMemory(upTo version: Int = Migrations.latestVersion) throws -> DatabaseQueue {
        let queue = try DatabaseQueue(configuration: configuration())
        try migrate(queue, upTo: version)
        return queue
    }

    static func userVersion(_ queue: DatabaseQueue) throws -> Int {
        try queue.read { db in
            try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
        }
    }

    /// Jede Version läuft in einer eigenen Transaktion: Bricht die App mittendrin ab, bleibt die alte
    /// Version vollständig erhalten und die Migration läuft beim nächsten Start erneut.
    static func migrate(_ queue: DatabaseQueue, upTo target: Int = Migrations.latestVersion) throws {
        var version = try userVersion(queue)
        if version >= target { return }

        if version == 0 && target >= 1 {
            // journal_mode lässt sich nicht innerhalb einer Transaktion ändern.
            try queue.writeWithoutTransaction { db in
                _ = try Row.fetchOne(db, sql: "PRAGMA journal_mode = WAL")
            }
            try queue.write { db in
                try db.execute(sql: Migrations.schemaV1)
            }
            version = 1
        }
        if version == 1 && target >= 2 {
            try queue.write { db in
                try db.execute(sql: Migrations.migrationV2)
            }
            version = 2
        }
        if version == 2 && target >= 3 {
            try queue.write { db in
                try db.execute(sql: Migrations.migrationV3)
            }
            version = 3
        }
        if version == 3 && target >= 4 {
            try queue.write { db in
                try db.execute(sql: Migrations.migrationV4)
            }
            version = 4
        }
    }

    /// Spaltennamen einer Tabelle, für Tests der Migrationen.
    static func columns(_ queue: DatabaseQueue, table: String) throws -> [String] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(\(table))").map { row in row["name"] as String }
        }
    }

    /// Beliebiges SQL ohne Rückgabe, für Tests (z. B. Daten im alten Schema anlegen).
    static func execute(_ queue: DatabaseQueue, sql: String) throws {
        try queue.write { db in
            try db.execute(sql: sql)
        }
    }

    static func count(_ queue: DatabaseQueue, table: String) throws -> Int {
        try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? 0
        }
    }
}
