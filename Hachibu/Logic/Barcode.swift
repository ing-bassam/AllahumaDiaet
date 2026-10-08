import Foundation

/// Wandelt gescannte oder eingetippte Codes in eine einheitliche GTIN um,
/// damit derselbe Artikel lokal immer unter demselben Schlüssel liegt.
enum Barcode {
    private static let gtinLengths: Set<Int> = [8, 12, 13, 14]

    static func isDigits(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.isASCII && $0.isNumber }
    }

    static func hasValidCheckDigit(_ code: String) -> Bool {
        guard isDigits(code), gtinLengths.contains(code.count) else { return false }
        var digits = code.compactMap { Int(String($0)) }
        let check = digits.removeLast()
        // Von rechts gewichtet: 3, 1, 3, 1, ...
        var sum = 0
        for (index, digit) in digits.reversed().enumerated() {
            sum += digit * (index % 2 == 0 ? 3 : 1)
        }
        return (10 - (sum % 10)) % 10 == check
    }

    static func canonicalGtin(_ code: String) -> String {
        // UPC-A (12) und GTIN-14 mit führender Null auf EAN-13 bringen.
        if code.count == 12 { return "0" + code }
        if code.count == 14 && code.hasPrefix("0") { return String(code.dropFirst()) }
        return code
    }

    /// Schreibt einen achtstelligen UPC-E zur zwölfstelligen UPC-A aus.
    /// Die Prüfziffer gilt für die ausgeschriebene Form, nicht für die acht Ziffern.
    static func expandUpcE(_ code: String) -> String? {
        guard code.count == 8, isDigits(code), code.first == "0" || code.first == "1" else { return nil }
        let c = Array(code)
        let system = String(c[0])
        let d1 = String(c[1])
        let d2 = String(c[2])
        let d3 = String(c[3])
        let d4 = String(c[4])
        let d5 = String(c[5])
        let d6 = String(c[6])
        let check = String(c[7])
        let body: String
        switch c[6] {
        case "0", "1", "2": body = d1 + d2 + d6 + "0000" + d3 + d4 + d5
        case "3": body = d1 + d2 + d3 + "00000" + d4 + d5
        case "4": body = d1 + d2 + d3 + d4 + "00000" + d5
        default: body = d1 + d2 + d3 + d4 + d5 + "0000" + d6
        }
        return system + body + check
    }

    /// Normalisierte GTIN oder `nil`, wenn der Inhalt kein Produktcode ist. Erkennt reine Ziffern
    /// und QR-Codes im GS1-Digital-Link-Format (z. B. https://id.gs1.org/01/04012345678901).
    /// `symbology` ist der vom Scanner gemeldete Typ: Ein UPC-E hat acht Ziffern wie eine EAN-8,
    /// wird aber anders geprüft.
    static func normalize(_ raw: String, symbology: String? = nil) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if symbology == "upc_e" {
            guard let upcA = expandUpcE(value), hasValidCheckDigit(upcA) else { return nil }
            return canonicalGtin(upcA)
        }

        if isDigits(value) {
            return hasValidCheckDigit(value) ? canonicalGtin(value) : nil
        }

        if let gtin = digitalLinkGtin(in: value), hasValidCheckDigit(gtin) {
            return canonicalGtin(gtin)
        }

        return nil
    }

    /// Sucht „/01/“ gefolgt von 14 Ziffern, danach Ende oder „/“, „?“, „#“.
    private static func digitalLinkGtin(in text: String) -> String? {
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: "/01/", range: searchRange) {
            let start = range.upperBound
            if let end = text.index(start, offsetBy: 14, limitedBy: text.endIndex) {
                let candidate = String(text[start..<end])
                let next: Character? = end < text.endIndex ? text[end] : nil
                if isDigits(candidate), next == nil || next == "/" || next == "?" || next == "#" {
                    return candidate
                }
            }
            searchRange = range.upperBound..<text.endIndex
        }
        return nil
    }
}
