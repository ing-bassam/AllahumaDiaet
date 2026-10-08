import Foundation
import Testing
@testable import Hachibu

@Suite struct OpenFoodFactsTests {
    @Test func userAgent() {
        #expect(OpenFoodFacts.userAgent(appName: "AllahumaDiaet", appVersion: "2.0.0", contactEmail: "kontakt@example.com") == "AllahumaDiaet/2.0.0 (kontakt@example.com)")
    }

    @Test func vollstaendigesProdukt() {
        let raw: [String: Any] = [
            "product_name": "Skyr",
            "product_name_de": "Skyr natur",
            "brands": "Milsani, Aldi",
            "product_quantity": "500",
            "product_quantity_unit": "g",
            "image_front_small_url": "https://images.openfoodfacts.org/x.jpg",
            "nutriments": ["energy-kcal_100g": 63.4, "proteins_100g": "11", "carbohydrates_100g": 4, "fat_100g": 0.2],
        ]
        guard case .found(let product) = OpenFoodFacts.parseProduct(barcode: "4006381333931", raw: raw) else {
            Issue.record("Produkt sollte vollständig sein")
            return
        }
        #expect(product.name == "Skyr natur")
        #expect(product.brand == "Milsani")
        #expect(product.caloriesPer100g == 63)
        #expect(product.proteinPer100g == 11)
        #expect(product.servingSizeG == 500)
        #expect(product.imageUrl == "https://images.openfoodfacts.org/x.jpg")
    }

    @Test func kilojouleAlsRueckfall() {
        let raw: [String: Any] = ["nutriments": ["energy-kj_100g": 418.4, "proteins_100g": 1, "carbohydrates_100g": 1, "fat_100g": 1]]
        guard case .found(let product) = OpenFoodFacts.parseProduct(barcode: "96385074", raw: raw) else {
            Issue.record("Produkt sollte vollständig sein")
            return
        }
        #expect(product.caloriesPer100g == 100)
        #expect(product.name == "Unbenanntes Produkt")
    }

    @Test func unvollstaendigesProdukt() {
        let raw: [String: Any] = ["product_name": "Nüsse", "brands": ["Marke A", "Marke B"], "product_quantity": 200, "product_quantity_unit": "ml", "nutriments": ["proteins_100g": 20]]
        guard case .incomplete(let partial) = OpenFoodFacts.parseProduct(barcode: "96385074", raw: raw) else {
            Issue.record("Produkt sollte unvollständig sein")
            return
        }
        #expect(partial.name == "Nüsse")
        #expect(partial.brand == "Marke A")
        #expect(partial.servingSizeG == 200)
    }

    @Test func packungsgroesseNurInGrammOderMilliliter() {
        let raw: [String: Any] = ["product_quantity": 6, "product_quantity_unit": "stk", "nutriments": [String: Any]()]
        guard case .incomplete(let partial) = OpenFoodFacts.parseProduct(barcode: "96385074", raw: raw) else { return }
        #expect(partial.servingSizeG == nil)
    }

    @Test func luceneSonderzeichen() {
        #expect(OpenFoodFacts.escapeLuceneQuery("Milch (3,5 %)") == "Milch \\(3,5 %\\)")
        #expect(OpenFoodFacts.escapeLuceneQuery("  Haferflocken   kernig ") == "Haferflocken kernig")
    }

    @Test func suchAdresse() {
        let url = OpenFoodFacts.searchURL(query: "Skyr", page: 2, germanyOnly: true)
        let text = url.absoluteString
        #expect(text.hasPrefix("https://search.openfoodfacts.org/search?"))
        #expect(text.contains("countries_tags"))
        #expect(text.contains("page=2"))
        #expect(text.contains("page_size=20"))
        #expect(text.contains("langs=de,en"))
        let world = OpenFoodFacts.searchURL(query: "Skyr", page: 1, germanyOnly: false).absoluteString
        #expect(!world.contains("countries_tags"))
    }

    @Test func suchergebnisseParsen() {
        let nutriments: [String: Any] = ["energy-kcal_100g": 63, "proteins_100g": 11, "carbohydrates_100g": 4, "fat_100g": 0.2]
        let hits: [[String: Any]] = [
            ["code": "4006381333931", "product_name": "Skyr", "nutriments": nutriments],
            ["code": "4006381333931", "product_name": "Doppelt"],
            ["code": "123", "product_name": "Ungültiger Code"],
            ["code": "96385074", "product_name": "Ohne Nährwerte"],
        ]
        let json: [String: Any] = ["count": 3, "page": 1, "page_count": 1, "hits": hits]
        let page = OpenFoodFacts.parseSearchResults(json)
        #expect(page.hits.count == 2)
        #expect(page.hits.map { $0.key } == ["4006381333931", "96385074"])
        if case .incomplete(let partial) = page.hits[1] {
            #expect(partial.name == "Ohne Nährwerte")
        } else {
            Issue.record("zweiter Treffer sollte unvollständig sein")
        }
        #expect(page.count == 3)
    }

    @Test func retryAfter() {
        #expect(OpenFoodFacts.parseRetryAfter("30") == 30)
        #expect(OpenFoodFacts.parseRetryAfter("2.2") == 3)
        #expect(OpenFoodFacts.parseRetryAfter(nil) == nil)
        #expect(OpenFoodFacts.parseRetryAfter("bald") == nil)
    }
}
