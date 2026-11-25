import Foundation
import SwiftData

/// Reads the launch arguments UI tests pass, and builds the model container
/// to match. A normal launch passes neither argument.
struct AppLaunch {
    /// Gives the app an empty in-memory store, so tests start clean and never
    /// touch data saved in the simulator.
    static let uiTestingArgument = "-ui-testing"
    /// Adds a small known stash. Honored only together with `-ui-testing`.
    static let seedStashArgument = "-ui-testing-seed-stash"

    let usesInMemoryStore: Bool
    let seedsStash: Bool

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        usesInMemoryStore = arguments.contains(Self.uiTestingArgument)
        seedsStash = usesInMemoryStore && arguments.contains(Self.seedStashArgument)
    }

    func makeContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: StashThread.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: usesInMemoryStore))
        if seedsStash {
            let context = container.mainContext
            context.insert(StashThread(brand: "DMC Floss", code: "310", name: "Black", color: "#000000", qty: 2))
            context.insert(StashThread(brand: "Silk & Ivory", code: "01", name: "Snow", color: "#ffffff", qty: 3))
            try context.save()
        }
        return container
    }
}
