import Foundation

// Anbindung an die Open Food Facts API (https://openfoodfacts.github.io/openfoodfacts-server/api/).
// Daten stehen unter der Open Database License (ODbL) und müssen in der App genannt werden.

struct ProductData: Equatable {
    var barcode: String
    var name: String
    var brand: String
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var servingSizeG: Double?
    var imageUrl: String?

    var per100g: Nutrients {
        Nutrients(calories: caloriesPer100g, protein: proteinPer100g, carbs: carbsPer100g, fat: fatPer100g)
    }
}

/// Was trotz fehlender Nährwerte schon bekannt ist, um das manuelle Formular vorzubefüllen.
struct PartialProduct: Equatable {
    var barcode: String
    var name: String
    var brand: String
    var servingSizeG: Double?
    var imageUrl: String?
}

enum LookupResult: Equatable {
    case found(ProductData)
    case incomplete(PartialProduct)
    case notFound
    case error
}

enum SearchHit: Equatable, Identifiable {
    case found(ProductData)
    case incomplete(PartialProduct)

    var key: String {
        switch self {
        case .found(let p): return p.barcode
        case .incomplete(let p): return p.barcode
        }
    }

    var id: String { key }

    var name: String {
        switch self {
        case .found(let p): return p.name
        case .incomplete(let p): return p.name
        }
    }

    var brand: String {
        switch self {
        case .found(let p): return p.brand
        case .incomplete(let p): return p.brand
        }
    }

    var imageUrl: String? {
        switch self {
        case .found(let p): return p.imageUrl
        case .incomplete(let p): return p.imageUrl
        }
    }
}

struct SearchPage: Equatable {
    var hits: [SearchHit]
    var count: Int
    var page: Int
    var pageCount: Int
}

enum SearchResult: Equatable {
    case ok(SearchPage)
    case rateLimited(retryAfterSeconds: Int?)
    case timeout
    case offline
    case unavailable
}

enum SearchScope: String {
    case germany
    case world
}

enum OpenFoodFacts {
    static let apiBase = "https://world.openfoodfacts.org/api/v2/product"
    static let fields = ["product_name", "product_name_de", "brands", "nutriments", "product_quantity", "product_quantity_unit", "image_front_small_url"]
    static let timeoutSeconds: TimeInterval = 8
    static let kjPerKcal = 4.184

    // Volltextsuche nur über Search-a-licious. Open Food Facts dokumentiert 10 Anfragen pro Minute je
    // IP-Adresse und rät von Suche beim Tippen ab; die App sucht deshalb nur beim Absenden.
    static let searchBase = "https://search.openfoodfacts.org/search"
    static let searchTimeoutSeconds: TimeInterval = 10
    static let searchPageSize = 20
    /// Bewusst unter dem dokumentierten Limit von 10 Anfragen pro Minute.
    static let searchRateLimit = 8
    static let searchRateWindowSeconds = 60.0
    static let searchFields = ["code", "product_name", "product_name_de", "brands", "nutriments", "product_quantity", "product_quantity_unit", "image_front_small_url"]

    /// Open Food Facts verlangt einen eindeutigen User-Agent im Format `AppName/Version (Kontakt-E-Mail)`.
    static func userAgent(appName: String, appVersion: String, contactEmail: String) -> String {
        "\(appName)/\(appVersion) (\(contactEmail))"
    }

    // MARK: Parsen

    static func toNumber(_ value: Any?) -> Double? {
        if let n = value as? NSNumber {
            return n.doubleValue.isFinite ? n.doubleValue : nil
        }
        if let s = value as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            guard let parsed = Double(trimmed.replacingOccurrences(of: ",", with: ".")), parsed.isFinite else { return nil }
            return parsed
        }
        return nil
    }

    static func toText(_ value: Any?) -> String {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Die Produkt-API liefert Marken als Text („A, B“), die Suche als Liste.
    static func firstBrand(_ value: Any?) -> String {
        if let list = value as? [Any] {
            let strings = list.compactMap { $0 as? String }
            return (strings.first ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let first = toText(value).split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        return first.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseProduct(barcode: String, raw: [String: Any]) -> LookupResult {
        let n = raw["nutriments"] as? [String: Any] ?? [:]

        let kcal: Double?
        if let direct = toNumber(n["energy-kcal_100g"]) {
            kcal = direct
        } else if let kj = toNumber(n["energy-kj_100g"]) ?? toNumber(n["energy_100g"]) {
            kcal = kj / kjPerKcal
        } else {
            kcal = nil
        }
        let protein = toNumber(n["proteins_100g"])
        let carbs = toNumber(n["carbohydrates_100g"])
        let fat = toNumber(n["fat_100g"])

        let unit = toText(raw["product_quantity_unit"]).lowercased()
        let quantity = toNumber(raw["product_quantity"])
        var servingSizeG: Double? = nil
        if let quantity, quantity > 0, unit == "" || unit == "g" || unit == "ml" {
            servingSizeG = quantity
        }

        let imageText = toText(raw["image_front_small_url"])
        let germanName = toText(raw["product_name_de"])
        let partial = PartialProduct(
            barcode: barcode,
            name: germanName.isEmpty ? toText(raw["product_name"]) : germanName,
            brand: firstBrand(raw["brands"]),
            servingSizeG: servingSizeG,
            imageUrl: imageText.isEmpty ? nil : imageText
        )

        guard let kcal, let protein, let carbs, let fat else {
            return .incomplete(partial)
        }

        return .found(ProductData(
            barcode: barcode,
            name: partial.name.isEmpty ? "Unbenanntes Produkt" : partial.name,
            brand: partial.brand,
            caloriesPer100g: NumberFormat.jsRound(kcal),
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat,
            servingSizeG: servingSizeG,
            imageUrl: partial.imageUrl
        ))
    }

    /// Maskiert Lucene-Sonderzeichen, damit Eingaben wie „Milch (3,5 %)“ keine Syntaxfehler auslösen.
    static func escapeLuceneQuery(_ query: String) -> String {
        let collapsed = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        let special: Set<Character> = ["+", "-", "!", "(", ")", "{", "}", "[", "]", "^", "\"", "~", "*", "?", ":", "\\", "/", "&", "|"]
        var result = ""
        for char in collapsed {
            if special.contains(char) { result.append("\\") }
            result.append(char)
        }
        return result
    }

    static func searchURL(query: String, page: Int, germanyOnly: Bool, pageSize: Int = searchPageSize) -> URL {
        let text = escapeLuceneQuery(query)
        // Deutsche Produkte bevorzugen: zuerst mit Länderfilter, bei null Treffern weltweit.
        let q = germanyOnly ? "\(text) countries_tags:\"en:germany\"" : text
        var components = URLComponents(string: searchBase)!
        components.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "langs", value: "de,en"),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "fields", value: searchFields.joined(separator: ",")),
        ]
        return components.url!
    }

    /// Wandelt eine Search-a-licious-Antwort um. Treffer ohne gültigen Barcode entfallen.
    static func parseSearchResults(_ json: Any) -> SearchPage {
        let data = json as? [String: Any] ?? [:]
        let rawHits = data["hits"] as? [Any] ?? []
        var seen = Set<String>()
        var hits: [SearchHit] = []

        for raw in rawHits {
            guard let product = raw as? [String: Any] else { continue }
            guard let barcode = Barcode.normalize(toText(product["code"])), !seen.contains(barcode) else { continue }
            seen.insert(barcode)
            switch parseProduct(barcode: barcode, raw: product) {
            case .found(let p): hits.append(.found(p))
            case .incomplete(let p): hits.append(.incomplete(p))
            default: break
            }
        }

        return SearchPage(
            hits: hits,
            count: Int(toNumber(data["count"]) ?? Double(hits.count)),
            page: Int(toNumber(data["page"]) ?? 1),
            pageCount: Int(toNumber(data["page_count"]) ?? 1)
        )
    }

    static func parseRetryAfter(_ value: String?) -> Int? {
        guard let value, let seconds = Double(value.trimmingCharacters(in: .whitespaces)), seconds.isFinite, seconds >= 0 else { return nil }
        return Int(seconds.rounded(.up))
    }
}

/// Die Netzwerkseite: eine Instanz pro App mit festem User-Agent.
final class OpenFoodFactsClient {
    let userAgent: String
    private let session: URLSession

    init(userAgent: String, session: URLSession = .shared) {
        self.userAgent = userAgent
        self.session = session
    }

    private func request(_ url: URL, timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    func fetchProduct(barcode: String) async -> LookupResult {
        let fields = OpenFoodFacts.fields.joined(separator: ",")
        let encoded = barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? barcode
        guard let url = URL(string: "\(OpenFoodFacts.apiBase)/\(encoded).json?fields=\(fields)") else { return .error }
        do {
            let (data, response) = try await session.data(for: request(url, timeout: OpenFoodFacts.timeoutSeconds))
            guard let http = response as? HTTPURLResponse else { return .error }
            // Unbekannte Codes beantwortet die API mit 404 und status 0.
            if http.statusCode == 404 { return .notFound }
            guard (200..<300).contains(http.statusCode) else { return .error }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .error }
            guard OpenFoodFacts.toNumber(json["status"]) == 1, let product = json["product"] as? [String: Any] else { return .notFound }
            return OpenFoodFacts.parseProduct(barcode: barcode, raw: product)
        } catch {
            return .error
        }
    }

    private func requestSearchPage(_ url: URL) async -> SearchResult {
        do {
            let (data, response) = try await session.data(for: request(url, timeout: OpenFoodFacts.searchTimeoutSeconds))
            guard let http = response as? HTTPURLResponse else { return .unavailable }
            if http.statusCode == 429 {
                return .rateLimited(retryAfterSeconds: OpenFoodFacts.parseRetryAfter(http.value(forHTTPHeaderField: "Retry-After")))
            }
            guard (200..<300).contains(http.statusCode) else { return .unavailable }
            let json = try JSONSerialization.jsonObject(with: data)
            // Fehler der Suchmaschine kommen mit Status 200 und einem errors-Feld.
            if let dict = json as? [String: Any], dict["errors"] != nil, dict["hits"] == nil { return .unavailable }
            return .ok(OpenFoodFacts.parseSearchResults(json))
        } catch let error as URLError where error.code == .timedOut {
            return .timeout
        } catch {
            return .offline
        }
    }

    /// Sucht bei Open Food Facts. Bevorzugt Produkte aus Deutschland: Auf Seite 1 ohne Treffer wird einmal
    /// weltweit gesucht. `acquire` prüft das Rate Limit vor jeder einzelnen Anfrage.
    func searchProducts(query: String, page: Int, scope: SearchScope, acquire: () -> RateLimitDecision) async -> (result: SearchResult, scope: SearchScope) {
        func run(_ scope: SearchScope) async -> SearchResult {
            switch acquire() {
            case .ok:
                return await requestSearchPage(OpenFoodFacts.searchURL(query: query, page: page, germanyOnly: scope == .germany))
            case .limited(let seconds):
                return .rateLimited(retryAfterSeconds: Int(seconds.rounded(.up)))
            }
        }

        let first = await run(scope)
        if scope == .germany, page == 1, case .ok(let firstPage) = first, firstPage.hits.isEmpty {
            return (await run(.world), .world)
        }
        return (first, scope)
    }
}
