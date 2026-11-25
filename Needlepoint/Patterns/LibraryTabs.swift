import Foundation

/// A pattern thread the stash doesn't hold enough of.
nonisolated struct MissingThread: Equatable, Sendable {
    let thread: PatternThread
    let have: Int

    var more: Int { thread.qty - have }

    /// "DMC 321 Red: need 2", or "need 2 more" when some are on hand.
    var label: String {
        let name = [thread.brand, thread.code, thread.name]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return have > 0 ? "\(name): need \(more) more" : "\(name): need \(more)"
    }
}

extension PatternThread {
    /// Rows with only a name, such as "Background", can't be matched to the stash.
    nonisolated var isMatchable: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension StashCoverage {
    /// The pattern's matchable threads that the stash is short of, in the
    /// pattern's order.
    func missing(in pattern: Pattern) -> [MissingThread] {
        pattern.threads.filter(\.isMatchable).compactMap { thread in
            if case .short(_, let have) = supply(of: thread) {
                return MissingThread(thread: thread, have: have)
            }
            return nil
        }
    }
}

/// Patterns that are still to be stitched: everything except Finished and
/// Needs finishing, with Wishlist only when the user includes it. Both Ready
/// to stitch and the shopping list start from these.
enum ActivePatterns {
    static func includes(_ pattern: Pattern, wishlist: Bool) -> Bool {
        switch pattern.status {
        case .finished, .needsFinishing: false
        case .wishlist: wishlist
        case .notStarted, .inProgress: true
        }
    }

    static func matchesNameOrDesigner(_ pattern: Pattern, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        return pattern.name.localizedStandardContains(needle) || pattern.designer.localizedStandardContains(needle)
    }
}

private func byName(_ lhs: Pattern, _ rhs: Pattern) -> Bool {
    lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
}

// MARK: - WIP

enum WorkInProgress {
    static func onTheNeedle(_ patterns: [Pattern], query: String) -> [Pattern] {
        patterns
            .filter { $0.status == .inProgress && PatternSearch.matches($0, query: query) }
            .sorted(by: byName)
    }

    static func needsFinishing(_ patterns: [Pattern], query: String) -> [Pattern] {
        patterns
            .filter { $0.status == .needsFinishing && PatternSearch.matches($0, query: query) }
            .sorted(by: byName)
    }

    /// The WIP tab's badge.
    static func count(_ patterns: [Pattern]) -> Int {
        patterns.filter(\.status.isWorkInProgress).count
    }

    static func notesPreview(_ notes: String) -> String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.count > 140 ? String(trimmed.prefix(140)) + "…" : trimmed
    }
}

enum StatusChange {
    /// The toast after a WIP or Ready to stitch button changes a status.
    static func toast(for status: PatternStatus, name: String) -> String {
        switch status {
        case .finished: "\"\(name)\" marked finished, congrats!"
        case .needsFinishing: "\"\(name)\" is stitched, on to finishing"
        default: "\"\(name)\" is on the needle"
        }
    }
}

// MARK: - Ready to stitch

struct AlmostThere: Identifiable {
    let pattern: Pattern
    let missing: [MissingThread]

    var id: UUID { pattern.id }
}

struct ReadyToStitch {
    /// Every matchable thread is covered by the stash.
    let ready: [Pattern]
    /// One or two threads short.
    let almost: [AlmostThere]
    /// Candidates with no matchable threads, which can't be judged either way.
    let noThreadsCount: Int

    static func make(_ patterns: [Pattern], coverage: StashCoverage, includeWishlist: Bool, query: String) -> ReadyToStitch {
        let candidates = patterns.filter {
            ActivePatterns.includes($0, wishlist: includeWishlist) && ActivePatterns.matchesNameOrDesigner($0, query: query)
        }
        var ready: [Pattern] = []
        var almost: [AlmostThere] = []
        var noThreads = 0
        for pattern in candidates {
            guard pattern.threads.contains(where: \.isMatchable) else {
                noThreads += 1
                continue
            }
            let missing = coverage.missing(in: pattern)
            if missing.isEmpty {
                ready.append(pattern)
            } else if missing.count <= 2 {
                almost.append(AlmostThere(pattern: pattern, missing: missing))
            }
        }
        return ReadyToStitch(
            ready: ready.sorted(by: Pattern.standardOrder),
            almost: almost.sorted {
                $0.missing.count != $1.missing.count
                    ? $0.missing.count < $1.missing.count
                    : Pattern.standardOrder($0.pattern, $1.pattern)
            },
            noThreadsCount: noThreads)
    }

    /// The tab's badge: ready patterns, whatever the search says.
    static func readyCount(_ patterns: [Pattern], coverage: StashCoverage, includeWishlist: Bool) -> Int {
        make(patterns, coverage: coverage, includeWishlist: includeWishlist, query: "").ready.count
    }

    static func noThreadsNote(count: Int) -> String? {
        switch count {
        case 0: nil
        case 1: "1 pattern has no threads listed yet, so it isn't counted here. Open it and add the threads."
        default: "\(count) patterns have no threads listed yet, so they aren't counted here. Open them and add the threads."
        }
    }
}

// MARK: - Shopping list

struct ShoppingLine: Identifiable {
    let key: ThreadKey
    /// Brand, code and name as written on the first pattern that lists the thread.
    let brand: String
    let code: String
    let name: String
    let need: Int
    let have: Int
    let patternNames: [String]
    /// The stash swatch, when the stash has the thread at all.
    let color: String?

    var id: String { key.storageValue }
    var buy: Int { need - have }

    var detail: String {
        "Buy \(buy), need \(need), have \(have), for \(patternNames.joined(separator: ", "))"
    }

    /// One line of "Copy list": `DMC 310 (Black), buy 2`.
    var copyLine: String {
        let label = name.isEmpty ? "\(brand) \(code)" : "\(brand) \(code) (\(name))"
        return "\(label), buy \(buy)"
    }
}

struct ShoppingSection: Identifiable {
    let brand: String
    let lines: [ShoppingLine]

    var id: String { brand.lowercased() }
}

enum ShoppingList {
    static func make(_ patterns: [Pattern], stash: [StashThread], includeWishlist: Bool) -> [ShoppingLine] {
        struct Need {
            var brand: String, code: String, name: String, qty: Int, patternNames: [String]
        }
        var needs: [ThreadKey: Need] = [:]
        var order: [ThreadKey] = []
        let active = patterns
            .filter { ActivePatterns.includes($0, wishlist: includeWishlist) }
            .sorted(by: Pattern.standardOrder)
        for pattern in active {
            for thread in pattern.threads where thread.isMatchable {
                let key = thread.key
                if var need = needs[key] {
                    need.qty += thread.qty
                    if need.name.isEmpty { need.name = thread.name.trimmingCharacters(in: .whitespacesAndNewlines) }
                    if need.patternNames.last != pattern.name { need.patternNames.append(pattern.name) }
                    needs[key] = need
                } else {
                    order.append(key)
                    needs[key] = Need(
                        brand: thread.brand.trimmingCharacters(in: .whitespacesAndNewlines),
                        code: thread.code.trimmingCharacters(in: .whitespacesAndNewlines),
                        name: thread.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        qty: thread.qty,
                        patternNames: [pattern.name])
                }
            }
        }

        let coverage = StashCoverage(stash: stash)
        let colors = Dictionary(stash.map { ($0.key, $0.color) }, uniquingKeysWith: { first, _ in first })
        return order.compactMap { key -> ShoppingLine? in
            guard let need = needs[key] else { return nil }
            let have = coverage.onHand(key)
            guard need.qty > have else { return nil }
            return ShoppingLine(
                key: key, brand: need.brand, code: need.code, name: need.name, need: need.qty, have: have,
                patternNames: need.patternNames, color: colors[key])
        }
        .sorted { lhs, rhs in
            let brand = lhs.brand.localizedStandardCompare(rhs.brand)
            if brand != .orderedSame { return brand == .orderedAscending }
            return lhs.code.localizedStandardCompare(rhs.code) == .orderedAscending
        }
    }

    /// Consecutive lines grouped by brand. `lines` must already be sorted by brand.
    static func sections(_ lines: [ShoppingLine]) -> [ShoppingSection] {
        var sections: [ShoppingSection] = []
        for line in lines {
            if let last = sections.last, last.id == line.brand.lowercased() {
                sections[sections.count - 1] = ShoppingSection(brand: last.brand, lines: last.lines + [line])
            } else {
                sections.append(ShoppingSection(brand: line.brand, lines: [line]))
            }
        }
        return sections
    }

    static func copyText(_ lines: [ShoppingLine]) -> String {
        lines.map(\.copyLine).joined(separator: "\n")
    }

    /// The summary band's "to buy" total.
    static func totalToBuy(_ lines: [ShoppingLine]) -> Int {
        lines.reduce(0) { $0 + $1.buy }
    }

    static func boughtToast(brand: String, code: String) -> String {
        "\(brand) \(code) added to stash"
    }
}
