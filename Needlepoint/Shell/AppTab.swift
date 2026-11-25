import Foundation

/// The five top-level sections, in display order.
enum AppTab: String, CaseIterable, Hashable {
    case patterns, wip, ready, stash, shopping

    var title: String {
        switch self {
        case .patterns: "Patterns"
        case .wip: "WIP"
        case .ready: "Ready to stitch"
        case .stash: "Thread stash"
        case .shopping: "Shopping list"
        }
    }

    var systemImage: String {
        switch self {
        case .patterns: "square.grid.2x2"
        case .wip: "hourglass"
        case .ready: "checkmark.seal"
        case .stash: "tray.full"
        case .shopping: "cart"
        }
    }
}
