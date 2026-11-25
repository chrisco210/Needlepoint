import Foundation
import SwiftData

/// The Add thread editor's form state, kept apart from the model so the form
/// can be cancelled without touching the stash.
struct ThreadDraft {
    enum Outcome: Equatable {
        case added
        /// The key was already in the stash, so the existing entry took the
        /// draft's values instead of a duplicate being added.
        case updatedExisting

        var toast: String {
            switch self {
            case .added: "Thread saved"
            case .updatedExisting: "Already in stash, updated it"
            }
        }
    }

    enum SaveError: Error, Equatable {
        case missingBrandOrCode
    }

    var brand = ""
    var code = ""
    var name = ""
    /// The web app's starting swatch for a new thread.
    var color = "#b84a7a"
    var qty = 1

    var canSave: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    func save(in context: ModelContext) throws -> Outcome {
        guard canSave else { throw SaveError.missingBrandOrCode }
        let existed = try StashThread.find(ThreadKey(brand: brand, code: code), in: context) != nil
        try StashThread.upsert(brand: brand, code: code, name: name, color: color, qty: qty, in: context)
        return existed ? .updatedExisting : .added
    }
}
