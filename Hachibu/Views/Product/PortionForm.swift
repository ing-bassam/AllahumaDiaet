import SwiftUI

/// Menge, Mahlzeit und optional korrigierte Nährwerte für ein Lebensmittel eintragen.
struct PortionForm: View {
    let food: FoodItem
    let persisted: Bool
    var fromScanner: Bool
    var onDone: (ProductOutcome) -> Void

    @EnvironmentObject private var model: AppModel
    @StateObject private var editor: NutritionEditor

    @State private var amount = ""
    @State private var mealType: MealType
    @State private var name: String
    @State private var brand: String
    @State private var correcting = false
    @State private var favorite: Bool
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var lastAmount: Double?
    @State private var restoring = false
    @State private var confirmRestore = false
    @FocusState private var amountFocused: Bool

    init(food: FoodItem, persisted: Bool, fromScanner: Bool, onDone: @escaping (ProductOutcome) -> Void) {
        self.food = food
        self.persisted = persisted
        self.fromScanner = fromScanner
        self.onDone = onDone
        _editor = StateObject(wrappedValue: NutritionEditor(initialPer100g: food.per100g, portionGrams: nil))
        _mealType = State(initialValue: MealType.suggested(for: Date()))
        _name = State(initialValue: food.name)
        _brand = State(initialValue: food.brand)
        _favorite = State(initialValue: food.favorite)
    }

    private var grams: Double? { Formatting.parseDecimal(amount) }
    private var validGrams: Double? { Portions.valid(grams) }
    private var per100g: Nutrients { (correcting && editor.touched ? editor.per100g : nil) ?? food.per100g }
    private var portion: Nutrients { Nutrition.nutrientsForPortion(per100g, grams: validGrams ?? 0) }
    private var canSave: Bool { validGrams != nil && (!correcting || !editor.touched || editor.isValid) && !saving }
    private var presets: [PortionPreset] { Portions.presets(servingSizeG: food.servingSizeG, lastAmount: lastAmount) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("0", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.trailing)
                            .fixedSize()
                            .focused($amountFocused)
                            .accessibilityLabel("Menge in Gramm")
                        Text("g")
                            .font(.title.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Text("\(NumberFormat.int(portion.calories)) kcal")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.primary)
                        .monospacedDigit()
                    Text("Protein \(NumberFormat.decimal(portion.protein)) g · Kohlenhydrate \(NumberFormat.decimal(portion.carbs)) g · Fett \(NumberFormat.decimal(portion.fat)) g")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if grams != nil && validGrams == nil {
                        Text("Bitte eine Menge zwischen 0 und \(NumberFormat.int(Portions.maxGrams)) g eingeben.")
                            .font(.caption)
                            .foregroundStyle(Theme.danger)
                    }
                }

                ChipRow(items: presets) { preset in
                    Chip(label: preset.label, selected: validGrams == preset.grams) {
                        amount = Formatting.inputText(preset.grams)
                        Haptics.tap()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Mahlzeit").font(.subheadline.weight(.semibold))
                    ChipRow(items: MealType.allCases) { meal in
                        Chip(label: meal.label, selected: mealType == meal) { mealType = meal }
                    }
                }

                correctionSection

                VStack(spacing: 10) {
                    Button {
                        save(continueScanning: false)
                    } label: {
                        Text("Speichern").font(.headline).frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                    if fromScanner {
                        Button {
                            save(continueScanning: true)
                        } label: {
                            Label("Speichern & weiter scannen", systemImage: "barcode.viewfinder").font(.headline).frame(maxWidth: .infinity).frame(height: 50)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canSave)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(food.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: favorite ? "star.fill" : "star")
                        .foregroundStyle(favorite ? Theme.carbs : Color.secondary)
                }
                .accessibilityLabel(favorite ? "Aus Favoriten entfernen" : "Zu Favoriten")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { amountFocused = false }
            }
        }
        .task {
            lastAmount = try? model.repo.lastAmount(key: food.barcode)
            if amount.isEmpty, let last = Portions.valid(lastAmount) {
                amount = Formatting.inputText(last)
            } else if amount.isEmpty {
                amountFocused = true
            }
        }
        .onChange(of: validGrams) { _, newValue in
            editor.updatePortionGrams(newValue)
        }
        .alert("Fehler", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog("Eigene Werte verwerfen?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Wiederherstellen", role: .destructive) { restoreFromOpenFoodFacts() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Nährwerte werden neu von Open Food Facts geladen.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            FoodThumbnail(imageUrl: food.imageUrl, size: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name).font(.headline)
                if !food.brand.isEmpty {
                    Text(food.brand).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(food.userEdited ? "Eigene Werte" : (food.source == .manual ? "Eigenes Lebensmittel" : "Open Food Facts"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var correctionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation { correcting.toggle() }
            } label: {
                HStack {
                    Label(correcting ? "Nährwerte ausblenden" : "Nährwerte korrigieren", systemImage: "pencil")
                        .font(.headline)
                    Spacer()
                    Image(systemName: correcting ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(correcting ? [.isSelected] : [])

            if correcting {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledInput(label: "Name", text: $name, keyboard: .default)
                    LabeledInput(label: "Marke", text: $brand, keyboard: .default)
                    NutritionFields(editor: editor)
                    Text("Die Korrektur gilt für dieses Lebensmittel dauerhaft. Bereits eingetragene Tage bleiben unverändert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if food.userEdited && !FoodKey.isCustom(food.barcode) {
                        Button("Werte von Open Food Facts wiederherstellen") { confirmRestore = true }
                            .font(.subheadline)
                            .disabled(restoring)
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func toggleFavorite() {
        favorite.toggle()
        Haptics.tap()
        do {
            if !persisted { try model.repo.saveProduct(food.asProductData) }
            try model.repo.setFavorite(key: food.barcode, favorite)
        } catch {
            favorite.toggle()
            errorMessage = "Favorit konnte nicht gespeichert werden."
        }
    }

    private func save(continueScanning: Bool) {
        guard let validGrams, !saving else { return }
        saving = true
        defer { saving = false }
        do {
            // Erst das Produkt, dann der Eintrag: log_entry verweist per Fremdschlüssel darauf.
            if !persisted {
                try model.repo.saveProduct(food.asProductData)
            }
            var values = food.per100g
            if correcting && editor.touched, let corrected = editor.per100g, editor.isValid {
                values = corrected
                try model.repo.updateFoodNutrients(key: food.barcode, per100g: corrected, name: name.trimmingCharacters(in: .whitespaces), brand: brand.trimmingCharacters(in: .whitespaces))
            }
            // Datum des gewählten Tages, Uhrzeit von jetzt.
            let at = DateMath.combine(day: model.selectedDay, time: Date())
            try model.repo.addEntry(key: food.barcode, grams: validGrams, mealType: mealType, per100g: values, at: at)
            Haptics.success()
            model.dataChanged()
            onDone(.saved(continueScanning: continueScanning))
        } catch {
            errorMessage = "Der Eintrag konnte nicht gespeichert werden. Bitte versuche es erneut."
        }
    }

    private func restoreFromOpenFoodFacts() {
        restoring = true
        Task {
            let result = await model.client.fetchProduct(barcode: food.barcode)
            restoring = false
            guard case .found(let product) = result else {
                errorMessage = "Open Food Facts hat gerade keine vollständigen Werte für dieses Produkt."
                return
            }
            do {
                try model.repo.restoreFromOpenFoodFacts(product)
                correcting = false
                onDone(.cancelled)
            } catch {
                errorMessage = "Wiederherstellen fehlgeschlagen."
            }
        }
    }
}
