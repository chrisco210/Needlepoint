import Foundation
import SwiftData
import Testing
@testable import Needlepoint

@MainActor
struct ThreadDraftTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: StashThread.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func allThreads() throws -> [StashThread] {
        try context.fetch(FetchDescriptor<StashThread>())
    }

    @Test func newDraftMatchesTheWebAppDefaults() {
        let draft = ThreadDraft()
        #expect(draft.brand.isEmpty && draft.code.isEmpty && draft.name.isEmpty)
        #expect(draft.color == "#b84a7a")
        #expect(draft.qty == 1)
    }

    @Test(arguments: [("", "310"), ("DMC", ""), ("  ", "310"), ("DMC", " \n")])
    func cannotSaveWithoutBrandAndCode(brand: String, code: String) {
        var draft = ThreadDraft()
        draft.brand = brand
        draft.code = code
        #expect(!draft.canSave)
    }

    @Test func canSaveWithBrandAndCode() {
        var draft = ThreadDraft()
        draft.brand = "DMC Floss"
        draft.code = "310"
        #expect(draft.canSave)
    }

    @Test func savingANewKeyAddsAThread() throws {
        var draft = ThreadDraft()
        draft.brand = " DMC Floss "
        draft.code = "310"
        draft.name = "Black"
        draft.color = "#000000"
        draft.qty = 3

        #expect(try draft.save(in: context) == .added)
        let saved = try #require(try allThreads().first)
        #expect(try allThreads().count == 1)
        #expect(saved.brand == "DMC Floss")
        #expect(saved.name == "Black")
        #expect(saved.color == "#000000")
        #expect(saved.qty == 3)
    }

    @Test func savingAnExistingKeyUpdatesIt() throws {
        context.insert(StashThread(brand: "DMC Floss", code: "310", name: "Black", qty: 1))
        var draft = ThreadDraft()
        draft.brand = "dmc floss"
        draft.code = "310"
        draft.name = "Noir"
        draft.qty = 4

        #expect(try draft.save(in: context) == .updatedExisting)
        #expect(try allThreads().count == 1)
        #expect(try allThreads().first?.name == "Noir")
        #expect(try allThreads().first?.qty == 4)
    }

    @Test func savingClampsNegativeQuantityToZero() throws {
        var draft = ThreadDraft()
        draft.brand = "DMC"
        draft.code = "310"
        draft.qty = -2
        try draft.save(in: context)
        #expect(try allThreads().first?.qty == 0)
    }

    @Test func savingAnInvalidDraftThrowsAndAddsNothing() throws {
        var draft = ThreadDraft()
        draft.brand = "DMC"
        #expect(throws: ThreadDraft.SaveError.missingBrandOrCode) { try draft.save(in: context) }
        #expect(try allThreads().isEmpty)
    }

    @Test func toastsMatchTheWebApp() {
        #expect(ThreadDraft.Outcome.added.toast == "Thread saved")
        #expect(ThreadDraft.Outcome.updatedExisting.toast == "Already in stash, updated it")
    }
}
