import Foundation
import UniformTypeIdentifiers

/// A pattern's PDF or image, as held by the editor before saving.
nonisolated struct AttachedFile: Equatable, Sendable {
    static let maxBytes = 20 * 1024 * 1024

    enum Problem: Error, Equatable {
        case tooLarge
        case unsupportedType

        var message: String {
            switch self {
            case .tooLarge: "That file is over 20 MB. Try a smaller export."
            case .unsupportedType: "Choose a PDF or an image."
            }
        }
    }

    let data: Data
    let name: String
    /// Nil only for a file saved before its type was recorded.
    let type: UTType?

    /// Checks a newly picked file: a PDF or image of at most 20 MB.
    static func make(data: Data, name: String, type: UTType) throws -> AttachedFile {
        guard type.conforms(to: .pdf) || type.conforms(to: .image) else { throw Problem.unsupportedType }
        guard data.count <= maxBytes else { throw Problem.tooLarge }
        return AttachedFile(data: data, name: name, type: type)
    }

    var isPDF: Bool { type?.conforms(to: .pdf) == true }
    var isImage: Bool { type?.conforms(to: .image) == true }
}
