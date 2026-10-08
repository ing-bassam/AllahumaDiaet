import SwiftUI

/// Lebensmittel suchen: Favoriten, zuletzt verwendet, lokale Treffer und – nur auf Wunsch – online.
struct SearchView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    struct Destination: Hashable {
        var key: String
        var prefillName: String?
    }

    enum OnlineStatus: Equatable {
        case idle, loading, loadingMore, done, error
    }

    struct OnlineState: Equatable {
        var query = ""
        var scope: SearchScope = .germany
        var hits: [SearchHit] = []
        var page = 1
        var pageCount = 1
        var status: OnlineStatus = .idle
        var error: String?
        var notice: String?
    }

    private static let suggestionLimit = 8
    private static let localLimit = 20

    @State private var query = ""
    @State private var favorites: [FoodItem] = []
    @State private var recent: [FoodItem] = []
    @State private var frequent: [FoodItem] = []
    @State private var localResults: [FoodItem] = []
    @State private var online = OnlineState()
    @State private var onlineLocal: [String: FoodItem] = [:]
    @State private var searchRun = 0
    @State private var path: [Destination] = []

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSearch: Bool { trimmed.count >= LocalSearch.minQueryLength }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if trimmed.isEmpty {
                    suggestionSections
                } else {
                    resultSections
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Lebensmittel suchen")
            .onSubmit(of: .search) {
                Task { await runOnlineSearch(page: 1) }
            }
            .navigationTitle("Suchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                ProductView(key: destination.key, prefillName: destination.prefillName) { outcome in
                    switch outcome {
                    case .saved:
                        dismiss()
                    case .cancelled:
                        if !path.isEmpty { path.removeLast() }
                    }
                }
            }
            .onAppear { loadSuggestions() }
            .onChange(of: path.count) { _, count in
                // Nach der Rückkehr vom Produkt-Screen: dort Gespeichertes oder Korrigiertes zeigen.
                if count == 0 {
                    loadSuggestions()
                    loadLocal()
                    refreshOnlineLocal()
                }
            }
            .onChange(of: trimmed) { _, newValue in
                loadLocal()
                // Online-Ergebnisse gehören zu genau einem Suchbegriff.
                if online.status != .idle && online.query != newValue {
                    searchRun += 1
                    online = OnlineState()
                    onlineLocal = [:]
                }
            }
        }
    }

    // MARK: Abschnitte

    @ViewBuilder
    private var suggestionSections: some View {
        if !favorites.isEmpty {
            Section("Favoriten") {
                ForEach(favorites) { food in foodLink(food) }
            }
        }
        if !recent.isEmpty {
            Section("Zuletzt verwendet") {
                ForEach(recent) { food in foodLink(food) }
            }
        }
        if !frequent.isEmpty {
            Section("Häufig gegessen") {
                ForEach(frequent) { food in foodLink(food) }
            }
        }
        if favorites.isEmpty && recent.isEmpty && frequent.isEmpty {
            Section {
                Text("Gib einen Namen ein – Hachibu sucht zuerst auf deinem Gerät und auf Wunsch bei Open Food Facts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        Section {
            NavigationLink(value: Destination(key: FoodKey.newCustomKey(), prefillName: nil)) {
                Label("Eigenes Lebensmittel anlegen", systemImage: "plus.circle")
            }
        }
    }

    @ViewBuilder
    private var resultSections: some View {
        if !localResults.isEmpty {
            Section("Auf deinem Gerät") {
                ForEach(localResults) { food in foodLink(food) }
            }
        }

        Section("Open Food Facts") {
            switch online.status {
            case .idle:
                Button {
                    Task { await runOnlineSearch(page: 1) }
                } label: {
                    Label("Online suchen", systemImage: "globe")
                }
                .disabled(!canSearch)
            case .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Suche läuft …").foregroundStyle(.secondary)
                }
            case .error:
                Text(online.error ?? "Fehler bei der Suche.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Erneut versuchen") {
                    Task { await runOnlineSearch(page: 1) }
                }
            case .done, .loadingMore:
                if let notice = online.notice {
                    Text(notice).font(.caption).foregroundStyle(.secondary)
                }
                if online.hits.isEmpty {
                    Text("Keine Treffer bei Open Food Facts.").foregroundStyle(.secondary)
                }
                ForEach(online.hits) { hit in
                    hitLink(hit)
                }
                if online.status == .loadingMore {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Lade mehr …").foregroundStyle(.secondary)
                    }
                } else if online.page < online.pageCount {
                    if let error = online.error {
                        Text(error).font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Mehr laden") {
                        Task { await runOnlineSearch(page: online.page + 1) }
                    }
                }
            }
        }

        Section {
            NavigationLink(value: Destination(key: FoodKey.newCustomKey(), prefillName: trimmed)) {
                Label("„\(trimmed)“ als eigenes Lebensmittel anlegen", systemImage: "plus.circle")
            }
        }
    }

    private func foodLink(_ food: FoodItem) -> some View {
        NavigationLink(value: Destination(key: food.barcode, prefillName: nil)) {
            FoodRow(name: food.name, brand: food.brand, calories: food.per100g.calories, imageUrl: food.imageUrl, badge: food.favorite ? "star.fill" : nil)
        }
    }

    private func hitLink(_ hit: SearchHit) -> some View {
        let local = onlineLocal[hit.key]
        return NavigationLink(value: Destination(key: hit.key, prefillName: nil)) {
            switch hit {
            case .found(let product):
                // Lokal vorhandene Produkte gewinnen: Ihre gespeicherten (ggf. korrigierten) Werte werden angezeigt.
                FoodRow(name: local?.name ?? product.name, brand: local?.brand ?? product.brand,
                        calories: local?.per100g.calories ?? product.caloriesPer100g, imageUrl: product.imageUrl,
                        badge: local != nil ? "checkmark.circle" : nil)
            case .incomplete(let partial):
                FoodRow(name: local?.name ?? partial.name, brand: local?.brand ?? partial.brand,
                        calories: local?.per100g.calories, imageUrl: partial.imageUrl,
                        badge: local != nil ? "checkmark.circle" : nil, subtitle: local == nil ? "Nährwerte fehlen" : nil)
            }
        }
    }

    // MARK: Laden

    private func loadSuggestions() {
        favorites = (try? model.repo.favoriteFoods()) ?? []
        recent = (try? model.repo.recentFoods(limit: SearchView.suggestionLimit)) ?? []
        frequent = (try? model.repo.frequentFoods(limit: SearchView.suggestionLimit)) ?? []
    }

    private func loadLocal() {
        guard canSearch else {
            localResults = []
            return
        }
        localResults = (try? model.repo.searchLocalFoods(query: trimmed, limit: SearchView.localLimit)) ?? []
    }

    private func refreshOnlineLocal() {
        let keys = online.hits.map { $0.key }
        guard !keys.isEmpty, let locals = try? model.repo.foodItems(keys: keys) else { return }
        for food in locals { onlineLocal[food.barcode] = food }
    }

    private func message(for result: SearchResult) -> String {
        switch result {
        case .rateLimited(let seconds):
            if let seconds { return "Zu viele Suchanfragen. Bitte in \(seconds) Sekunden erneut versuchen." }
            return "Zu viele Suchanfragen. Bitte gleich erneut versuchen."
        case .timeout: return "Die Suche hat zu lange gedauert. Bitte erneut versuchen."
        case .offline: return "Keine Internetverbindung."
        case .unavailable: return "Open Food Facts ist gerade nicht erreichbar. Bitte später erneut versuchen."
        case .ok: return ""
        }
    }

    private func runOnlineSearch(page: Int) async {
        let q = trimmed
        guard canSearch else { return }
        searchRun += 1
        let run = searchRun
        let scope: SearchScope = page == 1 ? .germany : online.scope
        if page == 1 {
            online = OnlineState(query: q, status: .loading)
            onlineLocal = [:]
        } else {
            online.status = .loadingMore
            online.error = nil
        }

        let limiter = model.searchLimiter
        let (result, usedScope) = await model.client.searchProducts(query: q, page: page, scope: scope) { limiter.tryAcquire() }
        // Veraltete Antworten verwerfen: Begriff geändert oder neue Suche gestartet.
        guard run == searchRun, trimmed == q else { return }

        guard case .ok(let pageData) = result else {
            online.error = message(for: result)
            online.status = page == 1 ? .error : .done
            return
        }

        let locals = (try? model.repo.foodItems(keys: pageData.hits.map { $0.key })) ?? []
        for food in locals { onlineLocal[food.barcode] = food }
        // Treffer merken: Der Produkt-Screen nutzt sie direkt, ohne das Produkt ein zweites Mal abzufragen.
        for hit in pageData.hits { model.rememberSearchHit(hit) }

        let existing = page == 1 ? [] : online.hits
        let known = Set(existing.map { $0.key })
        online = OnlineState(
            query: q,
            scope: usedScope,
            hits: existing + pageData.hits.filter { !known.contains($0.key) },
            page: pageData.page,
            pageCount: pageData.pageCount,
            status: .done,
            error: nil,
            notice: page == 1 ? (usedScope == .world ? "Keine Treffer aus Deutschland – Ergebnisse weltweit." : nil) : online.notice
        )
    }
}

struct FoodRow: View {
    var name: String
    var brand: String
    var calories: Double?
    var imageUrl: String?
    var badge: String? = nil
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            FoodThumbnail(imageUrl: imageUrl)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(name).lineLimit(1)
                    if let badge {
                        Image(systemName: badge).font(.caption).foregroundStyle(Theme.carbs)
                    }
                }
                let line = [brand, subtitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                if !line.isEmpty {
                    Text(line).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if let calories {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(NumberFormat.int(calories)).font(.body.weight(.semibold)).monospacedDigit()
                    Text("kcal/100 g").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}
