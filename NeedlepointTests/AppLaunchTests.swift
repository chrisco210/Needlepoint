import Foundation
import SwiftData
import Testing
@testable import Needlepoint

@MainActor
struct AppLaunchTests {
    private func stash(in container: ModelContainer) throws -> [StashThread] {
        try container.mainContext.fetch(FetchDescriptor<StashThread>())
    }

    @Test func normalLaunchUsesTheOnDiskStore() {
        #expect(!AppLaunch(arguments: ["Needlepoint"]).usesInMemoryStore)
    }

    @Test func uiTestingUsesAnEmptyInMemoryStore() throws {
        let launch = AppLaunch(arguments: ["Needlepoint", "-ui-testing"])
        #expect(launch.usesInMemoryStore)
        #expect(try stash(in: launch.makeContainer()).isEmpty)
    }

    @Test func seedStashAddsTwoThreadsTotallingFive() throws {
        let launch = AppLaunch(arguments: ["Needlepoint", "-ui-testing", "-ui-testing-seed-stash"])
        let container = try launch.makeContainer()
        // Models can't be read after their container is freed, and Swift may
        // free it right after its last use, so hold it until the checks are done.
        try withExtendedLifetime(container) {
            let threads = try stash(in: container)
            #expect(threads.count == 2)
            #expect(threads.reduce(0) { $0 + $1.qty } == 5)
        }
    }

    @Test func containerHoldsEveryModel() throws {
        let container = try AppLaunch(arguments: ["Needlepoint", "-ui-testing"]).makeContainer()
        let context = container.mainContext
        context.insert(Pattern(name: "Strawberry"))
        context.insert(FolderStyle(key: ""))
        #expect(try context.fetch(FetchDescriptor<Pattern>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<FolderStyle>()).count == 1)
    }

    @Test func seedPatternsAddsThreePatternsInTwoFolders() throws {
        let launch = AppLaunch(arguments: ["Needlepoint", "-ui-testing", "-ui-testing-seed-patterns"])
        #expect(launch.seedsPatterns)
        let container = try launch.makeContainer()
        try withExtendedLifetime(container) {
            let patterns = try container.mainContext.fetch(FetchDescriptor<Pattern>())
            #expect(patterns.count == 3)
            #expect(Set(patterns.map(\.folderKey)) == ["kirk & bradley", ""])
        }
    }

    @Test func seedPatternsIsIgnoredWithoutUITesting() {
        #expect(!AppLaunch(arguments: ["Needlepoint", "-ui-testing-seed-patterns"]).seedsPatterns)
    }

    /// Settings like the Patterns tab's Folders or All choice persist between
    /// launches, so UI tests get their own defaults, emptied at every launch.
    @Test func uiTestingUsesFreshDefaults() throws {
        let first = AppLaunch(arguments: ["Needlepoint", "-ui-testing"]).defaults
        #expect(first !== UserDefaults.standard)
        first.set("all", forKey: "patternsMode")
        let second = AppLaunch(arguments: ["Needlepoint", "-ui-testing"]).defaults
        #expect(second.string(forKey: "patternsMode") == nil)
    }

    @Test func normalLaunchUsesStandardDefaults() {
        #expect(AppLaunch(arguments: ["Needlepoint"]).defaults === UserDefaults.standard)
    }

    /// Seeding writes data, so it must never run against the user's real store.
    @Test func seedStashIsIgnoredWithoutUITesting() {
        let launch = AppLaunch(arguments: ["Needlepoint", "-ui-testing-seed-stash"])
        #expect(!launch.usesInMemoryStore)
        #expect(!launch.seedsStash)
    }
}
