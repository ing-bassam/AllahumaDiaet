import SwiftUI

/// Einen Tagebucheintrag bearbeiten: Menge, Mahlzeit, Nährwerte, bei Schnelleinträgen auch die Notiz.
struct EntryEditView: View {
    let entry: LogEntry

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var editor: NutritionEditor

    @State private var amount: String
    @State private var mealType: MealType
    @State private var note: String
    @State private var editingNutrients: Bool
    @State private var applyToFood = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?
    @FocusState private var amountFocused: Bool

    init(entry: LogEntry) {
        self.entry = entry
        // Standardmäßig „pro Portion“: So steht es meist auf dem Teller bzw. der Verpackung.
        _editor = StateObject(wrappedValue: NutritionEditor(
            initialPer100g: entry.per100g,
            portionGrams: Portions.valid(entry.grams),
            initialMode: entry.isQuickEntry ? .per100g : .portion
        ))
        _amount = State(initialValue: Formatting.inputText(entry.grams))
        _mealType = State(initialValue: entry.mealType)
        _note = State(initialValue: entry.note ?? "")
        _editingNutrients = State(initialValue: entry.isQuickEntry)
    }

    private var validGrams: Double? { entry.isQuickEntry ? 100 : Portions.valid(Formatting.parseDecimal(amount)) }
    private var nutrientsChanged: Bool { editingNutrients && editor.touched }
    private var per100g: Nutrients { nutrientsChanged ? (editor.per100g ?? entry.per100g) : entry.per100g }
    private var portion: Nutrients { Nutrition.nutrientsForPortion(per100g, grams: validGrams ?? 0) }
    private var canSave: Bool { validGrams != nil && (!nutrientsChanged || editor.isValid) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        FoodThumbnail(imageUrl: entry.imageUrl, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.displayName).font(.headline)
                            if !entry.brand.isEmpty { Text(entry.brand).font(.subheadline).foregroundStyle(.secondary) }
                            Text("Eingetragen um \(Formatting.time(entry.timestamp)) Uhr").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    if entry.isQuickEntry {
                        LabeledInput(label: "Bezeichnung (optional)", text: $note, keyboard: .default, placeholder: "z. B. Mittagessen in der Kantine")
                    } else {
                        amountSection
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mahlzeit").font(.subheadline.weight(.semibold))
                        ChipRow(items: MealType.allCases) { meal in
                            Chip(label: meal.label, selected: mealType == meal) { mealType = meal }
                        }
                    }

                    nutrientsSection

                    Button {
                        save()
                    } label: {
                        Text("Speichern").font(.headline).frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)

                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Text("Eintrag löschen").font(.headline).frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Eintrag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { amountFocused = false }
                }
            }
            .onChange(of: validGrams) { _, newValue in
                if !entry.isQuickEntry { editor.updatePortionGrams(newValue) }
            }
            .confirmationDialog("Eintrag löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { delete() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("\(entry.displayName) (\(NumberFormat.decimal(entry.grams)) g)")
            }
            .alert("Fehler", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var amountSection: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("0", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    .focused($amountFocused)
                    .accessibilityLabel("Menge in Gramm")
                Text("g").font(.title2.weight(.semibold)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            Text("\(NumberFormat.int(portion.calories)) kcal · Protein \(NumberFormat.decimal(portion.protein)) g · KH \(NumberFormat.decimal(portion.carbs)) g · Fett \(NumberFormat.decimal(portion.fat)) g")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            ChipRow(items: Portions.presets(servingSizeG: entry.servingSizeG)) { preset in
                Chip(label: preset.label, selected: validGrams == preset.grams) {
                    amount = Formatting.inputText(preset.grams)
                }
            }
        }
    }

    private var nutrientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !entry.isQuickEntry {
                Button {
                    withAnimation { editingNutrients.toggle() }
                } label: {
                    HStack {
                        Label(editingNutrients ? "Nährwerte ausblenden" : "Nährwerte ändern", systemImage: "pencil").font(.headline)
                        Spacer()
                        Image(systemName: editingNutrients ? "chevron.up" : "chevron.down").foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            if editingNutrients {
                VStack(alignment: .leading, spacing: 12) {
                    Text(entry.isQuickEntry ? "Werte dieses Schnelleintrags" : "Nährwerte dieses Eintrags").font(.headline)
                    NutritionFields(editor: editor)
                    if !entry.isQuickEntry {
                        Toggle("Auch für künftige Einträge dieses Lebensmittels übernehmen", isOn: $applyToFood)
                            .font(.subheadline)
                        if applyToFood {
                            Text("Das Lebensmittel wird dauerhaft korrigiert. Andere, bereits eingetragene Tage bleiben unverändert.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func save() {
        guard let validGrams else { return }
        var updated = entry
        updated.grams = validGrams
        updated.mealType = mealType
        updated.per100g = per100g
        updated.note = entry.isQuickEntry ? (note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note.trimmingCharacters(in: .whitespaces)) : entry.note
        do {
            try model.repo.updateEntry(updated)
            if applyToFood && nutrientsChanged && !entry.isQuickEntry {
                try model.repo.updateFoodNutrients(key: entry.barcode, per100g: per100g, name: entry.name, brand: entry.brand)
            }
            Haptics.success()
            model.dataChanged()
            dismiss()
        } catch {
            errorMessage = "Speichern fehlgeschlagen. Bitte versuche es erneut."
        }
    }

    private func delete() {
        do {
            try model.repo.deleteEntry(id: entry.id)
            model.dataChanged()
            dismiss()
        } catch {
            errorMessage = "Löschen fehlgeschlagen. Bitte versuche es erneut."
        }
    }
}
