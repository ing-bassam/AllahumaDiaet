import SwiftUI

/// Profil anlegen oder bearbeiten; daraus entsteht das Tagesziel.
struct ProfileFormView: View {
    var isOnboarding: Bool

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var age = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var goalWeight = ""
    @State private var sex: Sex?
    @State private var activity: ActivityLevel?
    @State private var protein = "30"
    @State private var carbs = "50"
    @State private var fat = "20"
    @State private var useCustomGoal = false
    @State private var customGoal = ""
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var loaded = false

    private func inRange(_ text: String, _ range: ClosedRange<Double>) -> Double? {
        guard let value = Formatting.parseDecimal(text), range.contains(value) else { return nil }
        return value
    }

    private func rangeError(_ text: String, _ range: ClosedRange<Double>, _ unit: String) -> String? {
        if text.trimmingCharacters(in: .whitespaces).isEmpty || inRange(text, range) != nil { return nil }
        return "Bitte einen Wert zwischen \(NumberFormat.int(range.lowerBound)) und \(NumberFormat.int(range.upperBound)) \(unit) eingeben."
    }

    private var ageValue: Double? { inRange(age, Nutrition.ageRange) }
    private var heightValue: Double? { inRange(height, Nutrition.heightRange) }
    private var weightValue: Double? { inRange(weight, Nutrition.weightRange) }
    private var goalWeightValue: Double? { inRange(goalWeight, Nutrition.weightRange) }

    private var macroSplit: MacroSplit {
        MacroSplit(
            protein: (Formatting.parseDecimal(protein) ?? .nan) / 100,
            carbs: (Formatting.parseDecimal(carbs) ?? .nan) / 100,
            fat: (Formatting.parseDecimal(fat) ?? .nan) / 100
        )
    }
    private var splitValid: Bool { Nutrition.isValidMacroSplit(macroSplit) }
    private var splitSum: Double { [protein, carbs, fat].reduce(0) { $0 + (Formatting.parseDecimal($1) ?? 0) } }

    private var goal: CalorieGoal? {
        guard let ageValue, let sex, let heightValue, let weightValue, let goalWeightValue, let activity else { return nil }
        return Nutrition.calculateCalorieGoal(GoalInput(
            age: Int(NumberFormat.jsRound(ageValue)), sex: sex, heightCm: heightValue, weightKg: weightValue,
            goalWeightKg: goalWeightValue, activityLevel: activity
        ))
    }

    private var choice: DailyGoalChoice? {
        guard let goal else { return nil }
        return Nutrition.chooseDailyGoal(goal, customEnabled: useCustomGoal, customKcal: Formatting.parseDecimal(customGoal))
    }

    private var customGoalError: String? {
        guard useCustomGoal else { return nil }
        let range = Double(Nutrition.customGoalRange.lowerBound)...Double(Nutrition.customGoalRange.upperBound)
        return rangeError(customGoal, range, "kcal")
    }

    private var canSave: Bool { choice != nil && splitValid && !saving }

    private var goalHint: String? {
        guard let goal else { return nil }
        if goal.adjustment < 0 { return "Gesamtbedarf \(NumberFormat.int(Double(goal.tdee))) kcal, minus \(NumberFormat.int(Double(-goal.adjustment))) kcal zum Abnehmen" }
        if goal.adjustment > 0 { return "Gesamtbedarf \(NumberFormat.int(Double(goal.tdee))) kcal, plus \(NumberFormat.int(Double(goal.adjustment))) kcal zum Zunehmen" }
        return "Gesamtbedarf \(NumberFormat.int(Double(goal.tdee))) kcal, Gewicht halten"
    }

    var body: some View {
        Form {
            Section {
                Text(isOnboarding ? "Einmal ausfüllen. Daraus berechnen wir dein tägliches Kalorienziel – oder du legst es selbst fest." : "Änderungen wirken ab sofort auf dein Tagesziel.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Körper") {
                LabeledInput(label: "Alter", unit: "Jahre", text: $age, keyboard: .numberPad, error: rangeError(age, Nutrition.ageRange, "Jahren"))
                LabeledInput(label: "Größe", unit: "cm", text: $height, error: rangeError(height, Nutrition.heightRange, "cm"))
                Picker("Geschlecht (für die Formel)", selection: $sex) {
                    Text("Bitte wählen").tag(Sex?.none)
                    ForEach(Sex.allCases, id: \.self) { value in
                        Text(value.label).tag(Sex?.some(value))
                    }
                }
            }

            Section("Gewicht") {
                LabeledInput(label: "Aktuelles Gewicht", unit: "kg", text: $weight, error: rangeError(weight, Nutrition.weightRange, "kg"))
                LabeledInput(label: "Zielgewicht", unit: "kg", text: $goalWeight, error: rangeError(goalWeight, Nutrition.weightRange, "kg"))
            }

            Section("Aktivität im Alltag") {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Button {
                        activity = level
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.label).font(.body.weight(.semibold)).foregroundStyle(Color.primary)
                                Text(level.description).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if activity == level {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
                            }
                        }
                    }
                    .accessibilityAddTraits(activity == level ? [.isSelected] : [])
                }
            }

            Section {
                HStack(spacing: 10) {
                    LabeledInput(label: "Protein", unit: "%", text: $protein, keyboard: .numberPad)
                    LabeledInput(label: "Kohlenh.", unit: "%", text: $carbs, keyboard: .numberPad)
                    LabeledInput(label: "Fett", unit: "%", text: $fat, keyboard: .numberPad)
                }
                if !splitValid {
                    Text("Die drei Werte müssen zusammen 100 % ergeben (aktuell \(NumberFormat.int(splitSum)) %).")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
            } header: {
                Text("Makroverteilung")
            }

            Section("Dein Tagesziel") {
                VStack(spacing: 6) {
                    Text(choice.map { "\(NumberFormat.int(Double($0.dailyGoal))) kcal" } ?? "–")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    if let goal, useCustomGoal {
                        Text("Eigenes Ziel · berechnet wären \(NumberFormat.int(Double(goal.dailyGoal))) kcal")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let goal, let goalHint {
                        Text("Grundumsatz \(NumberFormat.int(Double(goal.bmr))) kcal · \(goalHint)")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    if let choice, splitValid {
                        let macros = Nutrition.macroGoalsInGrams(dailyCalories: choice.dailyGoal, split: macroSplit)
                        Text("Protein \(macros.protein) g · Kohlenhydrate \(macros.carbs) g · Fett \(macros.fat) g")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                Toggle("Eigenes Tagesziel festlegen", isOn: $useCustomGoal)
                    .onChange(of: useCustomGoal) { _, on in
                        // Mit dem berechneten Wert starten, damit man nur noch anpassen muss.
                        if on, customGoal.trimmingCharacters(in: .whitespaces).isEmpty, let goal {
                            customGoal = String(goal.dailyGoal)
                        }
                    }
                if useCustomGoal {
                    LabeledInput(label: "Eigenes Tagesziel", unit: "kcal", text: $customGoal, keyboard: .numberPad, error: customGoalError)
                    if let choice, choice.belowBmr, let goal {
                        Text("Dein Ziel liegt unter deinem Grundumsatz von \(NumberFormat.int(Double(goal.bmr))) kcal. So wenig Energie über längere Zeit solltest du nur nach ärztlicher oder ernährungsfachlicher Beratung einplanen.")
                            .font(.caption)
                            .foregroundStyle(Theme.danger)
                    }
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    Text("Speichern").font(.headline).frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alle Angaben bleiben ausschließlich auf deinem Gerät. Es gibt kein Konto und keine Werbung. Beim Scannen und bei der Online-Suche wird nur der Barcode bzw. Suchbegriff an Open Food Facts gesendet, um das Produkt zu finden.")
                    Text("Berechnet wird der Grundumsatz nach der Formel von Mifflin-St. Jeor, multipliziert mit dem PAL-Faktor deines Aktivitätslevels nach den Referenzwerten der Deutschen Gesellschaft für Ernährung.")
                    Text(CalculationInfo.medicalDisclaimer)
                }
                .padding(.top, 8)
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    Label("Berechnung & Quellen", systemImage: "info.circle")
                }
            }
        }
        .navigationTitle("Dein Profil")
        .navigationBarTitleDisplayMode(isOnboarding ? .large : .inline)
        .keyboardDoneButton()
        .onAppear { prefill() }
        .alert("Fehler", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func prefill() {
        guard !loaded else { return }
        loaded = true
        guard let p = model.profile else { return }
        age = String(p.age)
        sex = p.sex
        height = Formatting.inputText(p.heightCm)
        weight = Formatting.inputText(p.weightKg)
        goalWeight = Formatting.inputText(p.goalWeightKg)
        activity = p.activityLevel
        protein = String(Int(NumberFormat.jsRound(p.macroSplit.protein * 100)))
        carbs = String(Int(NumberFormat.jsRound(p.macroSplit.carbs * 100)))
        fat = String(Int(NumberFormat.jsRound(p.macroSplit.fat * 100)))
        if p.calorieGoalIsCustom {
            useCustomGoal = true
            customGoal = String(p.dailyCalorieGoal)
        }
    }

    private func save() {
        guard let choice, let sex, let activity, let ageValue, let heightValue, let weightValue, let goalWeightValue, splitValid else { return }
        saving = true
        defer { saving = false }
        let profile = Profile(
            id: model.profile?.id ?? UUID().uuidString.lowercased(),
            age: Int(NumberFormat.jsRound(ageValue)),
            sex: sex,
            heightCm: heightValue,
            weightKg: weightValue,
            goalWeightKg: goalWeightValue,
            activityLevel: activity,
            dailyCalorieGoal: choice.dailyGoal,
            calorieGoalIsCustom: choice.isCustom,
            macroSplit: macroSplit
        )
        do {
            try model.repo.saveProfile(profile)
            Haptics.success()
            model.reloadProfile()
            if !isOnboarding { dismiss() }
        } catch {
            errorMessage = "Speichern fehlgeschlagen. Bitte versuche es erneut."
        }
    }
}
