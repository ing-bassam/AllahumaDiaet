import Foundation
import SwiftUI
import WidgetKit

/// Zustand der ganzen App: Datenbank, Profil, der angezeigte Tag und die offenen Dialoge.
@MainActor
final class AppModel: ObservableObject {
    enum LoadState: Equatable {
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var loadState: LoadState = .loading
    @Published private(set) var profile: Profile?
    @Published private(set) var today: Date
    @Published private(set) var selectedDay: Date
    @Published private(set) var entries: [LogEntry] = []
    @Published private(set) var previousDayEntries: [LogEntry] = []
    @Published private(set) var dayLoaded = false

    @Published var showScanner = false
    @Published var showSearch = false
    @Published var showQuickEntry = false
    @Published var editingEntry: LogEntry?

    private(set) var repository: Repository?
    let client = OpenFoodFactsClient(userAgent: AppInfo.userAgent)
    let searchLimiter = RateLimiter(limit: OpenFoodFacts.searchRateLimit, windowSeconds: OpenFoodFacts.searchRateWindowSeconds)
    /// Ausgewählte Online-Suchtreffer für den Produkt-Screen, ohne zweite Anfrage. Lebt nur im Arbeitsspeicher.
    private var searchHandoff: [String: SearchHit] = [:]
    private var searchHandoffOrder: [String] = []

    init() {
        let start = DateMath.startOfDay(Date())
        today = start
        selectedDay = start
    }

    /// Nur nach erfolgreichem Laden verwenden; die Oberfläche zeigt vorher den Lade- oder Fehlerzustand.
    var repo: Repository {
        guard let repository else { preconditionFailure("Datenbank ist noch nicht geöffnet") }
        return repository
    }

    var selectedKey: String { Formatting.dateKey(selectedDay) }
    var isToday: Bool { DateMath.isSameDay(selectedDay, today) }
    var totals: Nutrients { Nutrition.sum(entries.map { $0.totals }) }

    func load() {
        loadState = .loading
        do {
            let queue = try AppDatabase.openDefault()
            let repository = Repository(queue: queue)
            self.repository = repository
            profile = try repository.profile()
            loadState = .ready
            reloadDay()
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    /// War der ausgewählte Tag „heute“, wandert er nach Mitternacht auf den neuen heutigen Tag.
    func refreshToday() {
        let now = DateMath.startOfDay(Date())
        guard !DateMath.isSameDay(now, today) else { return }
        let wasToday = isToday
        today = now
        if wasToday { selectedDay = now }
        reloadDay()
    }

    func select(day: Date) {
        selectedDay = DateMath.startOfDay(day)
        reloadDay()
    }

    func shiftDay(_ delta: Int) {
        select(day: DateMath.addDays(selectedDay, delta))
    }

    func goToToday() {
        select(day: today)
    }

    func reloadDay() {
        guard let repository else { return }
        do {
            entries = try repository.entries(dateKey: selectedKey)
            previousDayEntries = try repository.entries(dateKey: Formatting.dateKey(DateMath.addDays(selectedDay, -1)))
            dayLoaded = true
        } catch {
            loadState = .failed(error.localizedDescription)
            return
        }
        updateWidgetSnapshot()
    }

    func reloadProfile() {
        guard let repository else { return }
        profile = try? repository.profile()
        updateWidgetSnapshot()
    }

    /// Nach jeder Änderung am Tagebuch aufrufen.
    func dataChanged() {
        reloadDay()
    }

    func afterDeleteAll() {
        profile = nil
        entries = []
        previousDayEntries = []
        TodaySnapshot.remove()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Online-Suche → Produkt-Screen

    func rememberSearchHit(_ hit: SearchHit) {
        if searchHandoff[hit.key] == nil { searchHandoffOrder.append(hit.key) }
        searchHandoff[hit.key] = hit
        while searchHandoffOrder.count > 200 {
            let oldest = searchHandoffOrder.removeFirst()
            searchHandoff[oldest] = nil
        }
    }

    func searchHit(for key: String) -> SearchHit? {
        searchHandoff[key]
    }

    // MARK: Deep Links (hachibu://scan, hachibu://search)

    func handle(url: URL) {
        guard url.scheme == "hachibu" else { return }
        switch url.host {
        case "scan":
            showSearch = false
            showQuickEntry = false
            showScanner = true
        case "search":
            showScanner = false
            showQuickEntry = false
            showSearch = true
        default:
            break
        }
    }

    // MARK: Widget

    func updateWidgetSnapshot() {
        guard let repository else { return }
        let todayKey = Formatting.dateKey(today)
        let todayEntries: [LogEntry] = isToday ? entries : ((try? repository.entries(dateKey: todayKey)) ?? [])
        let consumed = Nutrition.sum(todayEntries.map { $0.totals })
        let macros = profile?.macroGoals ?? MacroGrams(protein: 0, carbs: 0, fat: 0)
        let snapshot = TodaySnapshot(
            dateKey: todayKey,
            consumed: consumed,
            goalCalories: profile?.dailyCalorieGoal ?? 0,
            goalProtein: macros.protein,
            goalCarbs: macros.carbs,
            goalFat: macros.fat,
            entryCount: todayEntries.count,
            updatedAt: Date()
        )
        try? snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Bewertung

    private static let reviewRequestedKey = "reviewRequested"

    /// Einmalig, nachdem an fünf verschiedenen Tagen etwas eingetragen wurde.
    func shouldRequestReview() -> Bool {
        guard let repository, !UserDefaults.standard.bool(forKey: AppModel.reviewRequestedKey) else { return false }
        let days = (try? repository.distinctEntryDayCount()) ?? 0
        guard days >= 5 else { return false }
        UserDefaults.standard.set(true, forKey: AppModel.reviewRequestedKey)
        return true
    }
}
