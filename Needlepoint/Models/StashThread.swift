import Foundation
import SwiftData

/// A thread the user owns. Every property has a default because CloudKit
/// sync, planned for a later release, requires it.
@Model
final class StashThread {
    static let unknownColor = "#cccccc"

    var id: UUID = UUID()

    /// Brand and code are set together through `setIdentity(brand:code:)`
    /// so `matchKey` can't drift from them.
    private(set) var brand: String = ""
    /// The color number, kept as text because leading zeros and letters matter.
    private(set) var code: String = ""
    /// `ThreadKey.storageValue` for brand and code. CloudKit doesn't support
    /// unique constraints, so the insert helpers below look this up instead.
    private(set) var matchKey: String = ""

    var name: String = ""
    /// Swatch as `#rrggbb`.
    var color: String = "#cccccc"
    /// Cards or skeins on hand. Change it through `setQuantity(_:)` or
    /// `adjustQuantity(by:)`, which keep it at 0 or more.
    private(set) var qty: Int = 0
    var created: Date = Date()

    init(brand: String, code: String, name: String = "", color: String = StashThread.unknownColor, qty: Int = 1) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.color = color
        self.qty = max(0, qty)
        setIdentity(brand: brand, code: code)
    }

    var key: ThreadKey { ThreadKey(brand: brand, code: code) }

    func setIdentity(brand: String, code: String) {
        self.brand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        self.code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        matchKey = key.storageValue
    }

    func setQuantity(_ newValue: Int) {
        qty = max(0, newValue)
    }

    func adjustQuantity(by delta: Int) {
        setQuantity(qty + delta)
    }
}

// MARK: - Inserting without duplicates

extension StashThread {
    static func find(_ key: ThreadKey, in context: ModelContext) throws -> StashThread? {
        let value = key.storageValue
        var descriptor = FetchDescriptor<StashThread>(predicate: #Predicate { $0.matchKey == value })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Saves from the "Add thread" editor. If the key is already in the stash,
    /// this overwrites that entry's fields (keeping its `created` date)
    /// instead of adding a second one.
    @discardableResult
    static func upsert(
        brand: String, code: String, name: String, color: String, qty: Int,
        in context: ModelContext
    ) throws -> StashThread {
        if let existing = try find(ThreadKey(brand: brand, code: code), in: context) {
            existing.setIdentity(brand: brand, code: code)
            existing.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.color = color
            existing.setQuantity(qty)
            return existing
        }
        let thread = StashThread(brand: brand, code: code, name: name, color: color, qty: qty)
        context.insert(thread)
        return thread
    }

    /// Adds stock for "Paste a list" and the shopping list's "Bought it".
    /// An existing entry gains `qty` and keeps its name and color. A new
    /// entry gets `name` and the unknown-color swatch.
    @discardableResult
    static func addStock(
        _ qty: Int, brand: String, code: String, name: String = "",
        in context: ModelContext
    ) throws -> StashThread {
        if let existing = try find(ThreadKey(brand: brand, code: code), in: context) {
            existing.adjustQuantity(by: max(0, qty))
            return existing
        }
        let thread = StashThread(brand: brand, code: code, name: name, qty: qty)
        context.insert(thread)
        return thread
    }
}
