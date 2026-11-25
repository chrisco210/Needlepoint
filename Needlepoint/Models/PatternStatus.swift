import Foundation

/// Where a pattern is in its life. Raw values match the web app's data so
/// imported patterns keep their status.
nonisolated enum PatternStatus: String, CaseIterable, Codable, Sendable {
    case wishlist = "Wishlist"
    case notStarted = "Not started"
    case inProgress = "In progress"
    case needsFinishing = "Needs finishing"
    case finished = "Finished"

    var label: String {
        switch self {
        case .wishlist: "Wishlist"
        case .notStarted: "Not started"
        case .inProgress: "Stitching"
        case .needsFinishing: "Stitched, needs finishing"
        case .finished: "Finished"
        }
    }

    /// Position in the standard order: what's on the needle first, finished last.
    var sortRank: Int {
        switch self {
        case .inProgress: 0
        case .needsFinishing: 1
        case .notStarted: 2
        case .wishlist: 3
        case .finished: 4
        }
    }

    /// Statuses the WIP tab lists.
    var isWorkInProgress: Bool {
        self == .inProgress || self == .needsFinishing
    }
}

/// Canvas mesh count. Raw values match the web app's data.
nonisolated enum Mesh: String, CaseIterable, Codable, Sendable {
    case ten = "10"
    case thirteen = "13"
    case eighteen = "18"
    case other = "Other"

    var label: String { "\(rawValue) mesh" }
}
