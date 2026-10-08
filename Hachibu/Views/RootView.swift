import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        switch model.loadState {
        case .loading:
            ProgressView()
                .task { model.load() }
        case .failed(let message):
            LoadErrorView(title: "Hachibu konnte nicht starten", message: message) {
                model.load()
            }
        case .ready:
            if model.profile == nil {
                NavigationStack {
                    ProfileFormView(isOnboarding: true)
                }
            } else {
                MainTabView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Tagebuch", systemImage: "book.closed") }
            StatsView()
                .tabItem { Label("Verlauf", systemImage: "chart.bar") }
            MoreView()
                .tabItem { Label("Mehr", systemImage: "ellipsis.circle") }
        }
    }
}
