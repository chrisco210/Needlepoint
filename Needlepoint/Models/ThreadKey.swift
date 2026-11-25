import Foundation

/// Identifies a thread by brand and color number. Pattern threads, stash
/// threads and shopping-list lines all match through this type, so the
/// matching rule (trimmed, case-insensitive) lives in one place.
nonisolated struct ThreadKey: Hashable, Sendable {
    let brand: String
    let code: String

    init(brand: String, code: String) {
        self.brand = Self.normalize(brand)
        self.code = Self.normalize(code)
    }

    /// The form stored on models so a fetch can match a key in a predicate.
    /// The separator is the ASCII unit separator, which can't appear in typed text.
    var storageValue: String { brand + "\u{1F}" + code }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
