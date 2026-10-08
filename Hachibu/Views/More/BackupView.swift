import SwiftUI
import UniformTypeIdentifiers

/// Sicherung als Datei exportieren und wieder einlesen. Der Nutzer wählt im Teilen-Menü selbst,
/// wohin die Datei geht – die App legt nichts von sich aus in einer Cloud ab.
struct BackupView: View {
    @EnvironmentObject private var model: AppModel

    @State private var backupURL: URL?
    @State private var csvURL: URL?
    @State private var showImporter = false
    @State private var pendingImport: BackupDocument?
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        List {
            Section {
                Text("Alle Daten liegen nur auf diesem iPhone. Eine Sicherung schützt vor Verlust, wenn du die App löschst oder das Gerät wechselst.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let backupURL {
                    ShareLink(item: backupURL) {
                        Label("Sicherung teilen oder speichern", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        createBackup()
                    } label: {
                        Label("Sicherungsdatei erstellen", systemImage: "doc.badge.plus")
                    }
                }
                if let csvURL {
                    ShareLink(item: csvURL) {
                        Label("Tagebuch als CSV teilen", systemImage: "tablecells")
                    }
                } else {
                    Button {
                        createCSV()
                    } label: {
                        Label("Tagebuch als CSV (für Excel)", systemImage: "tablecells")
                    }
                }
            } header: {
                Text("Sichern")
            } footer: {
                Text("Die Sicherung enthält Profil, Lebensmittel, Tagebuch und Gewichtsverlauf, auch Alter und Gewicht. Teile sie nur mit Orten, denen du vertraust.")
            }

            Section {
                Button {
                    showImporter = true
                } label: {
                    Label("Sicherung einlesen", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Wiederherstellen")
            } footer: {
                Text("Ersetzt alle Daten auf diesem Gerät durch den Stand der Sicherung. Vorher wirst du gefragt.")
            }
        }
        .navigationTitle("Datensicherung")
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .plainText, .data]) { result in
            switch result {
            case .success(let url): readBackup(at: url)
            case .failure: errorMessage = "Die Datei konnte nicht geöffnet werden."
            }
        }
        .confirmationDialog(
            "Alle Daten ersetzen?",
            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
            titleVisibility: .visible,
            presenting: pendingImport
        ) { document in
            Button("Wiederherstellen", role: .destructive) { importBackup(document) }
            Button("Abbrechen", role: .cancel) {}
        } message: { document in
            Text("Sicherung vom \(formatted(document.exportedAt)) mit \(document.entries.count) Einträgen, \(document.foods.count) Lebensmitteln und \(document.weights.count) Gewichtseinträgen. Alle aktuellen Daten auf diesem Gerät werden ersetzt.")
        }
        .alert("Fehler", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Fertig", isPresented: Binding(get: { successMessage != nil }, set: { if !$0 { successMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage ?? "")
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func fileURL(name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    private func createBackup() {
        do {
            let document = try model.repo.exportBackup(appVersion: AppInfo.version)
            let url = fileURL(name: "Hachibu-Sicherung-\(Formatting.dateKey(Date())).json")
            try document.encoded().write(to: url, options: .atomic)
            backupURL = url
        } catch {
            errorMessage = "Die Sicherung konnte nicht erstellt werden."
        }
    }

    private func createCSV() {
        do {
            let csv = try model.repo.exportCSV()
            let url = fileURL(name: "Hachibu-Tagebuch-\(Formatting.dateKey(Date())).csv")
            // BOM, damit Excel die Umlaute richtig liest.
            var data = Data([0xEF, 0xBB, 0xBF])
            data.append(csv.data(using: .utf8) ?? Data())
            try data.write(to: url, options: .atomic)
            csvURL = url
        } catch {
            errorMessage = "Die CSV-Datei konnte nicht erstellt werden."
        }
    }

    private func readBackup(at url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let document = try BackupDocument.decode(data)
            if let problem = document.validate() {
                errorMessage = problem
                return
            }
            pendingImport = document
        } catch {
            errorMessage = "Das ist keine lesbare Hachibu-Sicherung."
        }
    }

    private func importBackup(_ document: BackupDocument) {
        do {
            try model.repo.importBackup(document)
            model.reloadProfile()
            model.dataChanged()
            successMessage = "Die Sicherung wurde wiederhergestellt."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
