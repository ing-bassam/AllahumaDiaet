import Charts
import SwiftUI

struct DayStat: Identifiable {
    var day: Date
    var key: String
    var label: String
    var calories: Double?
    var id: String { key }
}

/// Wochenübersicht und Gewichtsverlauf.
struct StatsView: View {
    @EnvironmentObject private var model: AppModel

    @State private var days: [DayStat] = []
    @State private var weights: [WeightEntry] = []
    @State private var showWeightSheet = false
    @State private var weightToDelete: WeightEntry?

    private var goal: Int { model.profile?.dailyCalorieGoal ?? 0 }
    private var loggedDays: [DayStat] { days.filter { $0.calories != nil } }
    private var averageCalories: Double? {
        let values = loggedDays.compactMap { $0.calories }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Letzte 7 Tage") {
                    Chart {
                        ForEach(days) { day in
                            BarMark(x: .value("Tag", day.label), y: .value("kcal", day.calories ?? 0))
                                .foregroundStyle((day.calories ?? 0) > Double(goal) && goal > 0 ? Theme.danger : Theme.primary)
                                .cornerRadius(6)
                        }
                        if goal > 0 {
                            RuleMark(y: .value("Ziel", goal))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                .foregroundStyle(.secondary)
                                .annotation(position: .top, alignment: .trailing) {
                                    Text("Ziel \(NumberFormat.int(Double(goal)))").font(.caption2).foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(height: 200)
                    .padding(.vertical, 6)
                    .accessibilityLabel("Kalorien der letzten sieben Tage")

                    HStack {
                        statTile(title: "Ø pro Tag", value: averageCalories.map { "\(NumberFormat.int($0)) kcal" } ?? "–")
                        statTile(title: "Tage mit Einträgen", value: "\(loggedDays.count) von 7")
                    }
                    if let averageCalories, goal > 0 {
                        let diff = averageCalories - Double(goal)
                        Text(abs(diff) < 50
                             ? "Im Schnitt genau im Ziel."
                             : (diff < 0 ? "Im Schnitt \(NumberFormat.int(-diff)) kcal unter dem Ziel." : "Im Schnitt \(NumberFormat.int(diff)) kcal über dem Ziel."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    if weights.count >= 2 {
                        Chart(weights.reversed()) { entry in
                            if let date = DateMath.parseDateKey(entry.date) {
                                LineMark(x: .value("Datum", date), y: .value("kg", entry.weightKg))
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(Theme.primary)
                                PointMark(x: .value("Datum", date), y: .value("kg", entry.weightKg))
                                    .foregroundStyle(Theme.primary)
                            }
                        }
                        .chartYScale(domain: weightDomain)
                        .frame(height: 180)
                        .padding(.vertical, 6)
                        .accessibilityLabel("Gewichtsverlauf")
                    }
                    if weights.isEmpty {
                        Text("Noch kein Gewicht eingetragen. Trag es regelmäßig ein, dann siehst du hier den Verlauf.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(weights.prefix(10)) { entry in
                        HStack {
                            Text(DateMath.parseDateKey(entry.date).map { DateMath.fullDateLabel($0) } ?? entry.date)
                            Spacer()
                            Text("\(NumberFormat.decimal(entry.weightKg)) kg").monospacedDigit()
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { try? model.repo.deleteWeight(dateKey: weights[index].date) }
                        loadWeights()
                    }
                    Button {
                        showWeightSheet = true
                    } label: {
                        Label("Gewicht eintragen", systemImage: "scalemass")
                    }
                } header: {
                    Text("Gewicht")
                } footer: {
                    if let profile = model.profile {
                        Text("Zielgewicht \(NumberFormat.decimal(profile.goalWeightKg)) kg · im Profil hinterlegt: \(NumberFormat.decimal(profile.weightKg)) kg")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Verlauf")
            .onAppear { load() }
            .onChange(of: model.entries) { _, _ in load() }
            .onChange(of: model.profile) { _, _ in load() }
            .sheet(isPresented: $showWeightSheet) {
                WeightEntrySheet { loadWeights() }
            }
        }
    }

    private var weightDomain: ClosedRange<Double> {
        let values = weights.map { $0.weightKg }
        let low = (values.min() ?? 0) - 1
        let high = (values.max() ?? 0) + 1
        return low...max(high, low + 2)
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() {
        let today = model.today
        let start = DateMath.addDays(today, -6)
        let totals = (try? model.repo.dailyTotals(from: Formatting.dateKey(start), to: Formatting.dateKey(today))) ?? [:]
        days = (0..<7).map { offset in
            let day = DateMath.addDays(start, offset)
            let key = Formatting.dateKey(day)
            let weekday = Calendar.current.component(.weekday, from: day)
            return DayStat(day: day, key: key, label: DateMath.weekdayLabels[(weekday + 5) % 7], calories: totals[key]?.calories)
        }
        loadWeights()
    }

    private func loadWeights() {
        weights = (try? model.repo.weights(limit: 90)) ?? []
    }
}

/// Heutiges Gewicht eintragen, auf Wunsch auch ins Profil übernehmen.
struct WeightEntrySheet: View {
    var onSaved: () -> Void

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var weight = ""
    @State private var updateProfile = true
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    private var value: Double? {
        guard let v = Formatting.parseDecimal(weight), Nutrition.weightRange.contains(v) else { return nil }
        return v
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledInput(label: "Gewicht heute", unit: "kg", text: $weight, error: weight.isEmpty || value != nil ? nil : "Bitte einen Wert zwischen 30 und 300 kg eingeben.")
                        .focused($focused)
                    Toggle("Auch im Profil übernehmen", isOn: $updateProfile)
                } footer: {
                    Text(updateProfile
                         ? "Das Profilgewicht und – wenn du kein eigenes Ziel festgelegt hast – das Tagesziel werden mit diesem Wert neu berechnet."
                         : "Das Gewicht wird nur im Verlauf gespeichert.")
                }
            }
            .navigationTitle("Gewicht eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { save() }.disabled(value == nil) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { focused = false }
                }
            }
            .onAppear {
                if let current = model.profile?.weightKg { weight = Formatting.inputText(current) }
                focused = true
            }
            .alert("Fehler", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let value else { return }
        do {
            try model.repo.saveWeight(dateKey: Formatting.dateKey(model.today), weightKg: value)
            if updateProfile, var profile = model.profile {
                profile.weightKg = value
                if !profile.calorieGoalIsCustom {
                    profile.dailyCalorieGoal = Nutrition.calculateCalorieGoal(profile.goalInput).dailyGoal
                }
                try model.repo.saveProfile(profile)
                model.reloadProfile()
            }
            Haptics.success()
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Speichern fehlgeschlagen. Bitte versuche es erneut."
        }
    }
}
