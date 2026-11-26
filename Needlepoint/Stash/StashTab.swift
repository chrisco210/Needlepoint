import SwiftData
import SwiftUI

struct StashTab: View {
    @Query private var threads: [StashThread]
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts

    @State private var query = ""
    @State private var editorRequest: ThreadEditorRequest?
    @State private var isPasting = false
    @State private var pendingDelete: StashThread?

    var body: some View {
        NavigationStack {
            Group {
                if threads.isEmpty {
                    ScrollView {
                        EmptyStateView(
                            title: "No threads in your stash yet",
                            message: "Add them one at a time, or paste a whole list at once.") {
                            HStack {
                                Button("Add thread") { editorRequest = .add }
                                Button("Paste a list") { isPasting = true }
                            }
                        }
                    }
                } else {
                    list
                }
            }
            .background(Color.background)
            .navigationTitle(AppTab.stash.title)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search brand, number or color")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Paste a list", systemImage: "list.bullet.clipboard") { isPasting = true }
                    Button("Add thread", systemImage: "plus") { editorRequest = .add }
                }
            }
            .sheet(item: $editorRequest) { ThreadEditor(request: $0) }
            .sheet(isPresented: $isPasting) { PasteListSheet() }
            .confirmationDialog(
                pendingDelete.map { StashDelete.confirmation(for: $0).title } ?? "",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    if let thread = pendingDelete {
                        try? StashDelete.delete(thread, in: context)
                        toasts.show(StashDelete.toast)
                    }
                    pendingDelete = nil
                }
            } message: {
                Text(pendingDelete.map { StashDelete.confirmation(for: $0).message } ?? "")
            }
        }
    }

    @ViewBuilder
    private var list: some View {
        let sections = StashSections.make(from: threads.filter { StashSearch.matches($0, query: query) })
        if sections.isEmpty {
            ScrollView { NoResultsMessage(text: "No threads match that search.") }
        } else {
            List {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.threads) { thread in
                            StashRow(thread: thread) { editorRequest = .edit(thread) }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Remove", systemImage: "trash") { pendingDelete = thread }
                                        .tint(.warnFill)
                                }
                        }
                    } header: {
                        Text(section.brand)
                            .font(.heading(22, relativeTo: .title3))
                            .foregroundStyle(Color.ink)
                            .textCase(nil)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }
}

private struct StashRow: View {
    let thread: StashThread
    let onEdit: () -> Void

    @Environment(\.modelContext) private var context
    @State private var saver = Debouncer()

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onEdit) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color(swatch: thread.color))
                        .overlay(Circle().strokeBorder(Color.line, lineWidth: 1))
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(thread.code)
                            .font(.appBody(17).weight(.bold))
                        if !thread.name.isEmpty {
                            Text(thread.name)
                                .font(.appBody(15, relativeTo: .subheadline))
                                .foregroundStyle(Color.mute)
                        }
                    }
                    Spacer(minLength: 0)
                    Text(thread.qty, format: .number)
                        .font(.appBody(17).weight(.heavy))
                        .monospacedDigit()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityText)
            .accessibilityHint("Edits the thread")
            .accessibilityIdentifier("stashRow")

            Stepper("Quantity of \(thread.brand) \(thread.code)", value: quantity, in: 0...999)
                .labelsHidden()
                .accessibilityIdentifier("stashRow.qty")
        }
        .frame(minHeight: 44)
        .listRowBackground(Color.card)
    }

    /// Updates the quantity on screen at once and saves after taps stop.
    private var quantity: Binding<Int> {
        Binding(
            get: { thread.qty },
            set: { newValue in
                thread.setQuantity(newValue)
                saver.schedule { try? context.save() }
            })
    }

    private var accessibilityText: String {
        thread.name.isEmpty
            ? "\(thread.code), \(thread.qty) on hand"
            : "\(thread.code), \(thread.name), \(thread.qty) on hand"
    }
}

/// "Paste a list": one thread per line.
private struct PasteListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 240)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("Threads to add")
                        .accessibilityIdentifier("pasteList.text")
                } footer: {
                    Text("One thread per line: brand, number, name, qty, separated by commas or tabs. Name and qty are optional. Lines matching a thread already in your stash add to its quantity.")
                }
            }
            .navigationTitle("Paste a list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add threads", action: add)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func add() {
        let count = (try? StashPaste.apply(StashPaste.parse(text), in: context)) ?? 0
        toasts.show(StashPaste.toast(count: count))
        dismiss()
    }
}
