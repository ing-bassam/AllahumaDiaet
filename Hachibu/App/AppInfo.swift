import Foundation

enum AppInfo {
    static let name = "Hachibu"
    static let contactEmail = "abdel.abu99@gmail.com"
    /// Kennung gegenüber Open Food Facts; bewusst unabhängig vom Anzeigenamen (seit der ersten Version so).
    static let apiClientName = "AllahumaDiaet"
    static let appStoreId = "6816385956"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    static var userAgent: String {
        OpenFoodFacts.userAgent(appName: apiClientName, appVersion: version, contactEmail: contactEmail)
    }

    static let appStoreURL = URL(string: "https://apps.apple.com/de/app/id6816385956")!
    static let reviewURL = URL(string: "https://apps.apple.com/de/app/id6816385956?action=write-review")!
}
