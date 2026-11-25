import SwiftData
import SwiftUI

@main struct MyApp: App {
    private let launch = AppLaunch()
    private let container: ModelContainer

    init() {
        do {
            container = try launch.makeContainer()
        } catch {
            fatalError("Couldn't open the data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .defaultAppStorage(launch.defaults)
        }
        .modelContainer(container)
    }
}
