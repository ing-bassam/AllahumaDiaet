import SwiftUI

/// Nährwerte eines unbekannten Produkts oder eines eigenen Lebensmittels einmalig erfassen.
struct ManualEntryForm: View {
    let key: String
    let reason: ProductView.ManualReason
    let partial: PartialProduct?
    var prefillName: String?
    var onRetry: () -> Void
    var onSaved: (FoodItem) -> Void

    @EnvironmentObject private var model: AppModel
    @StateObject private var editor: NutritionEditor

    @State private var name: String
    @State private var brand: String
    @State private var packageSize: String
    @State private var saving = false
    @State private var errorMessage: String?

    init(key: String, reason: ProductView.ManualReason, partial: PartialProduct?, prefillName: String?, onRetry: @escaping () -> Void, onSaved: @escaping (FoodItem) -> Void) {
        self.key = key
        self.reason = reason
        self.partial = partial
        self.prefillName = prefillName
        self.onRetry = onRetry
        self.onSaved = onSaved
        let size = partial?.servingSizeG
        _editor = StateObject(wrappedValue: NutritionEditor(initialPer100g: nil, portionGrams: size, portionLabel: "pro Packung", portionIsBasis: true))
        _name = State(initialValue: partial?.name ?? prefillName ?? "")
        _brand = State(initialValue: partial?.brand ?? "")
        _packageSize = State(initialValue: size.map { Formatting.inputText($0) } ?? "")
    }

    private var packageValue: Double? { Formatting.parseDecimal(packageSize) }
    private var packageError: String? {
        guard !packageSize.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let packageValue, packageValue > 0 else { return "Ungültige Menge." }
        return nil
    }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && editor.isValid && packageError == nil && !saving }

    private var reasonText: String {
        switch reason {
        case .notFound: return "Dieses Produkt ist bei Open Food Facts noch nicht bekannt. Trag die Nährwerte von der Packung einmal ein – beim nächsten Scan ist es sofort da."
        case .incomplete: return "Bei Open Food Facts fehlen die Nährwerte dieses Produkts. Trag sie von der Packung einmal ein."
        case .error: return "Open Food Facts ist gerade nicht erreichbar. Du kannst die Nährwerte von der Packung eintragen oder es später erneut versuchen."
        case .custom: return "Lebensmittel ohne Barcode, z. B. ein selbst gekochtes Gericht. Die Werte bleiben auf deinem Gerät."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    FoodThumbnail(imageUrl: partial?.imageUrl, size: 56)
                    Text(reasonText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if reason == .error {
                    Button("Erneut versuchen", action: onRetry)
                        .buttonStyle(.bordered)
                }
                if !FoodKey.isCustom(key) {
                    Text("Barcode \(key)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                LabeledInput(label: "Name", text: $name, keyboard: .default, placeholder: "z. B. Haferflocken")
                LabeledInput(label: "Marke (optional)", text: $brand, keyboard: .default)
                LabeledInput(label: "Packungsgröße (optional)", unit: "g", text: $packageSize, error: packageError)
                    .onChange(of: packageSize) { _, _ in
                        editor.updatePortionGrams((packageValue ?? 0) > 0 ? packageValue : nil)
                    }

                SectionCard(title: "Nährwerte") {
                    Text("Viele Etiketten nennen Werte pro Packung oder Portion – die Packungsgröße dient dann als Umrechnungsbasis.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    NutritionFields(editor: editor)
                }

                Button {
                    save()
                } label: {
                    Text(reason == .custom ? "Lebensmittel speichern" : "Produkt speichern")
                        .font(.headline).frame(maxWidth: .infinity).frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(reason == .custom ? "Eigenes Lebensmittel" : "Produkt anlegen")
        .keyboardDoneButton()
        .alert("Fehler", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save() {
        guard canSave, let per100g = editor.per100g else { return }
        saving = true
        defer { saving = false }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespaces)
        let size: Double? = (packageValue ?? 0) > 0 ? packageValue : nil
        do {
            try model.repo.saveFood(key: key, name: trimmedName, brand: trimmedBrand, per100g: per100g, servingSizeG: size, imageUrl: partial?.imageUrl, source: .manual)
            guard let saved = try model.repo.foodItem(key: key) else {
                errorMessage = "Speichern fehlgeschlagen."
                return
            }
            Haptics.success()
            onSaved(saved)
        } catch {
            errorMessage = "Speichern fehlgeschlagen. Bitte versuche es erneut."
        }
    }
}
