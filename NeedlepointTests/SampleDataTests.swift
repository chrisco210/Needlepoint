import Foundation
import SwiftData
import Testing
@testable import Needlepoint

/// The data UI tests seed and previews show.
@MainActor
struct SampleDataTests {
    @Test func containerHoldsTheSampleLibrary() throws {
        let container = try SampleData.container()
        try withExtendedLifetime(container) {
            let context = container.mainContext
            let patterns = try context.fetch(FetchDescriptor<Pattern>())
            let stash = try context.fetch(FetchDescriptor<StashThread>())
            #expect(Set(patterns.map(\.name)) == ["Strawberry", "Lemon", "Mystery Santa"])
            #expect(stash.count == 2)
        }
    }

    @Test func emptyContainerHoldsNothing() throws {
        let container = try SampleData.container(seeded: false)
        try withExtendedLifetime(container) {
            let patterns = try container.mainContext.fetch(FetchDescriptor<Pattern>())
            let stash = try container.mainContext.fetch(FetchDescriptor<StashThread>())
            #expect(patterns.isEmpty)
            #expect(stash.isEmpty)
        }
    }

    /// Each preview gets its own store, so edits in one don't show in another.
    @Test func eachContainerIsSeparate() throws {
        let first = try SampleData.container()
        let second = try SampleData.container()
        try withExtendedLifetime((first, second)) {
            first.mainContext.insert(Pattern(name: "Extra"))
            try first.mainContext.save()
            let patterns = try second.mainContext.fetch(FetchDescriptor<Pattern>())
            #expect(patterns.count == 3)
        }
    }

    @Test func insertsStashAndPatternsSeparately() throws {
        let container = try SampleData.container(seeded: false)
        try withExtendedLifetime(container) {
            let context = container.mainContext
            SampleData.insertStash(into: context)
            let stash = try context.fetch(FetchDescriptor<StashThread>())
            let noPatterns = try context.fetch(FetchDescriptor<Pattern>())
            #expect(stash.count == 2)
            #expect(noPatterns.isEmpty)
            SampleData.insertPatterns(into: context)
            let patterns = try context.fetch(FetchDescriptor<Pattern>())
            #expect(patterns.count == 3)
        }
    }
}
