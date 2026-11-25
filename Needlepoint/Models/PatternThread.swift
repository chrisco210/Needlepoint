import Foundation

/// A thread a pattern calls for. Stored as a value array on `Pattern`, in the
/// order the user entered them.
nonisolated struct PatternThread: Codable, Hashable, Sendable {
    var brand: String
    var code: String
    /// The color name, or where the thread is used when the pattern gives no name.
    var name: String
    /// Cards or skeins needed, at least 1 once cleaned.
    var qty: Int

    var key: ThreadKey { ThreadKey(brand: brand, code: code) }

    /// The editor's rows as they should be saved: fields trimmed, rows with
    /// no brand, code or name dropped, and quantities raised to at least 1.
    static func cleaned(_ rows: [PatternThread]) -> [PatternThread] {
        rows.compactMap { row in
            let cleaned = PatternThread(
                brand: row.brand.trimmingCharacters(in: .whitespacesAndNewlines),
                code: row.code.trimmingCharacters(in: .whitespacesAndNewlines),
                name: row.name.trimmingCharacters(in: .whitespacesAndNewlines),
                qty: max(1, row.qty))
            let isEmpty = cleaned.brand.isEmpty && cleaned.code.isEmpty && cleaned.name.isEmpty
            return isEmpty ? nil : cleaned
        }
    }
}
