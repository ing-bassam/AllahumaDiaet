import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section("Datenschutz") {
                Text("Alle Angaben bleiben ausschließlich auf deinem Gerät, es gibt kein Konto und keine Werbung. Die Kamera wird nur zum Scannen von Barcodes genutzt. Beim Scannen und bei der Online-Suche werden der Barcode bzw. dein Suchbegriff und deine IP-Adresse an Open Food Facts übermittelt, um das Produkt zu finden; Produktbilder werden ebenfalls von dort geladen.")
                    .font(.subheadline)
                Link("Datenschutzerklärung öffnen", destination: LegalURLs.privacyPolicy)
            }

            Section("Impressum") {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Imprint.name)
                    Text(Imprint.street)
                    Text(Imprint.postalCodeAndCity)
                    Text(Imprint.country)
                }
                .font(.subheadline)
                Link("E-Mail: \(Imprint.email)", destination: URL(string: "mailto:\(Imprint.email)")!)
                if let phone = Imprint.phone {
                    Text("Telefon: \(phone)").font(.subheadline)
                }
                Link("Impressum im Browser öffnen", destination: LegalURLs.imprint)
            }

            Section("Support") {
                Text("Fragen, Fehler oder Wünsche? Schreib an \(Imprint.email).")
                    .font(.subheadline)
                Link("Support-Seite öffnen", destination: LegalURLs.support)
            }

            Section("Datenquellen") {
                Text("Enthält Produktdaten von Open Food Facts, die gemäß der Open Database License (ODbL) zur Verfügung gestellt werden. Produktbilder: Open Food Facts, lizenziert unter CC BY-SA.")
                    .font(.subheadline)
                Link("Open Food Facts", destination: LegalURLs.openFoodFacts)
                Link("Open Database License (ODbL)", destination: LegalURLs.odbl)
                Link("CC BY-SA", destination: LegalURLs.ccBySa)
            }

            Section("Berechnung & Quellen") {
                Text("So entsteht dein Tagesziel:").font(.subheadline.weight(.semibold))
                ForEach(Array(CalculationInfo.steps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)").font(.subheadline)
                }
                ForEach(CalculationInfo.sources) { source in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.title).font(.subheadline.weight(.semibold))
                        Text(source.detail).font(.caption).foregroundStyle(.secondary)
                        Link("Quelle öffnen", destination: source.url).font(.caption.weight(.semibold))
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Open-Source-Lizenzen") {
                ForEach(OpenSourceLicenses.all) { item in
                    Link(destination: item.url) {
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text("\(item.version) · \(item.license)").foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Hinweis") {
                Text(CalculationInfo.medicalDisclaimer).font(.subheadline)
            }

            Section {
                Text("\(AppInfo.name) · Version \(AppInfo.version) (\(AppInfo.build))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Info & Rechtliches")
        .navigationBarTitleDisplayMode(.inline)
    }
}
