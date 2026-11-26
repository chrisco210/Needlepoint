import Foundation
import SwiftData
import UIKit
import UniformTypeIdentifiers

enum FolderRename {
    enum RenameError: Error, Equatable {
        /// "No designer" groups patterns with an empty designer, so it has no name to change.
        case noDesignerFolder
        case emptyName
    }

    static let toast = "Folder renamed"

    static func canRename(folderKey: String) -> Bool {
        !folderKey.isEmpty
    }

    /// Sets the designer of every pattern in the folder to `name` and returns
    /// the folder's new key. Renaming to another folder's name merges the two.
    /// The folder's style moves to the new key, unless that key already has a
    /// style, in which case the old one is deleted.
    @discardableResult
    static func rename(folderKey: String, to name: String, patterns: [Pattern], in context: ModelContext) throws -> String {
        guard canRename(folderKey: folderKey) else { throw RenameError.noDesignerFolder }
        let newName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { throw RenameError.emptyName }

        for pattern in patterns where pattern.folderKey == folderKey {
            pattern.designer = newName
        }
        let newKey = newName.lowercased()
        if newKey != folderKey, let oldStyle = try FolderStyle.find(key: folderKey, in: context) {
            if try FolderStyle.find(key: newKey, in: context) != nil {
                context.delete(oldStyle)
            } else {
                oldStyle.key = newKey
            }
        }
        try context.save()
        return newKey
    }
}

/// The folder image editor's form state.
struct FolderImageDraft {
    nonisolated struct Background: Sendable {
        /// Read by VoiceOver, since the swatches have no text.
        let name: String
        let hex: String
    }

    enum ImageError: Error, Equatable {
        case unreadable

        var message: String { "That image couldn't be used. Try a PNG or JPEG." }
    }

    nonisolated static let backgrounds = [
        Background(name: "White", hex: "#ffffff"),
        Background(name: "Blush", hex: "#f6e4ec"),
        Background(name: "Cream", hex: "#fbf3e2"),
        Background(name: "Sky", hex: "#e3eef6"),
        Background(name: "Plum", hex: "#7a1f4f"),
        Background(name: "Ink", hex: "#221b26"),
    ]
    /// Folder tiles are small, so their images don't need to be large.
    static let maxDimension: CGFloat = 800
    static let toast = "Folder image saved"

    var imageData: Data?
    var fit: FolderStyle.Fit
    var background: String

    init(style: FolderStyle?) {
        imageData = style?.imageData
        // A folder without a style starts at "Show whole image", as in the web app.
        fit = style?.fit ?? .contain
        background = style?.background ?? "#ffffff"
    }

    /// Logos usually come as PNG, GIF, WebP or SVG, and look best shown whole.
    static func defaultFit(for type: UTType) -> FolderStyle.Fit {
        let logoTypes: [UTType] = [.png, .gif, .webP, .svg]
        return logoTypes.contains { type.conforms(to: $0) } ? .contain : .cover
    }

    /// Sets the image, scaled to `maxDimension`, and the fit its type calls
    /// for. Images shown whole stay PNG so transparent areas show the background.
    mutating func setImage(_ data: Data, type: UTType) throws {
        guard let image = UIImage(data: data) else { throw ImageError.unreadable }
        let fit = Self.defaultFit(for: type)
        guard let scaled = Self.encode(image, asPNG: fit == .contain) else { throw ImageError.unreadable }
        imageData = scaled
        self.fit = fit
    }

    func save(folderKey: String, in context: ModelContext) throws {
        let style = try FolderStyle.style(forKey: folderKey, in: context)
        style.imageData = imageData
        style.fit = fit
        style.background = background
        try context.save()
    }

    private static func encode(_ image: UIImage, asPNG: Bool) -> Data? {
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longSide = max(pixels.width, pixels.height)
        guard longSide > 0 else { return nil }
        let factor = min(1, maxDimension / longSide)
        let target = CGSize(width: (pixels.width * factor).rounded(), height: (pixels.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !asPNG
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let draw: (UIGraphicsImageRendererContext) -> Void = { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return asPNG ? renderer.pngData(actions: draw) : renderer.jpegData(withCompressionQuality: 0.86, actions: draw)
    }
}
