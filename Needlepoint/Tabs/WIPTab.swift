import SwiftData
import SwiftUI

/// Patterns on the needle and patterns waiting to be finished.
struct WIPTab: View {
    let showReady: () -> Void

    @Query private var patterns: [Pattern]
    @Query private var stash: [StashThread]
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts

    @State private var query = ""
    @State private var editorRequest: PatternEditorRequest?

    var body: some View {
        let coverage = StashCoverage(stash: stash)
        let onNeedle = WorkInProgress.onTheNeedle(patterns, query: query)
        let finishing = WorkInProgress.needsFinishing(patterns, query: query)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if WorkInProgress.count(patterns) == 0 {
                        EmptyStateView(
                            title: "Nothing on the needle",
                            message: "Patterns marked \"Stitching\" or \"Stitched, needs finishing\" show up here. Start one from the Ready to stitch tab, or change a pattern's status.") {
                            Button("See what's ready", action: showReady)
                        }
                    } else if onNeedle.isEmpty && finishing.isEmpty {
                        NoResultsMessage(text: "No patterns match that search.")
                    } else {
                        if !onNeedle.isEmpty {
                            SectionHeading(title: "On the needle")
                            CardGrid {
                                ForEach(onNeedle) { pattern in
                                    PatternActionCard(pattern: pattern, coverage: coverage, onOpen: open) {
                                        let missing = coverage.missing(in: pattern)
                                        if !missing.isEmpty {
                                            MissingThreadList(missing: missing)
                                        }
                                        Button("Done stitching") { setStatus(pattern, .needsFinishing) }
                                            .buttonStyle(.borderedProminent)
                                            .tint(.accentFill)
                                    }
                                }
                            }
                        }
                        if !finishing.isEmpty {
                            SectionHeading(title: PatternStatus.needsFinishing.label)
                            CardGrid {
                                ForEach(finishing) { pattern in
                                    PatternActionCard(pattern: pattern, coverage: coverage, onOpen: open) {
                                        if let notes = WorkInProgress.notesPreview(pattern.notes) {
                                            Text(notes)
                                                .font(.appBody(14, relativeTo: .subheadline))
                                                .foregroundStyle(Color.mute)
                                        }
                                        HStack {
                                            Button("Mark finished") { setStatus(pattern, .finished) }
                                                .buttonStyle(.borderedProminent)
                                                .tint(.accentFill)
                                            Button("Back to stitching") { setStatus(pattern, .inProgress) }
                                                .buttonStyle(.bordered)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: 1240)
                .frame(maxWidth: .infinity)
            }
            .background(Color.background)
            .navigationTitle(AppTab.wip.title)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search work in progress")
            .sheet(item: $editorRequest) { PatternEditor(request: $0) }
        }
    }

    private func open(_ pattern: Pattern) {
        editorRequest = .edit(pattern)
    }

    private func setStatus(_ pattern: Pattern, _ status: PatternStatus) {
        toasts.show(context.changeStatus(of: pattern, to: status))
    }
}
