import Foundation

/// Whether the stash holds enough of one pattern thread.
enum ThreadSupply: Equatable {
    case covered(have: Int)
    case short(more: Int, have: Int)
}

/// The stash's quantities by thread key, for checking patterns against it.
/// Build one per render from the current stash.
struct StashCoverage {
    private let onHandByKey: [ThreadKey: Int]

    init(stash: [StashThread]) {
        var onHand: [ThreadKey: Int] = [:]
        // Entries with the same key can exist briefly after sync, so add them up.
        for thread in stash {
            onHand[thread.key, default: 0] += thread.qty
        }
        onHandByKey = onHand
    }

    func onHand(_ key: ThreadKey) -> Int {
        onHandByKey[key] ?? 0
    }

    /// A thread counts as covered when the stash holds at least the quantity
    /// the pattern calls for.
    func supply(of thread: PatternThread) -> ThreadSupply {
        let have = onHand(thread.key)
        return have >= thread.qty ? .covered(have: have) : .short(more: thread.qty - have, have: have)
    }

    func coveredCount(in pattern: Pattern) -> Int {
        pattern.threads.filter {
            if case .covered = supply(of: $0) { true } else { false }
        }.count
    }

    func progressLabel(for pattern: Pattern) -> String {
        Self.progressLabel(covered: coveredCount(in: pattern), total: pattern.threads.count)
    }

    static func progressLabel(covered: Int, total: Int) -> String {
        total == 0 ? "No threads listed" : "\(covered) of \(total) threads in stash"
    }
}
