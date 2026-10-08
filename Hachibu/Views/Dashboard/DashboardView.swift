import StoreKit
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    @State private var showCalendar = false
    @State private var repeatCandidate: MealToRepeat<LogEntry>?
    @State private var errorMessage: String?

    private var entriesByMeal: [MealType: [LogEntry]] {
        Dictionary(grouping: model.entries, by: { $0.mealType })
    }

    private var repeatable: [MealToRepeat<LogEntry>] {
        model.dayLoaded ? mealsToRepeat(previousDay: model.previousDayEntries, selectedDay: model.entries) : []
    }

    private var previousDayLabel: String { model.isToday ? "gestern" : "am Vortag" }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DaySummaryCard(showCalendar: $showCalendar)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if model.dayLoaded && model.entries.isEmpty {
                    Section {
                        Text(model.isToday ? "Noch nichts eingetragen.\nTippe unten auf „Scannen“ oder die Lupe." : "An diesem Tag ist nichts eingetragen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                    }
                }

                ForEach(MealType.allCases) { meal in
                    if let mealEntries = entriesByMeal[meal], !mealEntries.isEmpty {
                        Section {
                            ForEach(mealEntries) { entry in
                                Button {
                                    model.editingEntry = entry
                                } label: {
                                    EntryRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { offsets in
                                delete(offsets.map { mealEntries[$0] })
                            }
                        } header: {
                            HStack {
                                Label(meal.label, systemImage: meal.symbol)
                                Spacer()
                                Text("\(NumberFormat.int(mealEntries.reduce(0) { $0 + $1.totals.calories })) kcal")
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                if !repeatable.isEmpty {
                    Section("Wie \(previousDayLabel) eintragen") {
                        ForEach(repeatable, id: \.mealType) { meal in
                            Button {
                                repeatCandidate = meal
                            } label: {
                                HStack {
                                    Label("\(meal.label) (\(meal.entries.count))", systemImage: "plus.circle")
                                    Spacer()
                                    Text("\(NumberFormat.int(meal.entries.reduce(0) { $0 + $1.totals.calories })) kcal")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }

                Section {
                    Text("Daten & Bilder: Open Food Facts (ODbL, CC BY-SA)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .navigationTitle(DateMath.dayTitle(model.selectedDay, today: model.today))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !model.isToday {
                        Button("Heute") { model.goToToday() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("Kalender")
                }
            }
            .safeAreaInset(edge: .bottom) {
                ActionBar()
            }
            .fullScreenCover(isPresented: $model.showScanner) {
                ScannerView()
            }
            .sheet(isPresented: $model.showSearch) {
                SearchView()
            }
            .sheet(isPresented: $model.showQuickEntry) {
                QuickEntryView()
            }
            .sheet(item: $model.editingEntry) { entry in
                EntryEditView(entry: entry)
            }
            .sheet(isPresented: $showCalendar) {
                CalendarSheet()
            }
            .confirmationDialog(
                repeatCandidate.map { "\($0.label) wie \(previousDayLabel)?" } ?? "",
                isPresented: Binding(get: { repeatCandidate != nil }, set: { if !$0 { repeatCandidate = nil } }),
                titleVisibility: .visible,
                presenting: repeatCandidate
            ) { meal in
                Button("Eintragen") { repeatMeal(meal) }
                Button("Abbrechen", role: .cancel) {}
            } message: { meal in
                Text(meal.entries.map { "\($0.displayName) (\(NumberFormat.decimal($0.grams)) g)" }.joined(separator: "\n"))
            }
            .alert("Fehler", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    model.refreshToday()
                    model.reloadDay()
                }
            }
            .task {
                if model.shouldRequestReview() {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    requestReview()
                }
            }
        }
    }

    private func delete(_ entries: [LogEntry]) {
        do {
            for entry in entries {
                try model.repo.deleteEntry(id: entry.id)
            }
            model.dataChanged()
        } catch {
            errorMessage = "Der Eintrag konnte nicht gelöscht werden."
        }
    }

    private func repeatMeal(_ meal: MealToRepeat<LogEntry>) {
        do {
            try model.repo.copyEntries(meal.entries, to: model.selectedDay)
            Haptics.success()
            model.dataChanged()
        } catch {
            errorMessage = "Eintragen fehlgeschlagen. Bitte versuche es erneut."
        }
    }
}

/// Kopfbereich mit Tagesnavigation, Kalorienring und Makro-Balken.
struct DaySummaryCard: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showCalendar: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    model.shiftDay(-1)
                } label: {
                    Image(systemName: "chevron.left").font(.title3.weight(.semibold)).padding(8)
                }
                .accessibilityLabel("Vorheriger Tag")
                Spacer()
                Button {
                    showCalendar = true
                } label: {
                    VStack(spacing: 2) {
                        Text(DateMath.dayDateLine(model.selectedDay, today: model.today))
                            .font(.headline)
                        Text(DateMath.weekdays[Calendar.current.component(.weekday, from: model.selectedDay) - 1])
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(DateMath.fullDateLabel(model.selectedDay))
                Spacer()
                Button {
                    model.shiftDay(1)
                } label: {
                    Image(systemName: "chevron.right").font(.title3.weight(.semibold)).padding(8)
                }
                .accessibilityLabel("Nächster Tag")
            }

            CalorieRing(consumed: model.totals.calories, goal: Double(model.profile?.dailyCalorieGoal ?? 0))
                .frame(width: 210, height: 210)
                .padding(.vertical, 4)

            let macros = model.profile?.macroGoals ?? MacroGrams(protein: 0, carbs: 0, fat: 0)
            HStack(spacing: 16) {
                MacroBar(label: "Protein", consumed: model.totals.protein, goal: macros.protein, color: Theme.protein)
                MacroBar(label: "Kohlenh.", consumed: model.totals.carbs, goal: macros.carbs, color: Theme.carbs)
                MacroBar(label: "Fett", consumed: model.totals.fat, goal: macros.fat, color: Theme.fat)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .simultaneousGesture(
            DragGesture(minimumDistance: 40).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                model.shiftDay(value.translation.width < 0 ? 1 : -1)
            }
        )
    }
}

struct EntryRow: View {
    var entry: LogEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(Formatting.time(entry.timestamp))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .lineLimit(1)
                Text([entry.brand, entry.isQuickEntry ? nil : "\(NumberFormat.decimal(entry.grams)) g"].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(NumberFormat.int(entry.totals.calories))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.displayName), \(NumberFormat.decimal(entry.grams)) Gramm, \(NumberFormat.int(entry.totals.calories)) Kilokalorien")
        .accessibilityHint("Tippen zum Bearbeiten")
    }
}

/// Die drei Knöpfe am unteren Rand: Suchen, Scannen, Schnelleintrag.
struct ActionBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Button {
                model.showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.semibold))
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(.bordered)
            .clipShape(Circle())
            .accessibilityLabel("Lebensmittel suchen")

            Button {
                model.showScanner = true
            } label: {
                Label("Scannen", systemImage: "barcode.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Capsule())

            Button {
                model.showQuickEntry = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(.bordered)
            .clipShape(Circle())
            .accessibilityLabel("Schnelleintrag")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.bar)
    }
}
