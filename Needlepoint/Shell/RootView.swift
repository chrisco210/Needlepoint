import SwiftData
import SwiftUI

struct RootView: View {
    @State private var selection: AppTab = .patterns
    @State private var toasts = ToastCenter()
    @Query private var stash: [StashThread]
    @Query private var patterns: [Pattern]
    @AppStorage(Preferences.readyIncludesWishlist) private var readyIncludesWishlist = true
    @AppStorage(Preferences.shoppingIncludesWishlist) private var shoppingIncludesWishlist = false

    var body: some View {
        let coverage = StashCoverage(stash: stash)
        TabView(selection: $selection) {
            Tab(AppTab.patterns.tabLabel, systemImage: AppTab.patterns.systemImage, value: .patterns) {
                PatternsTab()
            }
            .badge(patterns.count)
            Tab(AppTab.wip.tabLabel, systemImage: AppTab.wip.systemImage, value: .wip) {
                WIPTab(showReady: { selection = .ready })
            }
            .badge(WorkInProgress.count(patterns))
            Tab(AppTab.ready.tabLabel, systemImage: AppTab.ready.systemImage, value: .ready) {
                ReadyTab()
            }
            .badge(ReadyToStitch.readyCount(patterns, coverage: coverage, includeWishlist: readyIncludesWishlist))
            Tab(AppTab.stash.tabLabel, systemImage: AppTab.stash.systemImage, value: .stash) {
                StashTab()
            }
            .badge(stash.count)
            Tab(AppTab.shopping.tabLabel, systemImage: AppTab.shopping.systemImage, value: .shopping) {
                ShoppingTab()
            }
            .badge(ShoppingList.make(patterns, stash: stash, includeWishlist: shoppingIncludesWishlist).count)
        }
        // A sidebar in iPad landscape, a tab bar elsewhere.
        .tabViewStyle(.sidebarAdaptable)
        .toastOverlay(toasts)
        .environment(toasts)
    }
}

#Preview("Sample library", traits: .sampleLibrary) {
    RootView()
}

#Preview("Dark", traits: .sampleLibrary) {
    RootView()
        .preferredColorScheme(.dark)
}

#Preview("Empty", traits: .emptyLibrary) {
    RootView()
}
