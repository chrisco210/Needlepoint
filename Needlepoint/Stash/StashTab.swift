import SwiftData
import SwiftUI

struct StashTab: View {
    @Query private var threads: [StashThread]
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            Group {
                if threads.isEmpty {
                    ScrollView {
                        EmptyStateView(
                            title: "No threads in your stash yet",
                            message: "Add them one at a time, or paste a whole list at once.") {
                            Button("Add thread") { isAdding = true }
                        }
                    }
                } else {
                    List {
                        ForEach(StashSections.make(from: threads)) { section in
                            Section {
                                ForEach(section.threads) { StashRow(thread: $0) }
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
            .background(Color.background)
            .navigationTitle(AppTab.stash.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add thread", systemImage: "plus") { isAdding = true }
                }
            }
            .sheet(isPresented: $isAdding) {
                ThreadEditor()
            }
        }
    }
}

private struct StashRow: View {
    let thread: StashThread

    var body: some View {
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
            Spacer()
            Text(thread.qty, format: .number)
                .font(.appBody(17).weight(.heavy))
                .monospacedDigit()
        }
        .frame(minHeight: 44)
        .listRowBackground(Color.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("stashRow")
    }

    private var accessibilityText: String {
        thread.name.isEmpty
            ? "\(thread.code), \(thread.qty) on hand"
            : "\(thread.code), \(thread.name), \(thread.qty) on hand"
    }
}
