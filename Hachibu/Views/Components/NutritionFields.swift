import SwiftUI

/// Zustand der Nährwertfelder. Kanonisch ist immer der Wert pro 100 g; er bleibt unverändert, solange
/// der Nutzer nichts eintippt, damit gerundete Anzeigewerte die gespeicherten Werte nicht verfälschen.
@MainActor
final class NutritionEditor: ObservableObject {
    @Published private(set) var mode: NutritionMode
    @Published private(set) var draft: NutrientDraft
    @Published private(set) var per100g: Nutrients?
    @Published private(set) var touched = false
    @Published private(set) var portionGrams: Double?

    let portionLabel: String
    /// Die Menge ist die Bezugsgröße der eingetippten Werte (Etikett „pro Packung“), nicht die gegessene
    /// Menge. Ändert sie sich, bleiben die Felder stehen und die Werte pro 100 g werden neu berechnet.
    let portionIsBasis: Bool

    /// Stand, aus dem die Felder zuletzt gefüllt wurden, und die seitdem bearbeiteten Felder.
    private var base: Nutrients?
    private var edited = Set<NutrientField>()

    init(initialPer100g: Nutrients?, portionGrams: Double?, initialMode: NutritionMode = .per100g, portionLabel: String = "pro Portion", portionIsBasis: Bool = false) {
        let startMode: NutritionMode = (initialMode == .portion && NutritionDraft.isUsablePortion(portionGrams)) ? .portion : .per100g
        self.mode = startMode
        self.portionGrams = portionGrams
        self.portionLabel = portionLabel
        self.portionIsBasis = portionIsBasis
        self.per100g = initialPer100g
        self.base = initialPer100g
        self.draft = initialPer100g.map { NutritionDraft.draft(from: $0, mode: startMode, grams: portionGrams) } ?? .empty
    }

    var validation: NutrientValidation? { per100g.map { Nutrition.validate($0) } }
    var warning: String? { per100g.flatMap { Nutrition.plausibilityWarning($0) } }
    var isValid: Bool { validation?.valid ?? false }
    var canUsePortion: Bool { NutritionDraft.isUsablePortion(portionGrams) }

    func setField(_ field: NutrientField, _ text: String) {
        draft[field] = text
        touched = true
        edited.insert(field)
        if let parsed = NutritionDraft.per100g(from: draft, mode: mode, grams: portionGrams) {
            per100g = NutritionDraft.mergeEditedFields(base: base, parsed: parsed, edited: edited)
        } else {
            per100g = nil
        }
    }

    /// Füllt die Felder neu aus den Werten pro 100 g. Danach stimmen Text und Wert wieder überein.
    private func showValues(_ values: Nutrients, mode newMode: NutritionMode, grams: Double?) {
        base = values
        edited.removeAll()
        draft = NutritionDraft.draft(from: values, mode: newMode, grams: grams)
    }

    func setMode(_ newMode: NutritionMode) {
        guard newMode != mode else { return }
        if newMode == .portion && !canUsePortion { return }
        mode = newMode
        if let per100g { showValues(per100g, mode: newMode, grams: portionGrams) }
    }

    /// Ändert sich die Menge, rechnen die Portionsfelder proportional mit – außer die Menge ist die Basis.
    func updatePortionGrams(_ grams: Double?) {
        guard grams != portionGrams else { return }
        portionGrams = grams
        guard mode == .portion else { return }
        if portionIsBasis {
            base = nil
            edited.removeAll()
            per100g = NutritionDraft.per100g(from: draft, mode: .portion, grams: grams)
            return
        }
        if !NutritionDraft.isUsablePortion(grams) {
            mode = .per100g
            if let per100g { showValues(per100g, mode: .per100g, grams: nil) }
            return
        }
        if let per100g { showValues(per100g, mode: .portion, grams: grams) }
    }
}

struct NutritionFields: View {
    @ObservedObject var editor: NutritionEditor
    var autoFocus = false

    @FocusState private var focused: NutrientField?

    private func binding(_ field: NutrientField) -> Binding<String> {
        Binding(get: { editor.draft[field] }, set: { editor.setField(field, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if editor.canUsePortion {
                Picker("Bezug", selection: Binding(get: { editor.mode }, set: { editor.setMode($0) })) {
                    Text("pro 100 g").tag(NutritionMode.per100g)
                    Text("\(editor.portionLabel) (\(NumberFormat.decimal(editor.portionGrams ?? 0)) g)").tag(NutritionMode.portion)
                }
                .pickerStyle(.segmented)
            }
            LabeledInput(label: "Kalorien", unit: "kcal", text: binding(.calories), error: editor.validation?.calories)
                .focused($focused, equals: .calories)
            LabeledInput(label: "Protein", unit: "g", text: binding(.protein), error: editor.validation?.protein)
                .focused($focused, equals: .protein)
            LabeledInput(label: "Kohlenhydrate", unit: "g", text: binding(.carbs), error: editor.validation?.carbs)
                .focused($focused, equals: .carbs)
            LabeledInput(label: "Fett", unit: "g", text: binding(.fat), error: editor.validation?.fat)
                .focused($focused, equals: .fat)
            if let macroTotal = editor.validation?.macroTotal {
                Text(macroTotal)
                    .font(.caption)
                    .foregroundStyle(Theme.danger)
            }
            if let warning = editor.warning {
                Label(warning, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if autoFocus { focused = .calories }
        }
    }
}
