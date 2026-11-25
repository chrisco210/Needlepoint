import Testing
@testable import Needlepoint

struct PatternThreadTests {
    @Test func keyMatchesAStashThreadKey() {
        let thread = PatternThread(brand: " DMC Floss", code: "310 ", name: "Black", qty: 1)
        #expect(thread.key == ThreadKey(brand: "dmc floss", code: "310"))
    }

    @Test func cleanedDropsRowsWithNoBrandCodeOrName() {
        let rows = [
            PatternThread(brand: "", code: "", name: "", qty: 1),
            PatternThread(brand: "  ", code: " ", name: "\n", qty: 3),
            PatternThread(brand: "", code: "", name: "Background", qty: 1),
        ]
        #expect(PatternThread.cleaned(rows).map(\.name) == ["Background"])
    }

    @Test func cleanedTrimsFields() {
        let cleaned = PatternThread.cleaned([PatternThread(brand: " DMC ", code: " 310 ", name: " Black ", qty: 2)])
        #expect(cleaned == [PatternThread(brand: "DMC", code: "310", name: "Black", qty: 2)])
    }

    @Test(arguments: [(0, 1), (-4, 1), (1, 1), (5, 5)])
    func cleanedClampsQuantityToAtLeastOne(qty: Int, expected: Int) {
        let cleaned = PatternThread.cleaned([PatternThread(brand: "DMC", code: "310", name: "", qty: qty)])
        #expect(cleaned.first?.qty == expected)
    }

    @Test func cleanedKeepsTheUsersOrder() {
        let rows = [
            PatternThread(brand: "DMC", code: "999", name: "", qty: 1),
            PatternThread(brand: "DMC", code: "1", name: "", qty: 1),
        ]
        #expect(PatternThread.cleaned(rows).map(\.code) == ["999", "1"])
    }
}
