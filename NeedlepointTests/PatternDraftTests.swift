import Foundation
import SwiftData
import Testing
@testable import Needlepoint

@MainActor
struct PatternDraftTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Pattern.self, FolderStyle.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func allPatterns() throws -> [Pattern] {
        try context.fetch(FetchDescriptor<Pattern>())
    }

    // MARK: - Starting a draft

    @Test func newDraftHasReadmeDefaults() {
        let draft = PatternDraft()
        #expect(draft.name.isEmpty && draft.designer.isEmpty && draft.notes.isEmpty)
        #expect(draft.status == .notStarted)
        #expect(draft.mesh == nil)
        #expect(draft.threads.isEmpty)
        #expect(!draft.canSave)
    }

    /// "Add to this folder" opens the editor with the folder's designer filled in.
    @Test func draftForAFolderPrefillsTheDesigner() {
        #expect(PatternDraft(designer: "Kirk & Bradley").designer == "Kirk & Bradley")
    }

    @Test func draftForAnExistingPatternCopiesItsFields() {
        let pattern = Pattern(name: "Strawberry")
        pattern.designer = "Kirk & Bradley"
        pattern.status = .inProgress
        pattern.mesh = .thirteen
        pattern.notes = "Gift"
        pattern.threads = [PatternThread(brand: "DMC", code: "310", name: "Black", qty: 2)]

        let draft = PatternDraft(editing: pattern)
        #expect(draft.name == "Strawberry")
        #expect(draft.designer == "Kirk & Bradley")
        #expect(draft.status == .inProgress)
        #expect(draft.mesh == .thirteen)
        #expect(draft.notes == "Gift")
        #expect(draft.threads.map(\.patternThread) == pattern.threads)
    }

    @Test(arguments: ["", "   ", "\n"])
    func cannotSaveWithoutAName(name: String) {
        var draft = PatternDraft()
        draft.name = name
        #expect(!draft.canSave)
    }

    // MARK: - Thread rows

    @Test func addThreadRowCopiesThePreviousBrand() {
        var draft = PatternDraft()
        let first = draft.addThreadRow()
        #expect(draft.threads.count == 1)
        #expect(draft.threads[0].id == first)
        #expect(draft.threads[0].brand.isEmpty)
        #expect(draft.threads[0].qty == 1)

        draft.threads[0].brand = "DMC Floss"
        draft.threads[0].code = "310"
        let second = draft.addThreadRow()
        #expect(draft.threads.count == 2)
        #expect(draft.threads[1].id == second)
        #expect(draft.threads[1].brand == "DMC Floss")
        #expect(draft.threads[1].code.isEmpty)
    }

    @Test func removeThreadRowRemovesOnlyThatRow() {
        var draft = PatternDraft()
        let first = draft.addThreadRow()
        let second = draft.addThreadRow()
        draft.removeThreadRow(first)
        #expect(draft.threads.map(\.id) == [second])
    }

    @Test(arguments: [("DMC", "310", true), ("DMC", " ", false), ("", "310", false)])
    func rowHasAKeyOnlyWithBrandAndCode(brand: String, code: String, expected: Bool) {
        #expect(EditableThread(brand: brand, code: code, name: "", qty: 1).hasKey == expected)
    }

    // MARK: - Saving

    @Test func savingANewDraftInsertsACleanedPattern() throws {
        var draft = PatternDraft()
        draft.name = " Strawberry "
        draft.designer = " Kirk & Bradley "
        draft.status = .wishlist
        draft.mesh = .eighteen
        draft.notes = "Gift"
        draft.threads = [
            EditableThread(brand: " DMC ", code: "310", name: "", qty: 0),
            EditableThread(brand: "", code: "", name: "", qty: 1),
        ]

        let saved = try draft.save(to: nil, in: context)
        #expect(try allPatterns().count == 1)
        #expect(saved.name == "Strawberry")
        #expect(saved.designer == "Kirk & Bradley")
        #expect(saved.status == .wishlist)
        #expect(saved.mesh == .eighteen)
        #expect(saved.notes == "Gift")
        #expect(saved.threads == [PatternThread(brand: "DMC", code: "310", name: "", qty: 1)])
    }

    @Test func savingAnExistingPatternUpdatesItInPlace() throws {
        let pattern = Pattern(name: "Strawberry")
        pattern.fileData = Data([1, 2, 3])
        pattern.coverData = Data([4])
        let created = pattern.created
        context.insert(pattern)

        var draft = PatternDraft(editing: pattern)
        draft.name = "Strawberry Field"
        let saved = try draft.save(to: pattern, in: context)

        #expect(saved === pattern)
        #expect(try allPatterns().count == 1)
        #expect(pattern.name == "Strawberry Field")
        #expect(pattern.created == created)
        #expect(pattern.fileData == Data([1, 2, 3]), "The form doesn't edit the file, so saving keeps it")
        #expect(pattern.coverData == Data([4]))
    }

    @Test func savingWithoutANameThrowsAndAddsNothing() throws {
        let draft = PatternDraft()
        #expect(throws: PatternDraft.SaveError.missingName) { try draft.save(to: nil, in: context) }
        #expect(try allPatterns().isEmpty)
    }

    // MARK: - Deleting

    @Test func deleteRemovesThePattern() throws {
        let pattern = Pattern(name: "Strawberry")
        context.insert(pattern)
        try context.save()
        try PatternDraft.delete(pattern, in: context)
        #expect(try allPatterns().isEmpty)
    }

    @Test func deleteConfirmationMentionsTheFileOnlyWhenThereIsOne() {
        let plain = Pattern(name: "Strawberry")
        #expect(PatternDraft.deleteConfirmation(for: plain).title == "Delete \"Strawberry\"?")
        #expect(PatternDraft.deleteConfirmation(for: plain).message == "This can't be undone.")

        let withFile = Pattern(name: "Lemon")
        withFile.fileData = Data([1])
        #expect(PatternDraft.deleteConfirmation(for: withFile).message
            == "This also removes the pattern file. It can't be undone.")
    }

    @Test func toastsMatchTheWebApp() {
        #expect(PatternDraft.savedToast == "Pattern saved")
        #expect(PatternDraft.deletedToast == "Pattern deleted")
    }
}

struct ThreadSupplyLabelTests {
    @Test(arguments: [
        (ThreadSupply.covered(have: 2), "In stash (2)"),
        (ThreadSupply.short(more: 3, have: 2), "Need 3 more, you have 2"),
        (ThreadSupply.short(more: 1, have: 0), "Need 1 more"),
    ])
    func labelsMatchTheWebApp(supply: ThreadSupply, expected: String) {
        #expect(supply.label == expected)
    }
}

@MainActor
struct DesignerSuggestionsTests {
    @Test func listsEachDesignerOnceSortedWithoutNoDesigner() {
        let patterns = ["Melissa Shirley", "", "Associated Talents", "melissa shirley"].enumerated().map { index, designer in
            let pattern = Pattern(name: "P\(index)")
            pattern.designer = designer
            return pattern
        }
        #expect(DesignerSuggestions.all(from: patterns) == ["Associated Talents", "Melissa Shirley"])
    }
}
