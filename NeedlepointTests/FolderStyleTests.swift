import Foundation
import SwiftData
import Testing
@testable import Needlepoint

@MainActor
struct FolderStyleTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Pattern.self, FolderStyle.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func allStyles() throws -> [FolderStyle] {
        try context.fetch(FetchDescriptor<FolderStyle>())
    }

    @Test func newStyleDefaultsToFillOnWhite() {
        let style = FolderStyle(key: "kirk & bradley")
        #expect(style.fit == .cover)
        #expect(style.background == "#ffffff")
        #expect(style.imageData == nil)
    }

    @Test func fitStoresTheWebAppRawValue() {
        let style = FolderStyle(key: "")
        style.fit = .contain
        #expect(style.fitRaw == "contain")
        style.fitRaw = "stretch"
        #expect(style.fit == .cover, "An unknown fit reads as the default")
    }

    @Test func findMatchesTheKey() throws {
        let style = FolderStyle(key: "kirk & bradley")
        context.insert(style)
        #expect(try FolderStyle.find(key: "kirk & bradley", in: context) === style)
        #expect(try FolderStyle.find(key: "melissa shirley", in: context) == nil)
    }

    /// The empty key is the "No designer" folder, which can have a style too.
    @Test func findMatchesTheEmptyKey() throws {
        let style = FolderStyle(key: "")
        context.insert(style)
        #expect(try FolderStyle.find(key: "", in: context) === style)
    }

    @Test func styleForKeyReturnsTheExistingStyleInsteadOfAddingOne() throws {
        let existing = FolderStyle(key: "kirk & bradley")
        context.insert(existing)
        #expect(try FolderStyle.style(forKey: "kirk & bradley", in: context) === existing)
        #expect(try allStyles().count == 1)
    }

    @Test func styleForKeyAddsAStyleWhenNoneExists() throws {
        let style = try FolderStyle.style(forKey: "melissa shirley", in: context)
        #expect(style.key == "melissa shirley")
        #expect(try allStyles().count == 1)
    }
}
