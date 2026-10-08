import SwiftUI
import UIKit
import WidgetKit

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: TodaySnapshot?
}

/// Liest nur die Datei, die die App nach jeder Änderung in den App-Group-Ordner schreibt.
struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), snapshot: TodaySnapshot.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: Date(), snapshot: context.isPreview ? TodaySnapshot.sample : current()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = TodayEntry(date: Date(), snapshot: current())
        // Nach Mitternacht beginnt ein neuer Tag mit 0 kcal.
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }

    private func current() -> TodaySnapshot? {
        guard let stored = TodaySnapshot.load() else { return nil }
        let todayKey = TodaySnapshot.todayKey()
        if stored.dateKey == todayKey { return stored }
        // Der gespeicherte Stand ist von gestern: Ziel behalten, Verzehr auf 0.
        return TodaySnapshot(
            dateKey: todayKey, consumed: .zero, goalCalories: stored.goalCalories,
            goalProtein: stored.goalProtein, goalCarbs: stored.goalCarbs, goalFat: stored.goalFat,
            entryCount: 0, updatedAt: Date()
        )
    }
}

struct TodayWidget: Widget {
    let kind = "HachibuToday"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("Kalorien heute")
        .description("Übrige Kalorien und Makros des Tages. Tippen öffnet den Scanner.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private var snapshot: TodaySnapshot? { entry.snapshot }
    private var goal: Double { Double(snapshot?.goalCalories ?? 0) }
    private var consumed: Double { snapshot?.consumed.calories ?? 0 }
    private var remaining: Int { snapshot?.remainingCalories ?? 0 }
    private var progress: Double { goal > 0 ? min(max(consumed / goal, 0), 1) : 0 }

    var body: some View {
        Group {
            if snapshot == nil {
                noProfile
            } else {
                switch family {
                case .systemMedium: medium
                case .accessoryCircular: circular
                case .accessoryRectangular: rectangular
                case .accessoryInline: inline
                default: small
                }
            }
        }
        .widgetURL(URL(string: "hachibu://scan"))
    }

    private var noProfile: some View {
        VStack(spacing: 6) {
            Image(systemName: "barcode.viewfinder").font(.title2)
            Text("Hachibu öffnen").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var small: some View {
        VStack(spacing: 4) {
            CalorieRing(consumed: consumed, goal: goal, lineWidth: 10, compact: true)
            Text("\(snapshot?.entryCount ?? 0) Einträge")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            CalorieRing(consumed: consumed, goal: goal, lineWidth: 10, compact: true)
                .frame(width: 110, height: 110)
            VStack(alignment: .leading, spacing: 8) {
                macroLine("Protein", snapshot?.consumed.protein ?? 0, snapshot?.goalProtein ?? 0, Theme.protein)
                macroLine("Kohlenh.", snapshot?.consumed.carbs ?? 0, snapshot?.goalCarbs ?? 0, Theme.carbs)
                macroLine("Fett", snapshot?.consumed.fat ?? 0, snapshot?.goalFat ?? 0, Theme.fat)
                Label("Scannen", systemImage: "barcode.viewfinder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
    }

    private func macroLine(_ label: String, _ value: Double, _ target: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption2.weight(.semibold))
                Spacer()
                Text("\(NumberFormat.int(value)) / \(target) g").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(color).frame(width: geo.size.width * (target > 0 ? min(value / Double(target), 1) : 0))
                }
            }
            .frame(height: 5)
        }
    }

    private var circular: some View {
        Gauge(value: progress) {
            Image(systemName: "fork.knife")
        } currentValueLabel: {
            Text(NumberFormat.int(Double(abs(remaining))))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(remaining >= 0 ? "\(NumberFormat.int(Double(remaining))) kcal übrig" : "\(NumberFormat.int(Double(-remaining))) kcal drüber")
                .font(.headline)
            Text("\(NumberFormat.int(consumed)) von \(NumberFormat.int(goal)) kcal")
                .font(.caption)
            Gauge(value: progress) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
        }
    }

    private var inline: some View {
        Text(remaining >= 0 ? "Hachibu: \(NumberFormat.int(Double(remaining))) kcal übrig" : "Hachibu: \(NumberFormat.int(Double(-remaining))) kcal drüber")
    }
}
