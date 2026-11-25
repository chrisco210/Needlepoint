import SwiftData
import SwiftUI

/// Whether the Patterns tab groups patterns into designer folders.
enum PatternsMode: String {
    case folders, all
}

struct PatternsTab: View {
    @Query private var patterns: [Pattern]
    @Query private var stash: [StashThread]
    @Query private var folderStyles: [FolderStyle]

    @AppStorage("patternsMode") private var mode: PatternsMode = .folders
    @State private var query = ""
    @State private var statusFilter: PatternStatus?
    @State private var editorRequest: PatternEditorRequest?

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SummaryHeader()
                    if patterns.isEmpty {
                        EmptyStateView(
                            title: "Your pattern library is empty",
                            message: "Add your first canvas or chart. Upload the PDF or a photo, then list the threads it calls for.") {
                            Button("Add pattern") { editorRequest = .new(designer: "") }
                        }
                    } else {
                        controls
                        content
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: 1240)
                .frame(maxWidth: .infinity)
            }
            .background(Color.background)
            .navigationTitle(AppTab.patterns.title)
            // Pinned under the navigation bar, because the default placement on
            // iPad can collapse search into a toolbar button.
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search patterns")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add pattern", systemImage: "plus") { editorRequest = .new(designer: "") }
                }
            }
            .navigationDestination(for: String.self) { key in
                FolderScreen(key: key, statusFilter: statusFilter) { editorRequest = $0 }
            }
            .sheet(item: $editorRequest) { request in
                PatternEditor(request: request)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("View", selection: $mode) {
                Text("Folders").tag(PatternsMode.folders)
                Text("All patterns").tag(PatternsMode.all)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            Spacer(minLength: 0)
            StatusFilterMenu(selection: $statusFilter)
        }
    }

    @ViewBuilder
    private var content: some View {
        if mode == .folders && !isSearching {
            folderGrid
        } else {
            if mode == .folders {
                Text("Showing matches from every folder.")
                    .font(.appBody(15, relativeTo: .callout))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blush, in: RoundedRectangle(cornerRadius: 12))
            }
            PatternGrid(
                patterns: PatternFilter.apply(patterns, query: query, status: statusFilter),
                coverage: StashCoverage(stash: stash),
                emptyMessage: isSearching ? "No patterns match that search." : "No patterns with that status.",
                onOpen: { editorRequest = .edit($0) })
        }
    }

    @ViewBuilder
    private var folderGrid: some View {
        let folders = PatternFolders.make(from: patterns, statusFilter: statusFilter)
        if folders.isEmpty {
            NoResultsMessage(text: "No patterns with that status.")
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(folders) { folder in
                    let tile = FolderTile(folder: folder, style: folderStyles.first { $0.key == folder.key })
                    NavigationLink(value: folder.key) { tile }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tile.accessibilityText)
                        .accessibilityIdentifier("folderTile")
                }
            }
        }
    }
}

/// The patterns in one designer folder.
struct FolderScreen: View {
    let key: String
    let statusFilter: PatternStatus?
    let openEditor: (PatternEditorRequest) -> Void

    @Query private var patterns: [Pattern]
    @Query private var stash: [StashThread]

    var body: some View {
        let inFolder = patterns.filter { $0.folderKey == key }
        let name = PatternFolders.make(from: inFolder, statusFilter: nil).first?.name ?? PatternFolders.noDesignerName
        ScrollView {
            PatternGrid(
                patterns: PatternFilter.apply(inFolder, query: "", status: statusFilter),
                coverage: StashCoverage(stash: stash),
                emptyMessage: "No patterns in this folder match.",
                onOpen: { openEditor(.edit($0)) })
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: 1240)
                .frame(maxWidth: .infinity)
        }
        .background(Color.background)
        .navigationTitle(name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // The "No designer" folder's key is empty, so its new patterns get no designer.
                Button("Add to this folder", systemImage: "plus") {
                    openEditor(.new(designer: key.isEmpty ? "" : name))
                }
                .labelStyle(.titleAndIcon)
            }
        }
    }
}

/// Pattern cards in an adaptive grid, or a message when there are none.
struct PatternGrid: View {
    let patterns: [Pattern]
    let coverage: StashCoverage
    let emptyMessage: String
    let onOpen: (Pattern) -> Void

    var body: some View {
        if patterns.isEmpty {
            NoResultsMessage(text: emptyMessage)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                ForEach(patterns) { pattern in
                    // A tap gesture instead of a Button keeps the card's own
                    // accessibility label and identifier.
                    PatternCard(pattern: pattern, coverage: coverage)
                        .contentShape(Rectangle())
                        .onTapGesture { onOpen(pattern) }
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
    }
}

/// A one-line note in place of an empty grid.
struct NoResultsMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.appBody())
            .foregroundStyle(Color.mute)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }
}

private struct StatusFilterMenu: View {
    @Binding var selection: PatternStatus?

    var body: some View {
        Menu {
            Picker("Status", selection: $selection) {
                Text("All statuses").tag(PatternStatus?.none)
                ForEach(PatternStatus.allCases, id: \.self) { status in
                    Text(status.label).tag(Optional(status))
                }
            }
        } label: {
            Label(selection?.label ?? "All statuses", systemImage: "line.3.horizontal.decrease.circle")
                .frame(minHeight: 44)
        }
        .accessibilityIdentifier("patterns.statusFilter")
    }
}
