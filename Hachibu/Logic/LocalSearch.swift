import Foundation

protocol NamedFood {
    var name: String { get }
    var brand: String { get }
}

/// Suche im lokalen Lebensmittelkatalog. SQLite vergleicht Groß-/Kleinschreibung nur für ASCII,
/// daher filtert die Datenbank grob vor und diese Funktionen entscheiden exakt und sortieren.
enum LocalSearch {
    static let minQueryLength = 2

    private static let wordSeparators = CharacterSet(charactersIn: " \t\n\r-_,.;:/()&+'\"!?")
    private static let locale = Locale(identifier: "de_DE")

    static func normalize(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .lowercased(with: locale)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// LIKE-Muster für die Vorauswahl: Sonderzeichen escaped (ESCAPE '\'), Nicht-ASCII durch `_` ersetzt,
    /// damit z. B. „Äpfel“ auch „äpfel“ findet.
    static func toLikePattern(_ query: String) -> String {
        var escaped = ""
        for char in query.trimmingCharacters(in: .whitespacesAndNewlines) {
            if char == "\\" || char == "%" || char == "_" {
                escaped.append("\\")
                escaped.append(char)
            } else if char.unicodeScalars.allSatisfy({ $0.isASCII }) {
                escaped.append(char)
            } else {
                escaped.append("_")
            }
        }
        return "%" + escaped + "%"
    }

    private static func words(_ text: String) -> [String] {
        text.components(separatedBy: wordSeparators).filter { !$0.isEmpty }
    }

    /// Rang eines Treffers, kleiner ist besser; `nil` = kein Treffer.
    /// 0: Name beginnt mit der Suche · 1: ein Wort im Namen beginnt damit · 2: Name enthält sie
    /// 3: ein Wort der Marke beginnt damit · 4: Marke enthält sie
    static func matchRank(name: String, brand: String, query: String) -> Int? {
        let q = normalize(query)
        if q.isEmpty { return nil }
        let n = normalize(name)
        let b = normalize(brand)

        if n.hasPrefix(q) { return 0 }
        if words(n).contains(where: { $0.hasPrefix(q) }) { return 1 }
        if n.contains(q) { return 2 }
        if words(b).contains(where: { $0.hasPrefix(q) }) { return 3 }
        if b.contains(q) { return 4 }
        return nil
    }

    static func rank<T: NamedFood>(_ items: [T], query: String, limit: Int) -> [T] {
        let ranked: [(item: T, rank: Int)] = items.compactMap { item in
            guard let rank = matchRank(name: item.name, brand: item.brand, query: query) else { return nil }
            return (item, rank)
        }
        return ranked
            .sorted { a, b in
                if a.rank != b.rank { return a.rank < b.rank }
                return a.item.name.compare(b.item.name, locale: locale) == .orderedAscending
            }
            .prefix(limit)
            .map { $0.item }
    }
}
