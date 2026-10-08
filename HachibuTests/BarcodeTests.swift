import Testing
@testable import Hachibu

@Suite struct BarcodeTests {
    @Test func pruefziffern() {
        #expect(Barcode.hasValidCheckDigit("4006381333931"))
        #expect(Barcode.hasValidCheckDigit("96385074"))
        #expect(!Barcode.hasValidCheckDigit("4006381333932"))
        #expect(!Barcode.hasValidCheckDigit("12345"))
        #expect(!Barcode.hasValidCheckDigit("40063813339ab"))
    }

    @Test func normalisierung() {
        #expect(Barcode.normalize(" 4006381333931 ") == "4006381333931")
        #expect(Barcode.normalize("036000291452") == "0036000291452")
        #expect(Barcode.normalize("04006381333931") == "4006381333931")
        #expect(Barcode.normalize("96385074") == "96385074")
        #expect(Barcode.normalize("96385074", symbology: "ean8") == "96385074")
        #expect(Barcode.normalize("4006381333932") == nil)
        #expect(Barcode.normalize("https://example.com/gewinnspiel") == nil)
    }

    @Test func gs1DigitalLink() {
        #expect(Barcode.normalize("https://id.gs1.org/01/04006381333931/10/ABC123") == "4006381333931")
        #expect(Barcode.normalize("https://example.com/01/04006381333931?x=1") == "4006381333931")
        #expect(Barcode.normalize("https://example.com/01/0400638133393") == nil)
    }

    @Test func upcEWirdAusgeschrieben() {
        #expect(Barcode.expandUpcE("04252614") == "042100005264")
        #expect(Barcode.expandUpcE("01234133") == "012300000413")
        #expect(Barcode.expandUpcE("01234145") == "012340000015")
        #expect(Barcode.expandUpcE("01234565") == "012345000065")
        #expect(Barcode.expandUpcE("425261") == nil)
        #expect(Barcode.expandUpcE("24252614") == nil)
    }

    @Test func upcEWirdNichtAlsEan8Geprueft() {
        // Als EAN-8 gelesen hätten die ersten beiden eine falsche Prüfziffer und würden abgewiesen.
        #expect(Barcode.normalize("04252614", symbology: "upc_e") == "0042100005264")
        #expect(Barcode.normalize("01201303", symbology: "upc_e") == "0012000000133")
        // Dieser ginge zufällig auch als EAN-8 durch, läge dann aber unter einem anderen Schlüssel.
        #expect(Barcode.normalize("04904403", symbology: "upc_e") == "0049000000443")
        #expect(Barcode.normalize("04252615", symbology: "upc_e") == nil)
    }

    @Test func lebensmittelSchluessel() {
        let key = FoodKey.newCustomKey()
        #expect(FoodKey.isCustom(key))
        #expect(FoodKey.isValid(key))
        #expect(FoodKey.isValid("4006381333931"))
        #expect(!FoodKey.isValid("036000291452"))
        #expect(!FoodKey.isCustom("custom:nicht-uuid"))
        #expect(FoodKey.parse(" 036000291452 ") == "0036000291452")
        #expect(FoodKey.parse("CUSTOM:3F2A9C1E-7B4D-4E8A-9F10-2C6D5E7A8B90") == "custom:3f2a9c1e-7b4d-4e8a-9f10-2c6d5e7a8b90")
        #expect(FoodKey.parse("abc") == nil)
        #expect(FoodKey.isCustom(FoodKey.quickEntryKey))
        #expect(FoodKey.isQuickEntry(FoodKey.quickEntryKey))
    }
}
