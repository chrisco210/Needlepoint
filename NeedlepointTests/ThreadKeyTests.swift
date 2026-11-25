import Testing
@testable import Needlepoint

struct ThreadKeyTests {
    @Test(arguments: [
        ("DMC Floss", "310", "dmc floss", "310"),
        ("  DMC Floss ", " 310", "DMC Floss", "310"),
        ("Silk & Ivory", "01\n", "SILK & IVORY", "01"),
        ("Kreinik #12 Braid", "002HL", "kreinik #12 braid", "002hl"),
    ])
    func matchesIgnoringCaseAndSurroundingWhitespace(
        brandA: String, codeA: String, brandB: String, codeB: String
    ) {
        #expect(ThreadKey(brand: brandA, code: codeA) == ThreadKey(brand: brandB, code: codeB))
    }

    @Test(arguments: [
        ("DMC", "0310", "DMC", "310"),    // Leading zeros are part of the color number.
        ("DMC", "310A", "DMC", "310"),
        ("DMC Floss", "310", "DMC Pearl Cotton #5", "310"),
        ("DMC Floss", "310", "DMCFloss", "310"),    // Only surrounding whitespace is ignored.
    ])
    func distinguishesDifferentThreads(
        brandA: String, codeA: String, brandB: String, codeB: String
    ) {
        #expect(ThreadKey(brand: brandA, code: codeA) != ThreadKey(brand: brandB, code: codeB))
    }

    @Test func equalKeysHashTogether() {
        let keys: Set = [ThreadKey(brand: "DMC", code: "310"), ThreadKey(brand: " dmc ", code: "310 ")]
        #expect(keys.count == 1)
    }

    @Test func storageValueIsTheSameForEqualKeys() {
        #expect(ThreadKey(brand: "DMC", code: "310").storageValue
            == ThreadKey(brand: " dmc", code: "310 ").storageValue)
    }

    /// A plain "|" separator would make these collide, the way the web app's keys could.
    @Test func storageValueKeepsBrandAndCodeApart() {
        #expect(ThreadKey(brand: "a|b", code: "c").storageValue
            != ThreadKey(brand: "a", code: "b|c").storageValue)
    }
}
