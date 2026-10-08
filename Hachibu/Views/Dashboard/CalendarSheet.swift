import SwiftUI

/// Monatskalender zum Springen auf einen Tag; Tage mit Einträgen sind markiert.
struct CalendarSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var month: Date = Date()
    @State private var markedDates: Set<String> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Button {
                        changeMonth(-1)
                    } label: {
                        Image(systemName: "chevron.left").padding(8)
                    }
                    .accessibilityLabel("Vorheriger Monat")
                    Spacer()
                    Text(DateMath.monthLabel(month))
                        .font(.headline)
                    Spacer()
                    Button {
                        changeMonth(1)
                    } label: {
                        Image(systemName: "chevron.right").padding(8)
                    }
                    .accessibilityLabel("Nächster Monat")
                }

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(DateMath.weekdayLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(DateMath.monthMatrix(month).enumerated()), id: \.offset) { _, week in
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            if let day {
                                dayCell(day)
                            } else {
                                Color.clear.frame(height: 40)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Kalender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Heute") {
                        model.goToToday()
                        dismiss()
                    }
                }
            }
            .onAppear {
                month = DateMath.startOfMonth(model.selectedDay)
                loadMarks()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func dayCell(_ day: Date) -> some View {
        let key = Formatting.dateKey(day)
        let isSelected = DateMath.isSameDay(day, model.selectedDay)
        let isToday = DateMath.isSameDay(day, model.today)
        let isFuture = day > model.today
        return Button {
            model.select(day: day)
            dismiss()
        } label: {
            VStack(spacing: 2) {
                Text("\(DateMath.day(day))")
                    .font(.body.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color(.systemBackground) : (isFuture ? Color.secondary : Color.primary))
                Circle()
                    .fill(markedDates.contains(key) ? (isSelected ? Color(.systemBackground) : Theme.primary) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(isSelected ? Theme.primary : (isToday ? Theme.primary.opacity(0.12) : Color.clear), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(DateMath.fullDateLabel(day) + (markedDates.contains(key) ? ", mit Einträgen" : ""))
    }

    private func changeMonth(_ delta: Int) {
        month = DateMath.addMonths(month, delta)
        loadMarks()
    }

    private func loadMarks() {
        let from = Formatting.dateKey(DateMath.startOfMonth(month))
        let to = Formatting.dateKey(DateMath.endOfMonth(month))
        markedDates = Set((try? model.repo.datesWithEntries(from: from, to: to)) ?? [])
    }
}
