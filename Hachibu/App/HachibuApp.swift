import SwiftUI

@main
struct HachibuApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(Theme.primary)
                .onOpenURL { url in
                    model.handle(url: url)
                }
        }
    }
}
