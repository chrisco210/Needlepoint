import Testing
@testable import Needlepoint

@MainActor
struct StashCoverageTests {
    private let coverage = StashCoverage(stash: [
        StashThread(brand: "DMC Floss", code: "310", qty: 2),
        StashThread(brand: "Silk & Ivory", code: "01", qty: 0),
    ])

    private func thread(_ brand: String, _ code: String, qty: Int) -> PatternThread {
        PatternThread(brand: brand, code: code, name: "", qty: qty)
    }

    @Test func onHandMatchesKeysIgnoringCaseAndWhitespace() {
        #expect(coverage.onHand(ThreadKey(brand: " dmc floss", code: "310")) == 2)
        #expect(coverage.onHand(ThreadKey(brand: "DMC Floss", code: "321")) == 0)
    }

    /// Two devices can each add the same key before sync dedupes them.
    @Test func duplicateStashEntriesAddUp() {
        let coverage = StashCoverage(stash: [
            StashThread(brand: "DMC", code: "310", qty: 2),
            StashThread(brand: "dmc", code: "310", qty: 1),
        ])
        #expect(coverage.onHand(ThreadKey(brand: "DMC", code: "310")) == 3)
    }

    @Test func aThreadIsCoveredWhenTheStashHasEnough() {
        #expect(coverage.supply(of: thread("DMC Floss", "310", qty: 2)) == .covered(have: 2))
        #expect(coverage.supply(of: thread("DMC Floss", "310", qty: 1)) == .covered(have: 2))
    }

    @Test func aThreadIsShortWhenTheStashHasTooFew() {
        #expect(coverage.supply(of: thread("DMC Floss", "310", qty: 5)) == .short(more: 3, have: 2))
        #expect(coverage.supply(of: thread("Silk & Ivory", "01", qty: 1)) == .short(more: 1, have: 0))
        #expect(coverage.supply(of: thread("Kreinik", "002", qty: 2)) == .short(more: 2, have: 0))
    }

    @Test func coveredCountCountsThreadsWithEnoughOnHand() {
        let pattern = Pattern(name: "Strawberry")
        pattern.threads = [thread("DMC Floss", "310", qty: 1), thread("DMC Floss", "321", qty: 1)]
        #expect(coverage.coveredCount(in: pattern) == 1)
    }

    @Test(arguments: [(0, 0, "No threads listed"), (1, 2, "1 of 2 threads in stash"), (3, 3, "3 of 3 threads in stash")])
    func progressLabel(covered: Int, total: Int, expected: String) {
        #expect(StashCoverage.progressLabel(covered: covered, total: total) == expected)
    }
}
