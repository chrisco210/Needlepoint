import SwiftData
import SwiftUI

struct RootView: View {
    @State private var selection: AppTab = .patterns
    @State private var toasts = ToastCenter()
    @Query private var stash: [StashThread]

    var body: some View {
        TabView(selection: $selection) {
            Tab(AppTab.patterns.title, systemImage: AppTab.patterns.systemImage, value: .patterns) {
                PatternsTab()
            }
            Tab(AppTab.wip.title, systemImage: AppTab.wip.systemImage, value: .wip) {
                WIPTab(showReady: { selection = .ready })
            }
            Tab(AppTab.ready.title, systemImage: AppTab.ready.systemImage, value: .ready) {
                ReadyTab()
            }
            Tab(AppTab.stash.title, systemImage: AppTab.stash.systemImage, value: .stash) {
                StashTab()
            }
            .badge(stash.count)
            Tab(AppTab.shopping.title, systemImage: AppTab.shopping.systemImage, value: .shopping) {
                ShoppingTab()
            }
        }
        // A sidebar in iPad landscape, a tab bar elsewhere.
        .tabViewStyle(.sidebarAdaptable)
        .toastOverlay(toasts)
        .environment(toasts)
    }
}

#Preview {
    RootView()
        .modelContainer(for: StashThread.self, inMemory: true)
}
