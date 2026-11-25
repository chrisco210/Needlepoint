import SwiftData
import SwiftUI
import UIKit

/// Threads the active patterns need beyond what the stash holds.
struct ShoppingTab: View {
    @Query private var patterns: [Pattern]
    @Query private var stash: [StashThread]
    @Environment(\.modelContext) private var context
    @Environment(ToastCenter.self) private var toasts

    @AppStorage(Preferences.shoppingIncludesWishlist) private var includeWishlist = false

    var body: some View {
        let lines = ShoppingList.make(patterns, stash: stash, includeWishlist: includeWishlist)
        let text = ShoppingList.copyText(lines)

        NavigationStack {
            List {
                Section {
                    Toggle("Include wishlist patterns", isOn: $includeWishlist)
                        .accessibilityIdentifier("shopping.includeWishlist")
                }
                if lines.isEmpty {
                    EmptyStateView(
                        title: "Nothing to buy",
                        message: patterns.isEmpty
                            ? "Add patterns with their thread lists and anything you're missing shows up here."
                            : "Your stash covers every active pattern.")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(ShoppingList.sections(lines)) { section in
                        Section {
                            ForEach(section.lines) { line in
                                ShoppingRow(line: line) { buy(line) }
                            }
                        } header: {
                            Text(section.brand)
                                .font(.heading(22, relativeTo: .title3))
                                .foregroundStyle(Color.ink)
                                .textCase(nil)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle(AppTab.shopping.title)
            .toolbar {
                if !lines.isEmpty {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Copy list", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = text
                            toasts.show("Shopping list copied")
                        }
                        // Sends the same text to Messages, Notes or Reminders.
                        ShareLink(item: text) {
                            Label("Share list", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private func buy(_ line: ShoppingLine) {
        _ = try? StashThread.addStock(line.buy, brand: line.brand, code: line.code, name: line.name, in: context)
        try? context.save()
        toasts.show(ShoppingList.boughtToast(brand: line.brand, code: line.code))
    }
}

private struct ShoppingRow: View {
    let line: ShoppingLine
    let onBought: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(swatch: line.color ?? StashThread.unknownColor))
                    .overlay(Circle().strokeBorder(Color.line, lineWidth: 1))
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.name.isEmpty ? line.code : "\(line.code) \(line.name)")
                        .font(.appBody(17).weight(.bold))
                    Text(line.detail)
                        .font(.appBody(14, relativeTo: .subheadline))
                        .foregroundStyle(Color.mute)
                }
                Spacer(minLength: 0)
            }
            // The text reads as one element; the button stays separate so it can be tapped.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .accessibilityIdentifier("shoppingRow")

            Button("Bought it", action: onBought)
                .buttonStyle(.bordered)
        }
        .frame(minHeight: 44)
        .listRowBackground(Color.card)
    }

    private var accessibilityText: String {
        [line.code, line.name.isEmpty ? nil : line.name, line.detail].compactMap(\.self).joined(separator: ", ")
    }
}
