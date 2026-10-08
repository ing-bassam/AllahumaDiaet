import Foundation

/// Datumsrechnung für die Tagesnavigation. Alles in lokaler Zeit über den Kalender, damit
/// Sommerzeitwechsel keinen Tag verschlucken.
enum DateMath {
    static let weekdays = ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"]
    static let months = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
    static let weekdayLabels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    /// Liest einen Schlüssel wie „2026-09-16“ als lokalen Tagesbeginn; `nil` bei ungültigem Text.
    static func parseDateKey(_ key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        // Fängt Werte wie 2026-02-31 ab, die der Kalender sonst still weiterrechnet.
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        return date
    }

    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Tage addieren oder abziehen; das Ergebnis ist immer der Tagesbeginn.
    static func addDays(_ date: Date, _ days: Int, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: days, to: start) ?? start
    }

    static func addMonths(_ date: Date, _ months: Int, calendar: Calendar = .current) -> Date {
        let first = startOfMonth(date, calendar: calendar)
        return calendar.date(byAdding: .month, value: months, to: first) ?? first
    }

    static func isSameDay(_ a: Date, _ b: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    static func startOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        let c = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: c) ?? calendar.startOfDay(for: date)
    }

    static func endOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        let next = addMonths(date, 1, calendar: calendar)
        return calendar.date(byAdding: .day, value: -1, to: next) ?? next
    }

    static func day(_ date: Date, calendar: Calendar = .current) -> Int { calendar.component(.day, from: date) }
    static func monthIndex(_ date: Date, calendar: Calendar = .current) -> Int { calendar.component(.month, from: date) - 1 }
    static func year(_ date: Date, calendar: Calendar = .current) -> Int { calendar.component(.year, from: date) }

    /// „Heute“, „Gestern“, „Morgen“, sonst der Wochentag.
    static func dayTitle(_ date: Date, today: Date, calendar: Calendar = .current) -> String {
        if isSameDay(date, today, calendar: calendar) { return "Heute" }
        if isSameDay(date, addDays(today, -1, calendar: calendar), calendar: calendar) { return "Gestern" }
        if isSameDay(date, addDays(today, 1, calendar: calendar), calendar: calendar) { return "Morgen" }
        return weekdays[calendar.component(.weekday, from: date) - 1]
    }

    /// „16. September“, in anderen Jahren mit Jahreszahl.
    static func dayDateLine(_ date: Date, today: Date, calendar: Calendar = .current) -> String {
        let base = "\(day(date, calendar: calendar)). \(months[monthIndex(date, calendar: calendar)])"
        if year(date, calendar: calendar) == year(today, calendar: calendar) { return base }
        return "\(base) \(year(date, calendar: calendar))"
    }

    static func fullDateLabel(_ date: Date, calendar: Calendar = .current) -> String {
        "\(day(date, calendar: calendar)). \(months[monthIndex(date, calendar: calendar)]) \(year(date, calendar: calendar))"
    }

    static func monthLabel(_ date: Date, calendar: Calendar = .current) -> String {
        "\(months[monthIndex(date, calendar: calendar)]) \(year(date, calendar: calendar))"
    }

    /// Datum des ausgewählten Tages mit der Uhrzeit von `time`.
    static func combine(day: Date, time: Date, calendar: Calendar = .current) -> Date {
        let d = calendar.dateComponents([.year, .month, .day], from: day)
        let t = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: time)
        var c = DateComponents()
        c.year = d.year
        c.month = d.month
        c.day = d.day
        c.hour = t.hour
        c.minute = t.minute
        c.second = t.second
        c.nanosecond = t.nanosecond
        return calendar.date(from: c) ?? day
    }

    /// Wochentag als Index mit Montag = 0.
    static func mondayIndex(_ date: Date, calendar: Calendar = .current) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    /// Wochenzeilen eines Monats: je 7 Einträge, `nil` für Tage des Vor- oder Folgemonats.
    static func monthMatrix(_ monthDate: Date, calendar: Calendar = .current) -> [[Date?]] {
        let first = startOfMonth(monthDate, calendar: calendar)
        let daysInMonth = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let leading = mondayIndex(first, calendar: calendar)

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for dayNumber in 1...daysInMonth {
            cells.append(calendar.date(byAdding: .day, value: dayNumber - 1, to: first))
        }
        while cells.count % 7 != 0 { cells.append(nil) }

        var weeks: [[Date?]] = []
        var index = 0
        while index < cells.count {
            weeks.append(Array(cells[index..<index + 7]))
            index += 7
        }
        return weeks
    }
}
