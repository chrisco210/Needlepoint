import Testing
@testable import Needlepoint

struct BrandSuggestionsTests {
    @Test func builtInListMatchesTheReadme() {
        #expect(BrandSuggestions.builtIn == [
            "DMC Pearl Cotton #3", "DMC Pearl Cotton #5", "DMC Floss", "Silk & Ivory", "Splendor",
            "Vineyard Silk", "Planet Earth Fiber", "Rainbow Gallery Neon Rays",
            "Rainbow Gallery Fyre Werks", "Kreinik #12 Braid", "Pepper Pot Silk", "Appleton Wool",
            "Paternayan", "Watercolours", "Silk Lamé Braid", "Entice", "Bravo!",
        ])
    }

    @Test func allAddsStashBrandsNotAlreadyBuiltIn() {
        let all = BrandSuggestions.all(stashBrands: ["Sundance", "dmc floss", " Access Commodities ", "Sundance", ""])
        #expect(Array(all.prefix(BrandSuggestions.builtIn.count)) == BrandSuggestions.builtIn)
        #expect(Array(all.dropFirst(BrandSuggestions.builtIn.count)) == ["Access Commodities", "Sundance"])
    }

    @Test func emptyQueryMatchesNothing() {
        #expect(BrandSuggestions.matching("  ", in: BrandSuggestions.builtIn).isEmpty)
    }

    @Test func matchesAnywhereIgnoringCaseWithPrefixMatchesFirst() {
        let brands = ["Vineyard Silk", "Silk & Ivory", "Pepper Pot Silk", "DMC Floss"]
        #expect(BrandSuggestions.matching("silk", in: brands) == ["Silk & Ivory", "Vineyard Silk", "Pepper Pot Silk"])
    }

    @Test func leavesOutABrandTypedInFull() {
        #expect(BrandSuggestions.matching("dmc floss", in: ["DMC Floss", "DMC Floss Variations"]) == ["DMC Floss Variations"])
    }

    @Test func returnsAtMostTheLimit() {
        #expect(BrandSuggestions.matching("a", in: BrandSuggestions.builtIn, limit: 3).count == 3)
    }
}
