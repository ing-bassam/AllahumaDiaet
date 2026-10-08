import SwiftUI
import UIKit

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

extension View {
    /// „Fertig“-Taste über der Zahlentastatur, die selbst keine Eingabetaste hat. Nur einmal je Screen anhängen.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}

/// Ersetzt einen Ladezustand, der sonst nach einem Fehler endlos stehen bliebe.
struct LoadErrorView: View {
    var title = "Daten konnten nicht geladen werden"
    var message: String? = nil
    var onRetry: () -> Void
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Bitte versuche es erneut. Hilft das nicht, starte die App neu. Tritt der Fehler weiter auf, schreib an \(AppInfo.contactEmail).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let message, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            Button("Erneut versuchen", action: onRetry)
                .buttonStyle(.borderedProminent)
            if let onClose {
                Button("Schließen", action: onClose)
                    .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

/// Beschriftetes Eingabefeld mit Einheit und Fehlertext; standardmäßig mit Zahlentastatur.
struct LabeledInput: View {
    var label: String
    var unit: String? = nil
    @Binding var text: String
    var keyboard: UIKeyboardType = .decimalPad
    var error: String? = nil
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            HStack {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .font(.body)
                    .accessibilityLabel(label)
                if let unit {
                    Text(unit)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(error == nil ? Color.primary.opacity(0.08) : Theme.danger, lineWidth: 1)
            )
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.danger)
            }
        }
    }
}

/// Auswahlknopf in Kapselform.
struct Chip: View {
    var label: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(selected ? Color.primary : Color(.secondarySystemGroupedBackground), in: Capsule())
                .foregroundStyle(selected ? Color(.systemBackground) : Color.primary)
                .overlay(Capsule().stroke(Color.primary.opacity(selected ? 0 : 0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Mehrere Chips, die bei Platzmangel umbrechen.
struct ChipRow<Item: Identifiable, Content: View>: View {
    var items: [Item]
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}

/// Einfaches Umbruch-Layout für Chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct MacroBar: View {
    var label: String
    var consumed: Double
    var goal: Int
    var color: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(consumed / Double(goal), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Text("\(NumberFormat.int(consumed)) / \(goal) g")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(color).frame(width: max(geo.size.width * progress, progress > 0 ? 6 : 0))
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(NumberFormat.int(consumed)) von \(goal) Gramm")
    }
}

/// Weiße Karte mit abgerundeten Ecken, für Inhalte außerhalb von Listen.
struct SectionCard<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Produktbild aus Open Food Facts oder ein Platzhalter.
struct FoodThumbnail: View {
    var imageUrl: String?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholder: some View {
        Image(systemName: "fork.knife")
            .foregroundStyle(.secondary)
    }
}
