import Foundation
import UniformTypeIdentifiers

enum PatternSearch {
    /// Matches name, designer, notes, and each thread's brand, code and name,
    /// ignoring case and diacritics. An empty query matches every pattern.
    static func matches(_ pattern: Pattern, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let fields = [pattern.name, pattern.designer, pattern.notes]
            + pattern.threads.flatMap { [$0.brand, $0.code, $0.name] }
        return fields.contains { $0.localizedStandardContains(needle) }
    }
}

enum PatternFilter {
    /// Patterns matching the search and status, in the standard order.
    static func apply(_ patterns: [Pattern], query: String, status: PatternStatus?) -> [Pattern] {
        patterns
            .filter { status == nil || $0.status == status }
            .filter { PatternSearch.matches($0, query: query) }
            .sorted(by: Pattern.standardOrder)
    }
}

/// A designer folder on the Patterns tab.
struct PatternFolder: Identifiable {
    /// `Pattern.folderKey`. The empty string is "No designer".
    let key: String
    let name: String
    /// Every pattern in the folder, in the standard order.
    let patterns: [Pattern]
    /// Patterns matching the status filter, or all of them without one.
    let matchingCount: Int
    let isFiltered: Bool

    var id: String { key }

    var inProgressCount: Int {
        patterns.filter(\.status.isWorkInProgress).count
    }

    var inProgressLabel: String? {
        inProgressCount > 0 ? "\(inProgressCount) in progress" : nil
    }

    var countLabel: String {
        if isFiltered { return "\(matchingCount) of \(patterns.count) patterns" }
        return patterns.count == 1 ? "1 pattern" : "\(patterns.count) patterns"
    }

    /// Shown on the folder glyph when the folder has no images. "No designer" has none.
    var initial: String? {
        key.isEmpty ? nil : name.first.map { String($0).uppercased() }
    }

    /// Up to four images for the tile's mosaic.
    var coverImages: [Data] {
        Array(patterns.compactMap(\.displayImageData).prefix(4))
    }
}

enum PatternFolders {
    static let noDesignerName = "No designer"

    /// One folder per designer, sorted by name with "No designer" last. With
    /// a status filter, folders with no matching patterns are left out.
    static func make(from patterns: [Pattern], statusFilter: PatternStatus?) -> [PatternFolder] {
        let folders = Dictionary(grouping: patterns, by: \.folderKey).map { key, group in
            PatternFolder(
                key: key,
                name: key.isEmpty ? noDesignerName : displayName(of: group),
                patterns: group.sorted(by: Pattern.standardOrder),
                matchingCount: statusFilter.map { status in group.filter { $0.status == status }.count } ?? group.count,
                isFiltered: statusFilter != nil)
        }
        return folders
            .filter { $0.matchingCount > 0 }
            .sorted { lhs, rhs in
                if lhs.key.isEmpty != rhs.key.isEmpty { return rhs.key.isEmpty }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    /// The designer as written on the folder's oldest pattern, so the name
    /// stays put when a newer pattern spells it differently.
    private static func displayName(of group: [Pattern]) -> String {
        let oldest = group.min { $0.created < $1.created }
        return oldest?.designer.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

extension Pattern {
    var designerLabel: String {
        let designer = designer.trimmingCharacters(in: .whitespacesAndNewlines)
        return designer.isEmpty ? "Designer not set" : designer
    }

    /// Shown on a card in place of an image.
    var placeholderLabel: String {
        fileType?.conforms(to: .pdf) == true ? "PDF pattern" : "No file yet"
    }

    /// The image a card shows: the cover, or the pattern file itself when
    /// that file is an image.
    var displayImageData: Data? {
        if let coverData { return coverData }
        if fileType?.conforms(to: .image) == true { return fileData }
        return nil
    }
}
