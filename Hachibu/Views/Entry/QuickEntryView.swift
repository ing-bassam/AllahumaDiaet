import SwiftUI

/// Schnelleintrag ohne Lebensmittel – für Restaurant, Kantine oder wenn nur die Kalorien bekannt sind.
struct QuickEntryView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var note = ""
    @State private var mealType = MealType.suggested(for: Date())
    @State private var errorMessage: String?
    @FocusState private var caloriesFocused: Bool

    private static let maxCalories = 5000.0

    private var caloriesValue: Double? { Formatting.parseDecimal(calories) }
    private var caloriesError: String? {
        guard !calories.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let caloriesValue, caloriesValue >= 0, caloriesValue <= QuickEntryView.maxCalories else {
            return "Bitte einen Wert zwischen 0 und \(NumberFormat.int(QuickEntryView.maxCalories)) kcal eingeben."
        }
        return nil
    }

    private func optionalGrams(_ text: String) -> Double? {
        text.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : Formatting.parseDecimal(text)
    }

    private func gramsError(_ text: String) -> String? {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let value = Formatting.parseDecimal(text), value >= 0, value <= 1000 else { return "Bitte einen Wert ab 0 g eingeben." }
        return nil
    }

    private var canSave: Bool {
        caloriesValue != nil && caloriesError == nil
            && optionalGrams(protein) != nil && optionalGrams(carbs) != nil && optionalGrams(fat) != nil
            && gramsError(protein) == nil && gramsError(carbs) == nil && gramsError(fat) == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Für Mahlzeiten ohne Barcode, z. B. im Restaurant. Nur die Kalorien sind Pflicht.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    LabeledInput(label: "Kalorien", unit: "kcal", text: $calories, error: caloriesError, placeholder: "z. B. 650")
                        .focused($caloriesFocused)
                    HStack(spacing: 10) {
                        LabeledInput(label: "Protein", unit: "g", text: $protein, error: gramsError(protein))
                        LabeledInput(label: "Kohlenh.", unit: "g", text: $carbs, error: gramsError(carbs))
                        LabeledInput(label: "Fett", unit: "g", text: $fat, error: gramsError(fat))
                    }
                    LabeledInput(label: "Bezeichnung (optional)", text: $note, keyboard: .default, placeholder: "z. B. Mittagessen in der Kantine")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mahlzeit").font(.subheadline.weight(.semibold))
                        ChipRow(items: MealType.allCases) { meal in
                            Chip(label: meal.label, selected: mealType == meal) { mealType = meal }
                        }
                    }
                    Button {
                        save()
                    } label: {
                        Text("Eintragen").font(.headline).frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Schnelleintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { caloriesFocused = false }
                }
            }
            .onAppear { caloriesFocused = true }
            .alert("Fehler", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        guard canSave, let kcal = caloriesValue else { return }
        let nutrients = Nutrients(calories: kcal, protein: optionalGrams(protein) ?? 0, carbs: optionalGrams(carbs) ?? 0, fat: optionalGrams(fat) ?? 0)
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)
        do {
            try model.repo.addQuickEntry(
                nutrients: nutrients,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                mealType: mealType,
                at: DateMath.combine(day: model.selectedDay, time: Date())
            )
            Haptics.success()
            model.dataChanged()
            dismiss()
        } catch {
            errorMessage = "Eintragen fehlgeschlagen. Bitte versuche es erneut."
        }
    }
}
