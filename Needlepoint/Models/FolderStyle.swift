import Foundation
import SwiftData

/// Optional styling for a designer folder's tile.
@Model
final class FolderStyle {
    nonisolated enum Fit: String, CaseIterable, Sendable {
        /// "Show whole image (best for logos)".
        case contain
        /// "Fill the tile".
        case cover
    }

    /// The folder's `Pattern.folderKey`: the lowercased, trimmed designer name.
    /// The empty string is "No designer". CloudKit doesn't support unique
    /// constraints, so get styles through `style(forKey:in:)` to avoid duplicates.
    var key: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    /// `Fit.rawValue`. Use `fit` to read and write it.
    var fitRaw: String = "cover"
    /// The tile background as `#rrggbb`.
    var background: String = "#ffffff"

    init(key: String) {
        self.key = key
    }

    var fit: Fit {
        get { Fit(rawValue: fitRaw) ?? .cover }
        set { fitRaw = newValue.rawValue }
    }

    static func find(key: String, in context: ModelContext) throws -> FolderStyle? {
        var descriptor = FetchDescriptor<FolderStyle>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// The folder's existing style, or a new one inserted into `context`.
    static func style(forKey key: String, in context: ModelContext) throws -> FolderStyle {
        if let existing = try find(key: key, in: context) {
            return existing
        }
        let style = FolderStyle(key: key)
        context.insert(style)
        return style
    }
}
