import SwiftData
import SwiftUI

/// Patterns the stash covers, and patterns one or two threads short.
struct ReadyTab: View {
    @Query private var patterns: [Pattern]
    @Query private var stash: [StashThread]
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts

    @AppStorage(Preferences.readyIncludesWishlist) private var includeWishlist = true
    @State private var query = ""
    @State private var editorRequest: PatternEditorRequest?

    var body: some View {
        let coverage = StashCoverage(stash: stash)
        let result = ReadyToStitch.make(patterns, coverage: coverage, includeWishlist: includeWishlist, query: query)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if patterns.isEmpty {
                        EmptyStateView(
                            title: "No patterns yet",
                            message: "Add patterns with their thread lists, and the ones you can start from your stash show up here.")
                    } else {
                        Toggle("Include wishlist", isOn: $includeWishlist)
                            .toggleStyle(.switch)
                            .fixedSize()
                            .accessibilityIdentifier("ready.includeWishlist")

                        SectionHeading(
                            title: result.ready.isEmpty ? "Ready to stitch" : "Ready to stitch (\(result.ready.count))",
                            subtitle: "Every thread these patterns call for is in your stash.")
                        if result.ready.isEmpty {
                            NoResultsMessage(text: "Nothing is fully covered by your stash yet."
                                + (result.almost.isEmpty ? "" : " See what's close below."))
                        } else {
                            CardGrid {
                                ForEach(result.ready) { pattern in
                                    PatternActionCard(pattern: pattern, coverage: coverage, onOpen: open) {
                                        if pattern.status == .inProgress {
                                            Text("Already on the needle")
                                                .font(.appBody(14, relativeTo: .subheadline))
                                                .foregroundStyle(Color.mute)
                                        } else {
                                            Button("Start stitching") {
                                                toasts.show(context.changeStatus(of: pattern, to: .inProgress))
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.accentFill)
                                        }
                                    }
                                }
                            }
                        }

                        if !result.almost.isEmpty {
                            SectionHeading(title: "Almost there", subtitle: "Missing just one or two threads.")
                                .padding(.top, 8)
                            CardGrid {
                                ForEach(result.almost) { item in
                                    PatternActionCard(pattern: item.pattern, coverage: coverage, onOpen: open) {
                                        MissingThreadList(missing: item.missing)
                                    }
                                }
                            }
                        }

                        if let note = ReadyToStitch.noThreadsNote(count: result.noThreadsCount) {
                            Text(note)
                                .font(.appBody(15, relativeTo: .callout))
                                .foregroundStyle(Color.mute)
                                .padding(.top, 8)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: 1240)
                .frame(maxWidth: .infinity)
            }
            .background(Color.background)
            .navigationTitle(AppTab.ready.title)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by name or designer")
            .sheet(item: $editorRequest) { PatternEditor(request: $0) }
        }
    }

    private func open(_ pattern: Pattern) {
        editorRequest = .edit(pattern)
    }
}
