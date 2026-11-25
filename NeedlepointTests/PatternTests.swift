import Foundation
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import Needlepoint

@MainActor
struct PatternTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Pattern.self, FolderStyle.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    // MARK: - Defaults and stored values

    @Test func newPatternHasReadmeDefaults() {
        let pattern = Pattern(name: " Strawberry ")
        #expect(pattern.name == "Strawberry")
        #expect(pattern.designer.isEmpty)
        #expect(pattern.status == .notStarted)
        #expect(pattern.mesh == nil)
        #expect(pattern.notes.isEmpty)
        #expect(pattern.threads.isEmpty)
        #expect(pattern.fileData == nil && pattern.coverData == nil)
        #expect(pattern.fileName.isEmpty)
        #expect(pattern.fileType == nil)
    }

    @Test func statusAndMeshStoreTheWebAppRawValues() {
        let pattern = Pattern(name: "Strawberry")
        pattern.status = .inProgress
        pattern.mesh = .other
        #expect(pattern.statusRaw == "In progress")
        #expect(pattern.meshRaw == "Other")
        pattern.mesh = nil
        #expect(pattern.meshRaw == nil)
    }

    /// Imported or synced data could carry a status this version doesn't know.
    @Test func unknownStatusReadsAsNotStarted() {
        let pattern = Pattern(name: "Strawberry")
        pattern.statusRaw = "Frogged"
        #expect(pattern.status == .notStarted)
    }

    @Test func fileTypeStoresTheIdentifier() {
        let pattern = Pattern(name: "Strawberry")
        pattern.fileType = .pdf
        #expect(pattern.fileTypeIdentifier == "com.adobe.pdf")
        #expect(pattern.fileType == .pdf)
        pattern.fileType = nil
        #expect(pattern.fileTypeIdentifier == nil)
    }

    @Test(arguments: [("Kirk & Bradley", "kirk & bradley"), ("  Melissa Shirley ", "melissa shirley"), ("", "")])
    func folderKeyIsTheTrimmedLowercasedDesigner(designer: String, key: String) {
        let pattern = Pattern(name: "Strawberry")
        pattern.designer = designer
        #expect(pattern.folderKey == key)
    }

    @Test func isValidNameRequiresTextAfterTrimming() {
        #expect(Pattern.isValidName("Strawberry"))
        #expect(!Pattern.isValidName(""))
        #expect(!Pattern.isValidName("  \n"))
    }

    // MARK: - Standard order

    @Test func standardOrderSortsByStatusThenName() {
        func make(_ name: String, _ status: PatternStatus) -> Pattern {
            let pattern = Pattern(name: name)
            pattern.status = status
            return pattern
        }
        let patterns = [
            make("Zebra", .finished), make("Apple", .wishlist), make("Pear", .inProgress),
            make("banana", .notStarted), make("Apple 10", .notStarted), make("Apple 9", .notStarted),
            make("Fig", .needsFinishing),
        ]
        #expect(patterns.sorted(by: Pattern.standardOrder).map(\.name) == [
            "Pear", "Fig", "Apple 9", "Apple 10", "banana", "Apple", "Zebra",
        ])
    }

    // MARK: - Persistence

    @Test func threadsAndFilesSurviveASaveAndFetch() throws {
        let pattern = Pattern(name: "Strawberry")
        pattern.threads = [
            PatternThread(brand: "DMC Floss", code: "321", name: "Red", qty: 2),
            PatternThread(brand: "Silk & Ivory", code: "01", name: "Snow", qty: 1),
        ]
        pattern.fileData = Data([0x25, 0x50, 0x44, 0x46])
        pattern.fileName = "strawberry.pdf"
        pattern.fileType = .pdf
        pattern.coverData = Data([0xff, 0xd8])
        context.insert(pattern)
        try context.save()

        let fetched = try #require(try ModelContext(container).fetch(FetchDescriptor<Pattern>()).first)
        #expect(fetched.threads == pattern.threads)
        #expect(fetched.fileData == pattern.fileData)
        #expect(fetched.coverData == pattern.coverData)
        #expect(fetched.fileName == "strawberry.pdf")
        #expect(fetched.fileType == .pdf)
    }
}
