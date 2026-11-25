import Foundation
import SwiftData
import Testing
@testable import Needlepoint

@MainActor
struct StashSearchTests {
    private let thread = StashThread(brand: "Silk & Ivory", code: "B12", name: "Snow")

    @Test(arguments: ["", "  ", "silk", "b12", "SNOW", " ivory "])
    func matchesBrandCodeAndName(query: String) {
        #expect(StashSearch.matches(thread, query: query))
    }

    @Test func doesNotMatchOtherText() {
        #expect(!StashSearch.matches(thread, query: "dmc"))
    }
}

struct StashPasteParseTests {
    @Test func readsBrandCodeNameAndQuantity() {
        #expect(StashPaste.parse("DMC Floss, 310, Black, 2") == [PastedThread(brand: "DMC Floss", code: "310", name: "Black", qty: 2)])
    }

    @Test func acceptsTabsAndMixedSeparators() {
        #expect(StashPaste.parse("DMC Floss\t310\tBlack\t2") == [PastedThread(brand: "DMC Floss", code: "310", name: "Black", qty: 2)])
        #expect(StashPaste.parse("DMC Floss\t310, Black") == [PastedThread(brand: "DMC Floss", code: "310", name: "Black", qty: 1)])
    }

    @Test func aNumericThirdFieldIsTheQuantity() {
        #expect(StashPaste.parse("Kreinik #12 Braid, 002, 3") == [PastedThread(brand: "Kreinik #12 Braid", code: "002", name: "", qty: 3)])
    }

    @Test func quantityDefaultsToOne() {
        #expect(StashPaste.parse("DMC, 310").first?.qty == 1)
        #expect(StashPaste.parse("DMC, 310, Black").first?.qty == 1)
        #expect(StashPaste.parse("DMC, 310, Black, lots").first?.qty == 1)
    }

    /// The web app kept an explicit 0, for recording a color you're out of.
    @Test func anExplicitZeroIsKept() {
        #expect(StashPaste.parse("DMC, 310, 0").first?.qty == 0)
    }

    @Test func skipsBlankAndIncompleteLines() {
        let text = """

        DMC
        , 310
        DMC,
        Silk & Ivory, 01, Snow
        """
        #expect(StashPaste.parse(text).map(\.code) == ["01"])
    }

    @Test func keepsLeadingZerosAndLetters() {
        #expect(StashPaste.parse("Kreinik, 002HL").first?.code == "002HL")
    }

    @Test(arguments: [(0, "No lines read. Use brand, number, name, qty."), (1, "Added 1 thread"), (4, "Added 4 threads")])
    func toast(count: Int, expected: String) {
        #expect(StashPaste.toast(count: count) == expected)
    }
}

@MainActor
struct StashPasteApplyTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(for: StashThread.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func allThreads() throws -> [StashThread] {
        try context.fetch(FetchDescriptor<StashThread>())
    }

    @Test func addsNewThreadsAndAddsToExistingOnes() throws {
        context.insert(StashThread(brand: "DMC Floss", code: "310", name: "Black", color: "#000000", qty: 1))
        let count = try StashPaste.apply(StashPaste.parse("dmc floss, 310, 2\nSilk & Ivory, 01, Snow"), in: context)

        #expect(count == 2)
        let threads = try allThreads()
        #expect(threads.count == 2)
        let black = try #require(threads.first { $0.code == "310" })
        #expect(black.qty == 3)
        #expect(black.name == "Black", "Pasting adds stock without renaming")
        #expect(threads.first { $0.code == "01" }?.name == "Snow")
    }

    @Test func repeatedLinesInOnePasteAddUp() throws {
        try StashPaste.apply(StashPaste.parse("DMC, 310, 1\nDMC, 310, 2"), in: context)
        #expect(try allThreads().map(\.qty) == [3])
    }
}

@MainActor
struct ThreadDraftEditingTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(for: StashThread.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func allThreads() throws -> [StashThread] {
        try context.fetch(FetchDescriptor<StashThread>())
    }

    @Test func editingDraftCopiesTheThread() {
        let thread = StashThread(brand: "DMC", code: "310", name: "Black", color: "#000000", qty: 4)
        let draft = ThreadDraft(editing: thread)
        #expect((draft.brand, draft.code, draft.name, draft.color, draft.qty) == ("DMC", "310", "Black", "#000000", 4))
    }

    @Test func savingAnEditUpdatesTheSameThread() throws {
        let thread = StashThread(brand: "DMC", code: "310", name: "Black", qty: 4)
        context.insert(thread)
        var draft = ThreadDraft(editing: thread)
        draft.name = "Noir"
        draft.code = "310 "

        #expect(try draft.save(editing: thread, in: context) == .saved)
        #expect(try allThreads().count == 1)
        #expect(thread.name == "Noir")
    }

    @Test func anEditCanChangeTheKey() throws {
        let thread = StashThread(brand: "DMC", code: "310", qty: 4)
        context.insert(thread)
        var draft = ThreadDraft(editing: thread)
        draft.code = "321"
        try draft.save(editing: thread, in: context)
        #expect(thread.code == "321")
        #expect(try StashThread.find(ThreadKey(brand: "DMC", code: "321"), in: context) === thread)
    }

    @Test func anEditCannotTakeAnotherThreadsKey() throws {
        let black = StashThread(brand: "DMC", code: "310", qty: 4)
        let red = StashThread(brand: "DMC", code: "321", qty: 1)
        context.insert(black)
        context.insert(red)
        var draft = ThreadDraft(editing: red)
        draft.code = "310"

        #expect(throws: ThreadDraft.SaveError.duplicateKey) { try draft.save(editing: red, in: context) }
        #expect(red.code == "321")
    }

    @Test func outcomeToasts() {
        #expect(ThreadDraft.Outcome.saved.toast == "Thread saved")
        #expect(ThreadDraft.SaveError.duplicateKey.message == "That brand and number is already in your stash.")
    }

    @Test func deleteConfirmationMatchesTheWebApp() {
        let thread = StashThread(brand: "DMC", code: "310")
        #expect(StashDelete.confirmation(for: thread).title == "Remove DMC 310?")
        #expect(StashDelete.confirmation(for: thread).message == "It comes off your stash list.")
        #expect(StashDelete.toast == "Thread removed")
    }

    @Test func deleteRemovesTheThread() throws {
        let thread = StashThread(brand: "DMC", code: "310")
        context.insert(thread)
        try StashDelete.delete(thread, in: context)
        #expect(try allThreads().isEmpty)
    }
}

@MainActor
struct DebouncerTests {
    @Test func rapidCallsRunTheActionOnceAfterThePause() async throws {
        var runs = 0
        let debouncer = Debouncer(delay: .milliseconds(200))
        for _ in 0..<5 {
            debouncer.schedule { runs += 1 }
            try await Task.sleep(for: .milliseconds(30))
        }
        #expect(runs == 0)
        try await Task.sleep(for: .milliseconds(500))
        #expect(runs == 1)
    }

    @Test func callsFarApartEachRun() async throws {
        var runs = 0
        let debouncer = Debouncer(delay: .milliseconds(100))
        debouncer.schedule { runs += 1 }
        try await Task.sleep(for: .milliseconds(400))
        debouncer.schedule { runs += 1 }
        try await Task.sleep(for: .milliseconds(400))
        #expect(runs == 2)
    }

    @Test func defaultDelayMatchesTheReadme() {
        #expect(Debouncer().delay == .milliseconds(700))
    }
}
