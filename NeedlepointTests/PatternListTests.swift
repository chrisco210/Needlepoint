import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Needlepoint

@MainActor
private func pattern(
    _ name: String, designer: String = "", status: PatternStatus = .notStarted,
    notes: String = "", threads: [PatternThread] = [], created: Date = .now
) -> Pattern {
    let pattern = Pattern(name: name)
    pattern.designer = designer
    pattern.status = status
    pattern.notes = notes
    pattern.threads = threads
    pattern.created = created
    return pattern
}

@MainActor
struct PatternSearchTests {
    private let strawberry = pattern(
        "Strawberry", designer: "Kirk & Bradley", notes: "Gift for Mom",
        threads: [PatternThread(brand: "Silk & Ivory", code: "B12", name: "Ruby", qty: 1)])

    @Test(arguments: ["", "  "])
    func emptyQueryMatchesEverything(query: String) {
        #expect(PatternSearch.matches(strawberry, query: query))
    }

    @Test(arguments: ["straw", "KIRK", "mom", "silk & ivory", "b12", "ruby", " berry "])
    func matchesNameDesignerNotesAndThreads(query: String) {
        #expect(PatternSearch.matches(strawberry, query: query))
    }

    @Test func doesNotMatchUnrelatedText() {
        #expect(!PatternSearch.matches(strawberry, query: "lemon"))
    }
}

@MainActor
struct PatternFilterTests {
    @Test func filtersByStatusAndSearchInStandardOrder() {
        let patterns = [
            pattern("Lemon", status: .notStarted), pattern("Lime", status: .inProgress),
            pattern("Strawberry", status: .inProgress), pattern("Pear", status: .finished),
        ]
        #expect(PatternFilter.apply(patterns, query: "", status: nil).map(\.name) == ["Lime", "Strawberry", "Lemon", "Pear"])
        #expect(PatternFilter.apply(patterns, query: "", status: .inProgress).map(\.name) == ["Lime", "Strawberry"])
        #expect(PatternFilter.apply(patterns, query: "l", status: .inProgress).map(\.name) == ["Lime"])
    }
}

@MainActor
struct PatternFoldersTests {
    @Test func oneFolderPerDesignerSortedWithNoDesignerLast() {
        let folders = PatternFolders.make(from: [
            pattern("A", designer: "Melissa Shirley"), pattern("B"),
            pattern("C", designer: "Associated Talents"), pattern("D", designer: "melissa shirley "),
        ], statusFilter: nil)
        #expect(folders.map(\.name) == ["Associated Talents", "Melissa Shirley", "No designer"])
        #expect(folders.map(\.patterns.count) == [1, 2, 1])
        #expect(folders.last?.key == "")
    }

    @Test func folderNameIsTheDesignerAsWrittenOnTheOldestPattern() {
        let folders = PatternFolders.make(from: [
            pattern("New", designer: "KIRK & BRADLEY", created: Date(timeIntervalSince1970: 200)),
            pattern("Old", designer: " Kirk & Bradley", created: Date(timeIntervalSince1970: 100)),
        ], statusFilter: nil)
        #expect(folders.map(\.name) == ["Kirk & Bradley"])
    }

    @Test func folderPatternsUseTheStandardOrder() {
        let folders = PatternFolders.make(from: [
            pattern("Lemon", designer: "K"), pattern("Lime", designer: "K", status: .inProgress),
        ], statusFilter: nil)
        #expect(folders.first?.patterns.map(\.name) == ["Lime", "Lemon"])
    }

    @Test func countsPatternsInProgress() {
        let folders = PatternFolders.make(from: [
            pattern("A", designer: "K", status: .inProgress), pattern("B", designer: "K", status: .needsFinishing),
            pattern("C", designer: "K", status: .finished),
        ], statusFilter: nil)
        #expect(folders.first?.inProgressCount == 2)
        #expect(folders.first?.inProgressLabel == "2 in progress")
    }

    @Test func noInProgressLabelWhenNoneAreInProgress() {
        let folders = PatternFolders.make(from: [pattern("A", designer: "K")], statusFilter: nil)
        #expect(folders.first?.inProgressLabel == nil)
    }

    @Test func countLabelWithoutAFilter() {
        let folders = PatternFolders.make(from: [
            pattern("A", designer: "K"), pattern("B", designer: "K"), pattern("C", designer: "M"),
        ], statusFilter: nil)
        #expect(folders.map(\.countLabel) == ["2 patterns", "1 pattern"])
    }

    @Test func statusFilterShowsMatchesOfTotalAndHidesEmptyFolders() {
        let folders = PatternFolders.make(from: [
            pattern("A", designer: "K", status: .inProgress), pattern("B", designer: "K"),
            pattern("C", designer: "M"),
        ], statusFilter: .inProgress)
        #expect(folders.map(\.name) == ["K"])
        #expect(folders.first?.countLabel == "1 of 2 patterns")
    }

    @Test func initialIsTheDesignersFirstLetter() {
        let folders = PatternFolders.make(from: [pattern("A", designer: "melissa"), pattern("B")], statusFilter: nil)
        #expect(folders.map(\.initial) == ["M", nil])
    }

    @Test func coverImagesAreTheFirstFourInStandardOrder() {
        let patterns = (0..<5).map { index in
            let p = pattern("P\(index)", designer: "K")
            p.coverData = Data([UInt8(index)])
            return p
        }
        patterns[1].coverData = nil
        let folders = PatternFolders.make(from: patterns, statusFilter: nil)
        #expect(folders.first?.coverImages == [Data([0]), Data([2]), Data([3]), Data([4])])
    }
}

@MainActor
struct PatternCardTextTests {
    @Test func designerLabelFallsBackWhenEmpty() {
        #expect(pattern("A", designer: "Kirk & Bradley").designerLabel == "Kirk & Bradley")
        #expect(pattern("A", designer: "  ").designerLabel == "Designer not set")
    }

    @Test func placeholderSaysPDFOnlyForAPDF() {
        let pdf = pattern("A")
        pdf.fileType = .pdf
        #expect(pdf.placeholderLabel == "PDF pattern")
        #expect(pattern("B").placeholderLabel == "No file yet")
    }

    @Test func displayImageIsTheCoverThenAnImageFile() {
        let withCover = pattern("A")
        withCover.coverData = Data([1])
        withCover.fileData = Data([2])
        withCover.fileType = .jpeg
        #expect(withCover.displayImageData == Data([1]))

        let imageFile = pattern("B")
        imageFile.fileData = Data([2])
        imageFile.fileType = .jpeg
        #expect(imageFile.displayImageData == Data([2]))

        let pdfFile = pattern("C")
        pdfFile.fileData = Data([3])
        pdfFile.fileType = .pdf
        #expect(pdfFile.displayImageData == nil)
    }
}
