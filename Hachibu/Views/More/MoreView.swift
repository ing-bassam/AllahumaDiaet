import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var model: AppModel

    @State private var confirmDeleteAll = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ProfileFormView(isOnboarding: false)
                    } label: {
                        Label("Profil & Tagesziel", systemImage: "person.crop.circle")
                    }
                    NavigationLink {
                        BackupView()
                    } label: {
                        Label("Daten sichern & wiederherstellen", systemImage: "externaldrive")
                    }
                }

                Section {
                    Link(destination: AppInfo.reviewURL) {
                        Label("Hachibu bewerten", systemImage: "star")
                    }
                    Link(destination: LegalURLs.openFoodFactsContribute) {
                        Label("Fehlendes Produkt bei Open Food Facts ergänzen", systemImage: "square.and.pencil")
                    }
                    Link(destination: URL(string: "mailto:\(AppInfo.contactEmail)")!) {
                        Label("Feedback senden", systemImage: "envelope")
                    }
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("Info & Rechtliches", systemImage: "info.circle")
                    }
                } footer: {
                    Text("Hachibu hat kein Konto, keine Werbung und kein Tracking. Alle Einträge bleiben auf deinem iPhone.")
                }

                Section {
                    Button(role: .destructive) {
                        confirmDeleteAll = true
                    } label: {
                        Label("Alle Daten löschen", systemImage: "trash")
                    }
                } footer: {
                    Text("Löscht dein Profil, alle Einträge, gespeicherte Produkte und den Gewichtsverlauf von diesem Gerät. · \(AppInfo.name) \(AppInfo.version) (\(AppInfo.build))")
                }
            }
            .navigationTitle("Mehr")
            .confirmationDialog("Alle Daten löschen?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { deleteAll() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Profil, Einträge, gespeicherte Produkte und Gewichtsverlauf werden unwiderruflich gelöscht.")
            }
            .alert("Fehler", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func deleteAll() {
        do {
            try model.repo.deleteAllData()
            model.afterDeleteAll()
        } catch {
            errorMessage = "Löschen fehlgeschlagen. Bitte versuche es erneut."
        }
    }
}
