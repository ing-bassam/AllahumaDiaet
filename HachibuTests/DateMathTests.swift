import Foundation
import Testing
@testable import Hachibu

@Suite struct DateMathTests {
    let cal = TestCalendar.berlin

    @Test func schluesselLesen() {
        #expect(DateMath.parseDateKey("2026-09-16", calendar: cal) == TestCalendar.date(2026, 9, 16))
        #expect(DateMath.parseDateKey("2026-02-31", calendar: cal) == nil)
        #expect(DateMath.parseDateKey("16.09.2026", calendar: cal) == nil)
        #expect(DateMath.parseDateKey("", calendar: cal) == nil)
    }

    @Test func tageAddierenUeberSommerzeit() {
        // 29. März 2026: Umstellung auf Sommerzeit in Berlin.
        let before = TestCalendar.date(2026, 3, 28)
        #expect(DateMath.addDays(before, 1, calendar: cal) == TestCalendar.date(2026, 3, 29))
        #expect(DateMath.addDays(before, 2, calendar: cal) == TestCalendar.date(2026, 3, 30))
        #expect(DateMath.addDays(TestCalendar.date(2026, 3, 30, 15), -1, calendar: cal) == TestCalendar.date(2026, 3, 29))
        #expect(Formatting.dateKey(DateMath.addDays(TestCalendar.date(2026, 10, 25), 1, calendar: cal), calendar: cal) == "2026-10-26")
    }

    @Test func monatsrechnung() {
        #expect(DateMath.addMonths(TestCalendar.date(2026, 1, 31), 1, calendar: cal) == TestCalendar.date(2026, 2, 1))
        #expect(DateMath.startOfMonth(TestCalendar.date(2026, 9, 16), calendar: cal) == TestCalendar.date(2026, 9, 1))
        #expect(DateMath.endOfMonth(TestCalendar.date(2026, 2, 10), calendar: cal) == TestCalendar.date(2026, 2, 28))
    }

    @Test func titelUndDatumszeile() {
        let today = TestCalendar.date(2026, 9, 16)
        #expect(DateMath.dayTitle(today, today: today, calendar: cal) == "Heute")
        #expect(DateMath.dayTitle(TestCalendar.date(2026, 9, 15), today: today, calendar: cal) == "Gestern")
        #expect(DateMath.dayTitle(TestCalendar.date(2026, 9, 17), today: today, calendar: cal) == "Morgen")
        #expect(DateMath.dayTitle(TestCalendar.date(2026, 9, 14), today: today, calendar: cal) == "Montag")
        #expect(DateMath.dayDateLine(today, today: today, calendar: cal) == "16. September")
        #expect(DateMath.dayDateLine(TestCalendar.date(2025, 12, 31), today: today, calendar: cal) == "31. Dezember 2025")
        #expect(DateMath.fullDateLabel(today, calendar: cal) == "16. September 2026")
        #expect(DateMath.monthLabel(today, calendar: cal) == "September 2026")
    }

    @Test func tagMitUhrzeitKombinieren() {
        let day = TestCalendar.date(2026, 9, 10)
        let time = TestCalendar.date(2026, 9, 16, 13, 45)
        #expect(DateMath.combine(day: day, time: time, calendar: cal) == TestCalendar.date(2026, 9, 10, 13, 45))
    }

    @Test func monatsraster() {
        // September 2026 beginnt an einem Dienstag.
        let weeks = DateMath.monthMatrix(TestCalendar.date(2026, 9, 1), calendar: cal)
        #expect(weeks.count == 5)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(weeks[0][0] == nil)
        #expect(weeks[0][1] == TestCalendar.date(2026, 9, 1))
        #expect(weeks[4][2] == TestCalendar.date(2026, 9, 30))
        #expect(weeks[4][3] == nil)
        #expect(DateMath.mondayIndex(TestCalendar.date(2026, 9, 14), calendar: cal) == 0)
        #expect(DateMath.mondayIndex(TestCalendar.date(2026, 9, 13), calendar: cal) == 6)
        // Februar 2027 beginnt an einem Montag und hat genau vier Wochen.
        #expect(DateMath.monthMatrix(TestCalendar.date(2027, 2, 1), calendar: cal).count == 4)
    }
}
