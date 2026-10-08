import Foundation
import Testing
@testable import Hachibu

/// Fester Kalender, damit die Tests in jeder Zeitzone dasselbe Ergebnis liefern.
enum TestCalendar {
    static let berlin: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.locale = Locale(identifier: "de_DE")
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        c.hour = hour
        c.minute = minute
        return berlin.date(from: c)!
    }

    /// Tagesbeginn in der Zeitzone des Test-Rechners – für Funktionen, die mit `Calendar.current` rechnen.
    static func localDay(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        return Calendar.current.date(from: c)!
    }
}

@Suite struct FormattingTests {
    @Test func zahlenDeutsch() {
        #expect(NumberFormat.int(2150) == "2.150")
        #expect(NumberFormat.int(980) == "980")
        #expect(NumberFormat.int(-1234567) == "-1.234.567")
        #expect(NumberFormat.decimal(12.54) == "12,5")
        #expect(NumberFormat.decimal(12) == "12")
        #expect(NumberFormat.decimal(1234.5) == "1.234,5")
        #expect(NumberFormat.decimal(-1234.5) == "-1.234,5")
        #expect(NumberFormat.decimal(999.96) == "1.000")
    }

    @Test func eingabenLesen() {
        #expect(Formatting.parseDecimal("12,5") == 12.5)
        #expect(Formatting.parseDecimal("12.5") == 12.5)
        #expect(Formatting.parseDecimal(" 7 ") == 7)
        #expect(Formatting.parseDecimal("") == nil)
        #expect(Formatting.parseDecimal(",") == nil)
        #expect(Formatting.parseDecimal("abc") == nil)
        #expect(Formatting.parseDecimal("1,2,3") == nil)
        #expect(Formatting.parseDecimal("1.000") == 1)
    }

    @Test func eingabeText() {
        #expect(Formatting.inputText(12.5) == "12,5")
        #expect(Formatting.inputText(12) == "12")
        #expect(Formatting.inputText(1000) == "1000")
        #expect(Formatting.inputText(0.06) == "0,1")
    }

    @Test func datumsschluesselLokal() {
        #expect(Formatting.dateKey(TestCalendar.date(2026, 9, 16, 0, 30), calendar: TestCalendar.berlin) == "2026-09-16")
        #expect(Formatting.dateKey(TestCalendar.date(2026, 1, 1, 23, 59), calendar: TestCalendar.berlin) == "2026-01-01")
    }

    @Test func zeitstempelHinUndZurueck() {
        let date = TestCalendar.date(2026, 9, 14, 7, 0)
        let text = Formatting.isoTimestamp(date)
        #expect(text == "2026-09-14T05:00:00.000Z")
        #expect(Formatting.parseIsoTimestamp(text) == date)
        #expect(Formatting.parseIsoTimestamp("2026-09-14T05:00:00Z") == date)
        #expect(Formatting.time(text, calendar: TestCalendar.berlin) == "07:00")
    }

    @Test func mahlzeitNachUhrzeit() {
        #expect(MealType.suggested(for: TestCalendar.date(2026, 9, 14, 7), calendar: TestCalendar.berlin) == .breakfast)
        #expect(MealType.suggested(for: TestCalendar.date(2026, 9, 14, 12), calendar: TestCalendar.berlin) == .lunch)
        #expect(MealType.suggested(for: TestCalendar.date(2026, 9, 14, 16), calendar: TestCalendar.berlin) == .snack)
        #expect(MealType.suggested(for: TestCalendar.date(2026, 9, 14, 19), calendar: TestCalendar.berlin) == .dinner)
        #expect(MealType.suggested(for: TestCalendar.date(2026, 9, 14, 23), calendar: TestCalendar.berlin) == .snack)
    }
}
