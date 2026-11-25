import Foundation
import SwiftData

/// The thread editor's form state, kept apart from the model so the form
/// can be cancelled without touching the stash.
struct ThreadDraft {
    enum Outcome: Equatable {
        case added
        /// The key was already in the stash, so the existing entry took the
        /// draft's values instead of a duplicate being added.
        case updatedExisting
        /// An existing thread was edited.
        case saved

        var toast: String {
            switch self {
            case .added, .saved: "Thread saved"
            case .updatedExisting: "Already in stash, updated it"
            }
        }
    }

    enum SaveError: Error, Equatable {
        case missingBrandOrCode
        /// An edit gave a thread the brand and number of another stash entry.
        case duplicateKey

        var message: String {
            switch self {
            case .missingBrandOrCode: "Enter a brand and a color number."
            case .duplicateKey: "That brand and number is already in your stash."
            }
        }
    }

    var brand = ""
    var code = ""
    var name = ""
    /// The web app's starting swatch for a new thread.
    var color = "#b84a7a"
    var qty = 1

    init() {}

    init(editing thread: StashThread) {
        brand = thread.brand
        code = thread.code
        name = thread.name
        color = thread.color
        qty = thread.qty
    }

    var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    func save(in context: ModelContext) throws -> Outcome {
        try save(editing: nil, in: context)
    }

    /// Saves an edit to `thread`, or adds a new thread when `thread` is nil.
    /// A new thread whose key is already in the stash updates that entry; an
    /// edit that would take another entry's key throws `duplicateKey`.
    @discardableResult
    func save(editing thread: StashThread?, in context: ModelContext) throws -> Outcome {
        guard canSave else { throw SaveError.missingBrandOrCode }
        if let thread {
            if let other = try StashThread.find(ThreadKey(brand: brand, code: code), in: context), other !== thread {
                throw SaveError.duplicateKey
            }
            thread.setIdentity(brand: brand, code: code)
            thread.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            thread.color = color
            thread.setQuantity(qty)
            return .saved
        }
        let existed = try StashThread.find(ThreadKey(brand: brand, code: code), in: context) != nil
        try StashThread.upsert(brand: brand, code: code, name: name, color: color, qty: qty, in: context)
        return existed ? .updatedExisting : .added
    }
}
