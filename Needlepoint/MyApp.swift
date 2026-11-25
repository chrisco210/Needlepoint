import SwiftData
import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [StashThread.self])
    }
}
