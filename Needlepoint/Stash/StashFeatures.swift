import Foundation
import SwiftData

enum StashSearch {
    /// Matches brand, color number or color name, ignoring case and diacritics.
    static func matches(_ thread: StashThread, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        return [thread.brand, thread.code, thread.name].contains { $0.localizedStandardContains(needle) }
    }
}

/// One line read from "Paste a list".
nonisolated struct PastedThread: Equatable, Sendable {
    let brand: String
    let code: String
    let name: String
    let qty: Int
}

enum StashPaste {
    /// Reads lines of `brand, number, name, qty`, separated by commas or tabs.
    /// Name and qty are optional. A numeric third field is the quantity.
    /// Lines without both a brand and a number are skipped.
    nonisolated static func parse(_ text: String) -> [PastedThread] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(omittingEmptySubsequences: false) { $0 == "," || $0 == "\t" }
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard fields.count >= 2, !fields[0].isEmpty, !fields[1].isEmpty else { return nil }
            let third = fields.count > 2 ? fields[2] : ""
            if let qty = Int(third) {
                return PastedThread(brand: fields[0], code: fields[1], name: "", qty: max(0, qty))
            }
            let qty = fields.count > 3 ? Int(fields[3]) ?? 1 : 1
            return PastedThread(brand: fields[0], code: fields[1], name: third, qty: max(0, qty))
        }
    }

    /// Adds each line to the stash and returns how many lines were added.
    /// Lines matching an existing thread add to its quantity.
    @discardableResult
    static func apply(_ lines: [PastedThread], in context: ModelContext) throws -> Int {
        for line in lines {
            try StashThread.addStock(line.qty, brand: line.brand, code: line.code, name: line.name, in: context)
        }
        try context.save()
        return lines.count
    }

    nonisolated static func toast(count: Int) -> String {
        switch count {
        case 0: "No lines read. Use brand, number, name, qty."
        case 1: "Added 1 thread"
        default: "Added \(count) threads"
        }
    }
}

enum StashDelete {
    static let toast = "Thread removed"

    static func confirmation(for thread: StashThread) -> (title: String, message: String) {
        (title: "Remove \(thread.brand) \(thread.code)?", message: "It comes off your stash list.")
    }

    static func delete(_ thread: StashThread, in context: ModelContext) throws {
        context.delete(thread)
        try context.save()
    }
}

/// Runs an action once calls stop for `delay`. The stash stepper uses it so
/// rapid taps change the quantity on screen right away but save once.
final class Debouncer {
    let delay: Duration
    private var pending: Task<Void, Never>?

    init(delay: Duration = .milliseconds(700)) {
        self.delay = delay
    }

    func schedule(_ action: @escaping () -> Void) {
        pending?.cancel()
        pending = Task { [delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            action()
        }
    }
}
