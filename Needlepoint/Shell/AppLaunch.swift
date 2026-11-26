import Foundation
import SwiftData

/// Reads the launch arguments UI tests pass, and builds the model container
/// and defaults to match. A normal launch passes none of them.
struct AppLaunch {
    /// Gives the app an empty in-memory store and empty defaults, so tests
    /// start clean and never touch data saved in the simulator.
    static let uiTestingArgument = "-ui-testing"
    /// Adds a small known stash. Honored only together with `-ui-testing`.
    static let seedStashArgument = "-ui-testing-seed-stash"
    /// Adds three known patterns in two folders. Honored only together with `-ui-testing`.
    static let seedPatternsArgument = "-ui-testing-seed-patterns"
    /// Makes "Take a photo" available and return a generated photo, since UI
    /// tests can't drive the system camera. Honored only together with `-ui-testing`.
    static let fakeCameraArgument = "-ui-testing-fake-camera"
    /// Hides "Take a photo" as on a device without a camera. Some simulators
    /// report a camera, so tests of the no-camera case need this. Honored
    /// only together with `-ui-testing`.
    static let noCameraArgument = "-ui-testing-no-camera"

    private static let uiTestingDefaultsSuite = "ui-testing"

    let usesInMemoryStore: Bool
    let seedsStash: Bool
    let seedsPatterns: Bool
    let fakesCamera: Bool
    let hidesCamera: Bool
    /// Where `@AppStorage` reads and writes. UI tests get a suite that's
    /// emptied at every launch, so a choice one test makes can't leak into the next.
    let defaults: UserDefaults

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        usesInMemoryStore = arguments.contains(Self.uiTestingArgument)
        seedsStash = usesInMemoryStore && arguments.contains(Self.seedStashArgument)
        seedsPatterns = usesInMemoryStore && arguments.contains(Self.seedPatternsArgument)
        fakesCamera = usesInMemoryStore && arguments.contains(Self.fakeCameraArgument)
        hidesCamera = usesInMemoryStore && arguments.contains(Self.noCameraArgument)
        if usesInMemoryStore, let suite = UserDefaults(suiteName: Self.uiTestingDefaultsSuite) {
            suite.removePersistentDomain(forName: Self.uiTestingDefaultsSuite)
            defaults = suite
        } else {
            defaults = .standard
        }
    }

    func makeContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: Schema(SampleData.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: usesInMemoryStore))
        let context = container.mainContext
        if seedsStash {
            SampleData.insertStash(into: context)
        }
        if seedsPatterns {
            SampleData.insertPatterns(into: context)
        }
        try context.save()
        return container
    }
}
