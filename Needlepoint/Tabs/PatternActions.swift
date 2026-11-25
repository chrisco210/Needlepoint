import SwiftData
import SwiftUI

/// `@AppStorage` keys shared between a tab and the badges and summary that
/// depend on the same setting.
enum Preferences {
    /// Ready to stitch includes Wishlist patterns. On by default, as in the web app.
    static let readyIncludesWishlist = "readyIncludesWishlist"
    /// The shopping list includes Wishlist patterns. Off by default, as in the web app.
    static let shoppingIncludesWishlist = "shoppingIncludesWishlist"
}

/// A pattern card that opens the editor when tapped, with buttons or notes underneath.
struct PatternActionCard<Footer: View>: View {
    let pattern: Pattern
    let coverage: StashCoverage
    let onOpen: (Pattern) -> Void
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PatternCard(pattern: pattern, coverage: coverage)
                .contentShape(Rectangle())
                .onTapGesture { onOpen(pattern) }
                .accessibilityAddTraits(.isButton)
            footer
                .padding(.horizontal, 4)
        }
    }
}

/// "Still need:" and one line per missing thread.
struct MissingThreadList: View {
    let missing: [MissingThread]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Still need:")
                .font(.appBody(14, relativeTo: .subheadline).weight(.bold))
                .foregroundStyle(Color.ink)
            ForEach(Array(missing.enumerated()), id: \.offset) { _, item in
                Text(item.label)
                    .font(.appBody(14, relativeTo: .subheadline))
                    .foregroundStyle(Color.warn)
            }
        }
    }
}

/// A section title with an optional explanation under it.
struct SectionHeading: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.heading(26, relativeTo: .title2))
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.appBody(15, relativeTo: .callout))
                    .foregroundStyle(Color.mute)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The adaptive grid every pattern list uses.
struct CardGrid<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16, alignment: .top)], spacing: 20) {
            content
        }
    }
}

extension ModelContext {
    /// Sets a pattern's status from a WIP or Ready to stitch button and
    /// returns the toast to show.
    func changeStatus(of pattern: Pattern, to status: PatternStatus) -> String {
        pattern.status = status
        try? save()
        return StatusChange.toast(for: status, name: pattern.name)
    }
}
