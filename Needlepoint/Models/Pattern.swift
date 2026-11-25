import Foundation
import SwiftData
import UniformTypeIdentifiers

/// A needlepoint pattern in the library. Every property has a default because
/// CloudKit sync, planned for a later release, requires it.
@Model
final class Pattern {
    var id: UUID = UUID()
    /// Required. Check new names with `isValidName(_:)` before saving.
    var name: String = ""
    /// May be empty. Patterns are grouped into folders by `folderKey`.
    var designer: String = ""
    /// `PatternStatus.rawValue`. Stored as a string, not the enum, so fetch
    /// predicates can filter on it. Use `status` to read and write it.
    var statusRaw: String = "Not started"
    /// `Mesh.rawValue`, or nil when unset. Use `mesh` to read and write it.
    var meshRaw: String?
    var notes: String = ""
    var threads: [PatternThread] = []
    /// The pattern PDF or photo.
    @Attribute(.externalStorage) var fileData: Data?
    var fileName: String = ""
    /// A `UTType` identifier. Use `fileType` to read and write it.
    var fileTypeIdentifier: String?
    /// A JPEG cover image.
    @Attribute(.externalStorage) var coverData: Data?
    var created: Date = Date()

    init(name: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var status: PatternStatus {
        // Data from an import or a newer version can hold a status this one doesn't know.
        get { PatternStatus(rawValue: statusRaw) ?? .notStarted }
        set { statusRaw = newValue.rawValue }
    }

    var mesh: Mesh? {
        get { meshRaw.flatMap(Mesh.init(rawValue:)) }
        set { meshRaw = newValue?.rawValue }
    }

    var fileType: UTType? {
        get { fileTypeIdentifier.flatMap(UTType.init) }
        set { fileTypeIdentifier = newValue?.identifier }
    }

    /// The folder this pattern belongs to. The empty string is "No designer".
    var folderKey: String {
        designer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isValidName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The order used wherever patterns are listed by status: Stitching,
    /// Needs finishing, Not started, Wishlist, Finished, with ties by name.
    static func standardOrder(_ lhs: Pattern, _ rhs: Pattern) -> Bool {
        if lhs.status.sortRank != rhs.status.sortRank {
            return lhs.status.sortRank < rhs.status.sortRank
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
