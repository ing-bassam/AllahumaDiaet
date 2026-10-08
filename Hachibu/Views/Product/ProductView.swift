import SwiftUI

enum ProductOutcome {
    case saved(continueScanning: Bool)
    case cancelled
}

/// Produkt eintragen: lädt das Lebensmittel (lokal, aus der Online-Suche oder von Open Food Facts)
/// und zeigt dann das Mengenformular oder das manuelle Formular.
struct ProductView: View {
    let key: String
    var fromScanner = false
    /// Name für ein neues eigenes Lebensmittel (aus der Suche).
    var prefillName: String? = nil
    var onDone: (ProductOutcome) -> Void

    @EnvironmentObject private var model: AppModel

    enum ManualReason {
        case notFound, incomplete, error, custom
    }

    enum LoadPhase: Equatable {
        case loading
        case ready(FoodItem, persisted: Bool)
        case manual(ManualReason, PartialProduct?)

        static func == (lhs: LoadPhase, rhs: LoadPhase) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): return true
            case (.ready(let a, let pa), .ready(let b, let pb)): return a == b && pa == pb
            case (.manual(let ra, let pa), .manual(let rb, let pb)): return ra == rb && pa == pb
            default: return false
            }
        }
    }

    @State private var phase: LoadPhase = .loading

    var body: some View {
        Group {
            switch phase {
            case .loading:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Produkt wird gesucht …")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            case .ready(let food, let persisted):
                PortionForm(food: food, persisted: persisted, fromScanner: fromScanner, onDone: onDone)
            case .manual(let reason, let partial):
                ManualEntryForm(key: key, reason: reason, partial: partial, prefillName: prefillName, onRetry: { Task { await load() } }) { food in
                    phase = .ready(food, persisted: true)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { onDone(.cancelled) }
            }
        }
        .task(id: key) { await load() }
    }

    private func load() async {
        phase = .loading
        if let local = try? model.repo.foodItem(key: key) {
            phase = .ready(local, persisted: true)
            return
        }
        if FoodKey.isCustom(key) {
            phase = .manual(.custom, nil)
            return
        }
        if let hit = model.searchHit(for: key) {
            switch hit {
            case .found(let product):
                phase = .ready(FoodItem(product: product), persisted: false)
            case .incomplete(let partial):
                phase = .manual(.incomplete, partial)
            }
            return
        }
        let result = await model.client.fetchProduct(barcode: key)
        switch result {
        case .found(let product):
            phase = .ready(FoodItem(product: product), persisted: false)
        case .incomplete(let partial):
            phase = .manual(.incomplete, partial)
        case .notFound:
            phase = .manual(.notFound, nil)
        case .error:
            phase = .manual(.error, nil)
        }
    }
}

extension FoodItem {
    init(product: ProductData) {
        self.init(
            barcode: product.barcode, name: product.name, brand: product.brand, per100g: product.per100g,
            servingSizeG: product.servingSizeG, imageUrl: product.imageUrl, source: .openfoodfacts, userEdited: false, favorite: false
        )
    }

    var asProductData: ProductData {
        ProductData(
            barcode: barcode, name: name, brand: brand, caloriesPer100g: per100g.calories, proteinPer100g: per100g.protein,
            carbsPer100g: per100g.carbs, fatPer100g: per100g.fat, servingSizeG: servingSizeG, imageUrl: imageUrl
        )
    }
}
