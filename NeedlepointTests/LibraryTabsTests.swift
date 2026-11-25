import Foundation
import Testing
@testable import Needlepoint

@MainActor
private func pattern(
    _ name: String, status: PatternStatus = .notStarted, designer: String = "",
    notes: String = "", threads: [PatternThread] = []
) -> Pattern {
    let pattern = Pattern(name: name)
    pattern.status = status
    pattern.designer = designer
    pattern.notes = notes
    pattern.threads = threads
    return pattern
}

private func thread(_ brand: String, _ code: String, _ name: String = "", qty: Int = 1) -> PatternThread {
    PatternThread(brand: brand, code: code, name: name, qty: qty)
}

// MARK: - Missing threads

@MainActor
struct MissingThreadTests {
    @Test func missingListsOnlyShortThreads() {
        let coverage = StashCoverage(stash: [StashThread(brand: "DMC", code: "310", qty: 1)])
        let p = pattern("A", threads: [thread("DMC", "310"), thread("DMC", "321", "Red", qty: 2), thread("DMC", "310", qty: 3)])
        #expect(coverage.missing(in: p).map(\.thread.code) == ["321", "310"])
        #expect(coverage.missing(in: p).map(\.more) == [2, 2])
    }

    /// Rows with only a name (where a thread is used) can't be matched to the stash.
    @Test func rowsWithoutBrandOrCodeAreIgnored() {
        let p = pattern("A", threads: [thread("", "", "Background")])
        #expect(StashCoverage(stash: []).missing(in: p).isEmpty)
    }

    @Test(arguments: [
        (PatternThread(brand: "DMC", code: "321", name: "Red", qty: 2), 0, "DMC 321 Red: need 2"),
        (PatternThread(brand: "DMC", code: "321", name: "", qty: 3), 1, "DMC 321: need 2 more"),
    ])
    func labelReadsAsAShortfall(thread: PatternThread, have: Int, expected: String) {
        #expect(MissingThread(thread: thread, have: have).label == expected)
    }
}

// MARK: - WIP

@MainActor
struct WorkInProgressTests {
    private let patterns = [
        pattern("Zinnia", status: .inProgress), pattern("Aster", status: .inProgress),
        pattern("Lily", status: .needsFinishing, designer: "Kirk"), pattern("Fern", status: .needsFinishing),
        pattern("Rose", status: .notStarted), pattern("Iris", status: .finished),
    ]

    @Test func sectionsSortByName() {
        #expect(WorkInProgress.onTheNeedle(patterns, query: "").map(\.name) == ["Aster", "Zinnia"])
        #expect(WorkInProgress.needsFinishing(patterns, query: "").map(\.name) == ["Fern", "Lily"])
    }

    @Test func searchFiltersBothSections() {
        #expect(WorkInProgress.onTheNeedle(patterns, query: "kirk").isEmpty)
        #expect(WorkInProgress.needsFinishing(patterns, query: "kirk").map(\.name) == ["Lily"])
    }

    @Test func countIncludesBothSections() {
        #expect(WorkInProgress.count(patterns) == 4)
    }

    @Test func notesPreviewCutsAt140Characters() {
        #expect(WorkInProgress.notesPreview("") == nil)
        #expect(WorkInProgress.notesPreview("Short note") == "Short note")
        let long = String(repeating: "a", count: 150)
        #expect(WorkInProgress.notesPreview(long) == String(repeating: "a", count: 140) + "…")
    }

    @Test func statusChangeToasts() {
        #expect(StatusChange.toast(for: .finished, name: "Lily") == "\"Lily\" marked finished, congrats!")
        #expect(StatusChange.toast(for: .needsFinishing, name: "Lily") == "\"Lily\" is stitched, on to finishing")
        #expect(StatusChange.toast(for: .inProgress, name: "Lily") == "\"Lily\" is on the needle")
    }
}

// MARK: - Ready to stitch

@MainActor
struct ReadyToStitchTests {
    private let coverage = StashCoverage(stash: [
        StashThread(brand: "DMC", code: "310", qty: 5),
        StashThread(brand: "DMC", code: "321", qty: 1),
    ])

    @Test func patternsFullyCoveredAreReadyInStandardOrder() {
        let patterns = [
            pattern("Pear", threads: [thread("DMC", "310")]),
            pattern("Apple", status: .inProgress, threads: [thread("DMC", "321")]),
            pattern("Fig", threads: [thread("DMC", "310"), thread("DMC", "999")]),
        ]
        let result = ReadyToStitch.make(patterns, coverage: coverage, includeWishlist: true, query: "")
        #expect(result.ready.map(\.name) == ["Apple", "Pear"])
    }

    @Test func finishedAndNeedsFinishingAreLeftOut() {
        let patterns = [
            pattern("Done", status: .finished, threads: [thread("DMC", "310")]),
            pattern("Stitched", status: .needsFinishing, threads: [thread("DMC", "310")]),
        ]
        let result = ReadyToStitch.make(patterns, coverage: coverage, includeWishlist: true, query: "")
        #expect(result.ready.isEmpty)
    }

    @Test func wishlistToggleControlsWishlistPatterns() {
        let patterns = [pattern("Dream", status: .wishlist, threads: [thread("DMC", "310")])]
        #expect(ReadyToStitch.make(patterns, coverage: coverage, includeWishlist: true, query: "").ready.count == 1)
        #expect(ReadyToStitch.make(patterns, coverage: coverage, includeWishlist: false, query: "").ready.isEmpty)
    }

    @Test func almostThereMeansOneOrTwoMissingSortedByMissingCount() {
        let patterns = [
            pattern("Two", threads: [thread("X", "1"), thread("X", "2")]),
            pattern("One", threads: [thread("X", "1"), thread("DMC", "310")]),
            pattern("Three", threads: [thread("X", "1"), thread("X", "2"), thread("X", "3")]),
            pattern("Also one", threads: [thread("DMC", "321", qty: 2)]),
        ]
        let result = ReadyToStitch.make(patterns, coverage: coverage, includeWishlist: true, query: "")
        #expect(result.almost.map(\.pattern.name) == ["Also one", "One", "Two"])
        #expect(result.almost.map(\.missing.count) == [1, 1, 2])
    }

    @Test func patternsWithoutThreadsAreCountedSeparately() {
        let patterns = [pattern("Empty"), pattern("Name only", threads: [thread("", "", "Background")])]
        let result = ReadyToStitch.make(patterns, coverage: coverage, includeWishlist: true, query: "")
        #expect(result.ready.isEmpty && result.almost.isEmpty)
        #expect(result.noThreadsCount == 2)
    }

    @Test func searchMatchesNameAndDesigner() {
        let patterns = [
            pattern("Pear", designer: "Kirk", threads: [thread("DMC", "310")]),
            pattern("Plum", threads: [thread("DMC", "310")]),
        ]
        #expect(ReadyToStitch.make(patterns, coverage: coverage, includeWishlist: true, query: "kirk").ready.map(\.name) == ["Pear"])
    }

    @Test func badgeCountIgnoresTheSearch() {
        let patterns = [pattern("Pear", threads: [thread("DMC", "310")]), pattern("Plum", threads: [thread("DMC", "310")])]
        #expect(ReadyToStitch.readyCount(patterns, coverage: coverage, includeWishlist: true) == 2)
    }

    @Test(arguments: [(0, nil), (1, "1 pattern has no threads listed yet, so it isn't counted here. Open it and add the threads."),
                      (3, "3 patterns have no threads listed yet, so they aren't counted here. Open them and add the threads.")])
    func noThreadsNote(count: Int, expected: String?) {
        #expect(ReadyToStitch.noThreadsNote(count: count) == expected)
    }
}

// MARK: - Shopping list

@MainActor
struct ShoppingListTests {
    private let stash = [
        StashThread(brand: "DMC Floss", code: "310", name: "Black", color: "#000000", qty: 1),
    ]

    @Test func sumsNeedsAcrossPatternsAndSubtractsTheStash() {
        let patterns = [
            pattern("Strawberry", status: .inProgress, threads: [thread("DMC Floss", "310", qty: 2), thread("DMC Floss", "321", "Red")]),
            pattern("Lemon", threads: [thread("dmc floss", "310 ")]),
        ]
        let lines = ShoppingList.make(patterns, stash: stash, includeWishlist: false)
        #expect(lines.map(\.code) == ["310", "321"])
        let black = lines[0]
        #expect((black.need, black.have, black.buy) == (3, 1, 2))
        #expect(black.patternNames == ["Strawberry", "Lemon"])
        #expect(black.color == "#000000")
        #expect(lines[1].name == "Red")
        #expect(lines[1].color == nil)
    }

    @Test func threadsTheStashCoversAreLeftOut() {
        let lines = ShoppingList.make([pattern("A", threads: [thread("DMC Floss", "310")])], stash: stash, includeWishlist: false)
        #expect(lines.isEmpty)
    }

    @Test func wishlistIsOffUnlessIncluded() {
        let patterns = [pattern("Dream", status: .wishlist, threads: [thread("X", "1")])]
        #expect(ShoppingList.make(patterns, stash: [], includeWishlist: false).isEmpty)
        #expect(ShoppingList.make(patterns, stash: [], includeWishlist: true).count == 1)
    }

    @Test func finishedAndNeedsFinishingAreLeftOut() {
        let patterns = [
            pattern("Done", status: .finished, threads: [thread("X", "1")]),
            pattern("Stitched", status: .needsFinishing, threads: [thread("X", "1")]),
        ]
        #expect(ShoppingList.make(patterns, stash: [], includeWishlist: true).isEmpty)
    }

    @Test func nameComesFromTheFirstPatternThatGivesOne() {
        let patterns = [pattern("A", threads: [thread("X", "1")]), pattern("B", threads: [thread("X", "1", "Gold")])]
        #expect(ShoppingList.make(patterns, stash: [], includeWishlist: false).first?.name == "Gold")
    }

    @Test func sortsByBrandThenNumericCode() {
        let patterns = [pattern("A", threads: [
            thread("Silk & Ivory", "01"), thread("DMC", "3865"), thread("DMC", "34"), thread("DMC", "310"),
        ])]
        let lines = ShoppingList.make(patterns, stash: [], includeWishlist: false)
        #expect(lines.map(\.code) == ["34", "310", "3865", "01"])
        #expect(ShoppingList.sections(lines).map(\.brand) == ["DMC", "Silk & Ivory"])
    }

    @Test func detailAndCopyTextMatchTheReadme() {
        let patterns = [
            pattern("Strawberry", threads: [thread("DMC", "310", "Black", qty: 2)]),
            pattern("Lemon", threads: [thread("DMC", "321")]),
        ]
        let lines = ShoppingList.make(patterns, stash: [StashThread(brand: "DMC", code: "310", qty: 1)], includeWishlist: false)
        #expect(lines[0].detail == "Buy 1, need 2, have 1, for Strawberry")
        #expect(ShoppingList.copyText(lines) == "DMC 310 (Black), buy 1\nDMC 321, buy 1")
        #expect(ShoppingList.totalToBuy(lines) == 2)
    }

    @Test func boughtToastNamesTheThread() {
        #expect(ShoppingList.boughtToast(brand: "DMC", code: "310") == "DMC 310 added to stash")
    }
}
