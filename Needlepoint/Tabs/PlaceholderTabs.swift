import SwiftUI

// Each tab shows the web app's empty state until its feature is built.
// Count badges for the pattern-based tabs come with the Pattern model.

struct PatternsTab: View {
    var body: some View {
        TabScreen(title: AppTab.patterns.title, showsSummary: true) {
            EmptyStateView(
                title: "Your pattern library is empty",
                message: "Add your first canvas or chart. Upload the PDF or a photo, then list the threads it calls for.")
        }
    }
}

struct WIPTab: View {
    let showReady: () -> Void

    var body: some View {
        TabScreen(title: AppTab.wip.title) {
            EmptyStateView(
                title: "Nothing on the needle",
                message: "Patterns marked \"Stitching\" or \"Stitched, needs finishing\" show up here. Start one from the Ready to stitch tab, or change a pattern's status.") {
                Button("See what's ready", action: showReady)
            }
        }
    }
}

struct ReadyTab: View {
    var body: some View {
        TabScreen(title: AppTab.ready.title) {
            EmptyStateView(
                title: "No patterns yet",
                message: "Add patterns with their thread lists, and the ones you can start from your stash show up here.")
        }
    }
}

struct ShoppingTab: View {
    var body: some View {
        TabScreen(title: AppTab.shopping.title) {
            EmptyStateView(
                title: "Nothing to buy",
                message: "Add patterns with their thread lists and anything you're missing shows up here.")
        }
    }
}

/// The navigation stack, background and optional summary band every tab shares.
struct TabScreen<Content: View>: View {
    let title: String
    var showsSummary = false
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if showsSummary {
                        SummaryHeader()
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                    content
                }
                .frame(maxWidth: 1240)
                .frame(maxWidth: .infinity)
            }
            .background(Color.background)
            .navigationTitle(title)
        }
    }
}
