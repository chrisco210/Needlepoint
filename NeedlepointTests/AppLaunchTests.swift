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

    /// Seeding writes data, so it must never run against the user's real store.
    @Test func seedStashIsIgnoredWithoutUITesting() {
        let launch = AppLaunch(arguments: ["Needlepoint", "-ui-testing-seed-stash"])
        #expect(!launch.usesInMemoryStore)
        #expect(!launch.seedsStash)
    }
}
