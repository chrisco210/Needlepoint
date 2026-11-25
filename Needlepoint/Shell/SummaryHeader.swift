import SwiftData
import SwiftUI

/// The plum band from the web app: the app name and the three library totals,
/// printed over a canvas-mesh pattern.
struct SummaryHeader: View {
    @Query private var stash: [StashThread]
    @Query private var patterns: [Pattern]

    @AppStorage(Preferences.shoppingIncludesWishlist) private var shoppingIncludesWishlist = false

    private var patternCount: Int { patterns.count }
    private var toBuyCount: Int {
        ShoppingList.totalToBuy(ShoppingList.make(patterns, stash: stash, includeWishlist: shoppingIncludesWishlist))
    }

    private var threadsOnHand: Int { stash.reduce(0) { $0 + $1.qty } }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 24) {
                titleBlock
                Spacer(minLength: 0)
                stats
            }
            VStack(alignment: .leading, spacing: 16) {
                titleBlock
                stats
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Color.plum
                CanvasMesh().opacity(0.16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stitch Stash")
                .font(.heading(40, relativeTo: .largeTitle))
                .accessibilityAddTraits(.isHeader)
            Text("Your needlepoint patterns, thread stash and shopping list in one place.")
                .font(.appBody())
                .opacity(0.85)
        }
    }

    private var stats: some View {
        HStack(spacing: 22) {
            Stat(value: patternCount, label: "patterns", id: "summary.patterns")
            Stat(value: threadsOnHand, label: "threads on hand", id: "summary.threadsOnHand")
            Stat(value: toBuyCount, label: "to buy", id: "summary.toBuy")
        }
    }
}

private struct Stat: View {
    let value: Int
    let label: String
    let id: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(.heading(28, relativeTo: .title))
                .monospacedDigit()
            Text(label)
                .font(.appBody(13, relativeTo: .caption))
                .opacity(0.85)
        }
        // Read as one phrase ("5 threads on hand") instead of "5, threads on hand".
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
        .accessibilityIdentifier(id)
    }
}

/// A 14-point grid with a diagonal stitch in each square, matching the
/// SVG pattern behind the web app's header.
private struct CanvasMesh: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 14
            var grid = Path()
            var stitches = Path()
            for x in stride(from: 0, through: size.width, by: step) {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: step) {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
                for x in stride(from: 0, through: size.width, by: step) {
                    stitches.move(to: CGPoint(x: x + 3, y: y + 11))
                    stitches.addLine(to: CGPoint(x: x + 11, y: y + 3))
                }
            }
            context.stroke(grid, with: .color(.white), lineWidth: 2)
            context.stroke(stitches, with: .color(.white.opacity(0.5)),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}
