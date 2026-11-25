import SwiftData
import SwiftUI

@main struct MyApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try AppLaunch().makeContainer()
        } catch {
            fatalError("Couldn't open the data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
