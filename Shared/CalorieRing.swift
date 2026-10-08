import SwiftUI

/// Der Kalorienring: Fortschritt zum Tagesziel, in der App und im Widget.
struct CalorieRing: View {
    var consumed: Double
    var goal: Double
    var lineWidth: CGFloat = 16
    var showsLabels: Bool = true
    var compact: Bool = false

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(max(consumed / goal, 0), 1)
    }

    private var isOver: Bool { goal > 0 && consumed > goal }

    private var remaining: Double { goal - consumed }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isOver ? AnyShapeStyle(Theme.danger) : AnyShapeStyle(Theme.ringGradient),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            if showsLabels {
                VStack(spacing: compact ? 0 : 2) {
                    Text(NumberFormat.int(abs(remaining)))
                        .font(.system(size: compact ? 22 : 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isOver ? Theme.danger : Color.primary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(isOver ? "kcal drüber" : "kcal übrig")
                        .font(compact ? .caption2 : .subheadline)
                        .foregroundStyle(.secondary)
                    if !compact {
                        Text("\(NumberFormat.int(consumed)) / \(NumberFormat.int(goal))")
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(lineWidth)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isOver
                ? "\(NumberFormat.int(abs(remaining))) Kilokalorien über dem Tagesziel"
                : "\(NumberFormat.int(remaining)) Kilokalorien übrig von \(NumberFormat.int(goal))"
        )
    }
}
