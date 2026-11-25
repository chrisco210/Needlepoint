import Foundation
import SwiftData

/// A thread row in the pattern editor. The `id` keeps SwiftUI rows and focus
/// stable while the user edits brand and code.
struct EditableThread: Identifiable, Equatable {
    let id: UUID
    var brand: String
    var code: String
    var name: String
    var qty: Int

    init(brand: String, code: String, name: String, qty: Int) {
        id = UUID()
        self.brand = brand
        self.code = code
        self.name = name
        self.qty = qty
    }

    init(_ thread: PatternThread) {
        self.init(brand: thread.brand, code: thread.code, name: thread.name, qty: thread.qty)
    }

    var patternThread: PatternThread {
        PatternThread(brand: brand, code: code, name: name, qty: qty)
    }

    /// Rows show stash status only once both brand and code are filled in.
    var hasKey: Bool {
        !brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// The pattern editor's form state, kept apart from the model so Cancel
/// leaves the pattern untouched. The pattern file and cover aren't part of it.
struct PatternDraft {
    enum SaveError: Error, Equatable {
        case missingName
    }

    static let savedToast = "Pattern saved"
    static let deletedToast = "Pattern deleted"

    var name = ""
    var designer = ""
    var status: PatternStatus = .notStarted
    var mesh: Mesh?
    var notes = ""
    var threads: [EditableThread] = []

    init() {}

    init(designer: String) {
        self.designer = designer
    }

    init(editing pattern: Pattern) {
        name = pattern.name
        designer = pattern.designer
        status = pattern.status
        mesh = pattern.mesh
        notes = pattern.notes
        threads = pattern.threads.map(EditableThread.init)
    }

    var canSave: Bool { Pattern.isValidName(name) }

    /// Appends a row with the previous row's brand and returns its id, so the
    /// editor can move focus to the new row's number field.
    @discardableResult
    mutating func addThreadRow() -> EditableThread.ID {
        let row = EditableThread(brand: threads.last?.brand ?? "", code: "", name: "", qty: 1)
        threads.append(row)
        return row.id
    }

    mutating func removeThreadRow(_ id: EditableThread.ID) {
        threads.removeAll { $0.id == id }
    }

    /// Writes the draft to `pattern`, or to a new pattern inserted into
    /// `context` when `pattern` is nil, and returns the pattern written.
    @discardableResult
    func save(to pattern: Pattern?, in context: ModelContext) throws -> Pattern {
        guard canSave else { throw SaveError.missingName }
        let target = pattern ?? {
            let new = Pattern(name: name)
            context.insert(new)
            return new
        }()
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.designer = designer.trimmingCharacters(in: .whitespacesAndNewlines)
        target.status = status
        target.mesh = mesh
        target.notes = notes
        target.threads = PatternThread.cleaned(threads.map(\.patternThread))
        try context.save()
        return target
    }

    /// Deletes the pattern. Its file and cover go with it, because they're
    /// stored on the pattern.
    static func delete(_ pattern: Pattern, in context: ModelContext) throws {
        context.delete(pattern)
        try context.save()
    }

    static func deleteConfirmation(for pattern: Pattern) -> (title: String, message: String) {
        (
            title: "Delete \"\(pattern.name)\"?",
            message: pattern.fileData == nil
                ? "This can't be undone."
                : "This also removes the pattern file. It can't be undone."
        )
    }
}

enum DesignerSuggestions {
    /// Every designer in the library, one per folder, sorted by name.
    static func all(from patterns: [Pattern]) -> [String] {
        PatternFolders.make(from: patterns, statusFilter: nil)
            .filter { !$0.key.isEmpty }
            .map(\.name)
    }
}
