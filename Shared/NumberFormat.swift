import Foundation

/// Zahlen in deutscher Schreibweise: Tausenderpunkt, Dezimalkomma.
enum NumberFormat {
    /// Rundet wie JavaScript (0,5 immer auf), damit Werte zur bisherigen App passen.
    static func jsRound(_ value: Double) -> Double {
        (value + 0.5).rounded(.down)
    }

    /// Ganze Zahl mit Tausenderpunkt, z. B. 2.150
    static func int(_ value: Double) -> String {
        let rounded = Int(jsRound(value))
        let digits = groupThousands(String(abs(rounded)))
        return rounded < 0 ? "-" + digits : digits
    }

    /// Höchstens eine Nachkommastelle mit Komma, z. B. 12,5 oder 12 oder 1.234,5
    static func decimal(_ value: Double) -> String {
        let rounded = jsRound(value * 10) / 10
        if rounded == rounded.rounded(.towardZero) {
            return int(rounded)
        }
        let text = String(format: "%.1f", rounded)
        let negative = text.hasPrefix("-")
        let body = negative ? String(text.dropFirst()) : text
        let parts = body.split(separator: ".", maxSplits: 1).map(String.init)
        let whole = groupThousands(parts[0])
        let fraction = parts.count > 1 ? parts[1] : "0"
        return (negative ? "-" : "") + whole + "," + fraction
    }

    static func groupThousands(_ digits: String) -> String {
        var result = ""
        for (index, char) in digits.reversed().enumerated() {
            if index > 0 && index % 3 == 0 { result.append(".") }
            result.append(char)
        }
        return String(result.reversed())
    }
}
